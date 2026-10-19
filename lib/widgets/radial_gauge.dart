/// Radial gauge — the repo score hero.
///
/// A 270° arc that sweeps from 0 to the value on the spring curve,
/// with the number counting up in Space Grotesk. Semantics drive the
/// accent: red < 40, amber < 70, green otherwise.
///
/// Only the painter repaints per tick — no layout animation.

library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';

class RadialGauge extends StatefulWidget {
  const RadialGauge({super.key, required this.label, this.value});

  final String label;
  final int? value;

  @override
  State<RadialGauge> createState() => _RadialGaugeState();
}

class _RadialGaugeState extends State<RadialGauge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.standard,
  );

  late final Animation<double> _sweep =
      CurvedAnimation(parent: _controller, curve: AppMotion.curve);

  @override
  void initState() {
    super.initState();
    if (widget.value != null) _controller.forward();
  }

  @override
  void didUpdateWidget(RadialGauge old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _tierColor(int v) {
    if (v < 40) return AppColors.danger;
    if (v < 70) return AppColors.warning;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final v = widget.value;
    final color = v == null ? null : _tierColor(v);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.shell),
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            color: tokens.surfaceHigh.withValues(alpha: 0.5),
          ),
          child: Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.card),
              color: tokens.surface,
            ),
            padding: const EdgeInsets.all(14),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) => CustomPaint(
                painter: _ArcPainter(
                  progress: v == null ? 0 : _sweep.value,
                  color: color ?? AppColors.brand,
                  track: tokens.surfaceHigh.withValues(alpha: 0.35),
                ),
                child: Center(
                  child: Semantics(
                    label: v == null
                        ? 'No ${widget.label.toLowerCase()} score yet'
                        : '${widget.label.toLowerCase()} score $v out of 100',
                    child: ExcludeSemantics(
                      child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (v == null)
                        Text('—',
                            style: Theme.of(context).textTheme.headlineMedium)
                      else
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: v.toDouble()),
                          duration: AppMotion.standard,
                          curve: AppMotion.curve,
                          builder: (context, t, _) => Text(
                            t.round().toString(),
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  fontFamily:
                                      GoogleFonts.spaceGrotesk().fontFamily,
                                  color: color,
                                ),
                          ),
                        ),
                      const SizedBox(height: 2),
                      Text(
                        widget.label,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.55),
                            ),
                      ),
                    ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter(
      {required this.progress, required this.color, required this.track});

  final double progress;
  final Color color;
  final Color track;

  static const _start = 0.75 * math.pi;
  static const _sweepTotal = 1.5 * math.pi;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 6;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawArc(rect, _start, _sweepTotal, false, trackPaint);

    final sweep = _sweepTotal * progress.clamp(0.0, 1.0);
    if (sweep > 0) {
      final barPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: _start,
          endAngle: _start + _sweepTotal,
          colors: [color.withValues(alpha: 0.55), color],
        ).createShader(rect);
      canvas.drawArc(rect, _start, sweep, false, barPaint);
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress || old.color != color || old.track != track;
}
