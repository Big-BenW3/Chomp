/// Scan log — the live heartbeat of a manual scan.
///
/// A terminal-styled panel: dark core, magenta-tinted hairline, one
/// row per phase. Entries stagger in on the spring curve and the view
/// auto-scrolls so the newest line is always visible. Phase icons and
/// dot colors map to the pipeline stage.

library;

import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/scan_engine.dart';

/// Whether the OS asks for reduced motion. Ambient and repeating
/// animation (auto-scroll, staggered slides) should respect it.
bool prefersReducedMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

class ScanLogView extends StatefulWidget {
  const ScanLogView({super.key, required this.entries});

  final List<ScanPhaseEvent> entries;

  @override
  State<ScanLogView> createState() => _ScanLogViewState();
}

class _ScanLogViewState extends State<ScanLogView> {
  final ScrollController _scroll = ScrollController();

  @override
  void didUpdateWidget(ScanLogView old) {
    super.didUpdateWidget(old);
    if (old.entries.length != widget.entries.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        // Reduced motion: jump straight to the newest line instead of
        // animating a scroll the user asked not to see.
        if (prefersReducedMotion(context)) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
          return;
        }
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: AppMotion.standard,
          curve: AppMotion.curve,
        );
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;

    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.shell),
        border: Border.all(color: AppColors.brand.withValues(alpha: 0.28)),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.card),
          color: const Color(0xFF0A090D),
          boxShadow: [
            BoxShadow(
              color: AppColors.brand.withValues(alpha: 0.08),
              blurRadius: 24,
              spreadRadius: -8,
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.terminal_rounded,
                    size: 14, color: AppColors.brand),
                const SizedBox(width: 8),
                Text(
                  'SCAN LOG',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.brand,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView.builder(
                controller: _scroll,
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: widget.entries.length,
                itemBuilder: (context, index) => _LogLine(
                  entry: widget.entries[index],
                  tokens: tokens,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogLine extends StatefulWidget {
  const _LogLine({required this.entry, required this.tokens});

  final ScanPhaseEvent entry;
  final AppTokens tokens;

  @override
  State<_LogLine> createState() => _LogLineState();
}

class _LogLineState extends State<_LogLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.standard,
  );
  late final Animation<double> _fade =
      CurvedAnimation(parent: _controller, curve: AppMotion.curve);
  late final Animation<Offset> _slide = Tween(
          begin: const Offset(-0.04, 0), end: Offset.zero)
      .animate(CurvedAnimation(parent: _controller, curve: AppMotion.curve));

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _phaseColor(widget.entry.phase),
                ),
              ),
              const SizedBox(width: 10),
              Icon(_phaseIcon(widget.entry.phase),
                  size: 13,
                  color: widget.tokens.surfaceHigh.withValues(alpha: 0.8)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.entry.message,
                  style: const TextStyle(
                    color: Color(0xFF9BE8A8),
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _phaseColor(ScanPhase phase) => switch (phase) {
        ScanPhase.complete => AppColors.success,
        ScanPhase.error => AppColors.danger,
        ScanPhase.securityCheck => AppColors.danger.withValues(alpha: 0.8),
        ScanPhase.codeReview => const Color(0xFFA78BFA),
        ScanPhase.docsEval || ScanPhase.testsEval => const Color(0xFFF5A623),
        _ => AppColors.brand,
      };

  IconData _phaseIcon(ScanPhase phase) => switch (phase) {
        ScanPhase.fetching => Icons.download_rounded,
        ScanPhase.ingesting => Icons.folder_open_rounded,
        ScanPhase.analysing => Icons.analytics_rounded,
        ScanPhase.codeReview => Icons.code_rounded,
        ScanPhase.securityCheck => Icons.shield_rounded,
        ScanPhase.docsEval => Icons.menu_book_rounded,
        ScanPhase.testsEval => Icons.checklist_rounded,
        ScanPhase.complete => Icons.check_circle_rounded,
        ScanPhase.error => Icons.error_rounded,
      };
}
