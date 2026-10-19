/// Welcome — the first impression for new users.
///
/// Brand lockup eases in, tagline sells the value in one line, and a
/// full-bleed magenta CTA starts the GitHub OAuth handshake. Errors
/// surface as a quiet pill rather than raw red text.

library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/brand_mark.dart';
import '../home/home_screen.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.standard,
  );
  late final Animation<double> _fade =
      CurvedAnimation(parent: _controller, curve: AppMotion.curve);
  late final Animation<Offset> _rise = Tween(
          begin: const Offset(0, 0.08), end: Offset.zero)
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
    final auth = ref.watch(authProvider);
    final scheme = Theme.of(context).colorScheme;

    ref.listen(authProvider, (previous, next) {
      if (next.isSignedIn) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: AppMotion.standard,
            pageBuilder: (_, __, ___) => const HomeScreen(),
            transitionsBuilder: (_, animation, __, child) => FadeTransition(
              opacity:
                  CurvedAnimation(parent: animation, curve: AppMotion.curve),
              child: child,
            ),
          ),
        );
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          // Ambient brand glow, top-left.
          Positioned(
            top: -140,
            left: -100,
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.brand.withValues(alpha: 0.14),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _rise,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      const Spacer(),
                      const BrandLockup(size: 108),
                      const SizedBox(height: 20),
                      Text(
                        'GitHub analytics, watched by AI, on your phone.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: scheme.onSurface.withValues(alpha: 0.65),
                            ),
                      ),
                      const Spacer(),
                      if (auth.error != null) ...[
                        _ErrorPill(message: auth.error!),
                        const SizedBox(height: 14),
                      ],
                      FilledButton(
                        onPressed: auth.isLoading
                            ? null
                            : () => ref
                                .read(authProvider.notifier)
                                .signInWithGitHub(),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                        ),
                        child: AnimatedSwitcher(
                          duration: AppMotion.micro,
                          switchInCurve: AppMotion.curve,
                          switchOutCurve: AppMotion.curve,
                          child: auth.isLoading
                              ? const SizedBox(
                                  key: ValueKey('loading'),
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Row(
                                  key: ValueKey('idle'),
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.vpn_key_rounded, size: 20),
                                    SizedBox(width: 10),
                                    Text('Connect GitHub'),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Secure OAuth — your GitHub token never touches this device.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: scheme.onSurface.withValues(alpha: 0.35),
                            ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorPill extends StatelessWidget {
  const _ErrorPill({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_rounded, size: 16, color: AppColors.danger),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}
