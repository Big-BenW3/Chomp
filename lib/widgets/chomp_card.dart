/// ChompCard — the shared double-bezel enclosure.
///
/// The app's signature surface: a hairline outer shell hugging a surfaced
/// core (both concentric at `shell > card` radius). Used to be duplicated
/// as ~6 copies of the same BoxDecoration boilerplate; now every card in
/// the app earns its bezel from one widget so the treatment stays
/// consistent and theme-aware.
///
/// [tint] optionally overrides the outer shell color (used by the scan
/// tile's magenta wash); [innerPadding] lets dense tiles tighten padding.

library;

import 'package:flutter/material.dart';
import '../core/theme.dart';

class ChompCard extends StatelessWidget {
  const ChompCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.innerPadding,
    this.tint,
    this.borderColor,
    this.backgroundColor,
  });

  final Widget child;

  /// When set, the whole card taps through an InkWell.
  final VoidCallback? onTap;

  /// Padding of the surfaced inner core.
  final EdgeInsetsGeometry padding;

  /// Padding of the inner core, when it must differ from [padding].
  final EdgeInsetsGeometry? innerPadding;

  /// Outer shell tint. Defaults to the theme surfaceHigh wash.
  final Color? tint;

  /// Outer shell border color. Defaults to the theme outline.
  final Color? borderColor;

  /// Inner core color. Defaults to the theme surface.
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<AppTokens>()!;

    return Container(
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.shell),
        border: Border.all(color: borderColor ?? scheme.outline),
        color: tint ?? tokens.surfaceHigh.withValues(alpha: 0.5),
      ),
      child: Material(
        color: backgroundColor ?? tokens.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: innerPadding ?? padding,
            child: child,
          ),
        ),
      ),
    );
  }
}
