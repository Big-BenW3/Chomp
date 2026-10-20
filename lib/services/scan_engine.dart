/// Scan engine for live repository analysis.
///
/// Manages manual scan requests via Server-Sent Events (SSE). The actual
/// scan work (GitHub fetch, NVIDIA analysis, Groq evaluation) happens
/// server-side — this client just opens an SSE connection and turns each
/// event into a UI-friendly log entry.
///
/// The scan pipeline on the server:
/// 1. Fetch repo files from GitHub
/// 2. Pick sample files for AI analysis
/// 3. Run NVIDIA for code quality + security scores
/// 4. Run Groq for documentation + test ratings
/// 5. Store results in Neon and create alerts if needed

library;

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import 'api_client.dart';

/// Phases of a repository scan.
///
/// Maps to the server's scan pipeline stages. Used to update the UI
/// with the current scan progress.
enum ScanPhase {
  fetching, // Fetching repo data from GitHub
  ingesting, // Processing file tree
  analysing, // Analyzing repository structure
  codeReview, // Running NVIDIA code review
  securityCheck, // Running NVIDIA security check
  docsEval, // Running Groq documentation evaluation
  testsEval, // Running Groq test coverage evaluation
  complete, // Scan finished successfully
  error, // Scan failed
}

/// Event emitted during a scan.
///
/// Contains the current phase, a human-readable message, and optionally
/// the final scan result payload when the scan completes.
class ScanPhaseEvent {
  final ScanPhase phase;
  final String message;
  final Map<String, dynamic>? payload; // only set on `complete`

  const ScanPhaseEvent(this.phase, this.message, [this.payload]);
}

/// Runs manual, live scans for repositories.
///
/// Opens an SSE connection to the backend and streams phase events
/// back to the UI. The client never has access to the raw GitHub
/// token or AI API keys — all processing happens server-side.
///
/// Wire format note: the server writes `: ping` comment lines every
/// 15s to keep intermediaries (Render proxy) from idle-killing long
/// AI calls. This parser only reacts to `event:`/`data:` lines plus
/// blank event terminators, so heartbeat comments fall through
/// harmlessly.
class ScanEngine {
  final _api = ApiClient.instance;

  /// Initiates a scan for the given repository.
  ///
  /// Returns a stream of [ScanPhaseEvent] that emits updates as the
  /// scan progresses through each phase. The stream completes when
  /// the scan finishes or fails.
  Stream<ScanPhaseEvent> runScan(String repoId) {
    final controller = StreamController<ScanPhaseEvent>();
    _stream(repoId, controller);
    return controller.stream;
  }

  /// Internal method that manages the SSE connection and event parsing.
  Future<void> _stream(
      String repoId, StreamController<ScanPhaseEvent> controller) async {
    http.Client? client;
    try {
      // Open SSE connection to the backend
      final (streamed, openedClient) =
          await _api.openStream('${ApiEndpoints.scanRepo}/$repoId');
      client = openedClient;
      final lines = streamed.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      String? eventName;
      final buffer = StringBuffer();

      // Parse SSE format:
      //   ": ping\n\n"        → keepalive comment, ignored
      //   "event: <name>\n"   → remember the event name
      //   "data: <json>\n\n"  → emit one ScanPhaseEvent
      await for (final line in lines) {
        if (line.startsWith('event:')) {
          eventName = line.substring(6).trim();
        } else if (line.startsWith('data:')) {
          buffer.write(line.substring(5).trim());
        } else if (line.isEmpty && buffer.isNotEmpty) {
          // Empty line indicates end of event
          final data = jsonDecode(buffer.toString()) as Map<String, dynamic>;
          buffer.clear();
          final phase = _parsePhase(eventName ?? data['phase'] as String?);
          controller.add(ScanPhaseEvent(
            phase,
            data['message'] as String? ?? phase.name,
            data['result'] as Map<String, dynamic>?,
          ));
          eventName = null;
          if (phase == ScanPhase.complete || phase == ScanPhase.error) {
            _safeClose(controller);
            return;
          }
        }
      }
      _safeClose(controller);
    } catch (e) {
      controller.add(const ScanPhaseEvent(
          ScanPhase.error, 'Scan failed. Please try again.'));
      _safeClose(controller);
    } finally {
      client?.close();
    }
  }

  /// Closes the controller without throwing if it was already closed
  /// (e.g. the consumer cancelled the subscription mid-stream).
  void _safeClose(StreamController<ScanPhaseEvent> controller) {
    if (!controller.isClosed) controller.close();
  }

  /// Converts a raw phase string from the server to a [ScanPhase] enum.
  ScanPhase _parsePhase(String? raw) {
    switch (raw) {
      case 'fetching':
        return ScanPhase.fetching;
      case 'ingesting':
        return ScanPhase.ingesting;
      case 'analysing':
        return ScanPhase.analysing;
      case 'code_review':
        return ScanPhase.codeReview;
      case 'security_check':
        return ScanPhase.securityCheck;
      case 'docs_eval':
        return ScanPhase.docsEval;
      case 'tests_eval':
        return ScanPhase.testsEval;
      case 'complete':
        return ScanPhase.complete;
      default:
        return ScanPhase.error;
    }
  }
}
