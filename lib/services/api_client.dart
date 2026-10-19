/// HTTP client wrapper for all API communication with the Chomp backend.
///
/// This is the single point of contact between the Flutter app and the
/// backend server. It handles:
/// - Session token storage (JWT issued after GitHub OAuth)
/// - Authenticated request headers
/// - JSON request/response serialization
/// - Error handling via [ApiException]
/// - Server-Sent Events (SSE) for live scan updates
///
/// The raw GitHub access token never touches the client — the backend
/// holds it securely and acts as a proxy for all GitHub API calls.

library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/env.dart';

/// Exception thrown when an API request fails.
///
/// Contains the HTTP status code and response body for debugging.
class ApiException implements Exception {
  final int statusCode;
  final String body;
  ApiException(this.statusCode, this.body);

  @override
  String toString() => 'ApiException($statusCode): $body';
}

/// Thin HTTP wrapper shared by every service.
///
/// Owns the session token (issued by OUR backend after GitHub OAuth —
/// never the raw GitHub token) and attaches it to every request.
/// Uses FlutterSecureStorage to persist the token across app restarts.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const _storage = FlutterSecureStorage();
  static const _sessionKey = 'chomp_session_token';

  /// Retrieves the stored session token, if any.
  Future<String?> get sessionToken => _storage.read(key: _sessionKey);

  /// Persists a new session token after successful authentication.
  Future<void> setSessionToken(String token) =>
      _storage.write(key: _sessionKey, value: token);

  /// Clears the stored session token (used during sign out).
  Future<void> clearSession() => _storage.delete(key: _sessionKey);

  /// Builds a full URI from an endpoint path.
  Uri _uri(String path) => Uri.parse('${Env.apiBaseUrl}$path');

  /// Builds authenticated request headers.
  ///
  /// Includes the session token in the Authorization header if available.
  Future<Map<String, String>> _authHeaders() async {
    final token = await sessionToken;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Sends an authenticated GET request.
  Future<dynamic> get(String path) async {
    final res = await http.get(_uri(path), headers: await _authHeaders());
    return _handle(res);
  }

  /// Sends an authenticated POST request with a JSON body.
  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final res = await http.post(_uri(path),
        headers: await _authHeaders(), body: jsonEncode(body));
    return _handle(res);
  }

  /// Sends an authenticated PUT request with a JSON body.
  Future<dynamic> put(String path, Map<String, dynamic> body) async {
    final res = await http.put(_uri(path),
        headers: await _authHeaders(), body: jsonEncode(body));
    return _handle(res);
  }

  /// Handles the HTTP response, throwing [ApiException] on error.
  ///
  /// Extracts a user-friendly error message from the response body
  /// when possible, falling back to a generic message for non-JSON
  /// or unexpected responses. On a 401 the stored session is cleared
  /// so the app can't get wedged in a signed-in-but-dead state.
  Future<dynamic> _handle(http.Response res) async {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(res.body);
    }
    String message;
    try {
      final body = jsonDecode(res.body);
      message = body['error'] is String
          ? body['error']
          : 'Request failed. Please try again.';
    } catch (_) {
      message = res.statusCode >= 500
          ? 'Server error. Please try again.'
          : 'Request failed. Please try again.';
    }
    if (res.statusCode == 401) await clearSession();
    throw ApiException(res.statusCode, message);
  }

  /// Opens a Server-Sent Events connection.
  ///
  /// Used only by [ScanEngine] for the live "Scan Again" phase log.
  /// Returns the [http.StreamedResponse] alongside the [http.Client]
  /// that owns the underlying connection — the caller MUST close the
  /// client when the stream is done to avoid leaking sockets.
  Future<(http.StreamedResponse, http.Client)> openStream(String path) async {
    final request = http.Request('POST', _uri(path));
    request.headers.addAll(await _authHeaders());
    request.headers['Accept'] = 'text/event-stream';
    final client = http.Client();
    final response = await client.send(request);
    return (response, client);
  }
}
