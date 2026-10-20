/// Home — 3-tab shell (Home / Feed / Profile).
///
/// The navigation bar is a floating island: a hairline-topped surface
/// pill that reads as hardware, with a magenta indicator for the
/// active tab. The Home tab handles repo loading states (skeletons,
/// guided empty state, inline retry) and pull-to-refresh.

library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/repo_provider.dart';
import '../../services/fcm_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/repo_card.dart';
import '../../widgets/reveal.dart';
import '../../widgets/skeleton.dart';
import '../repo_detail/repo_detail_screen.dart';
import '../feed/feed_screen.dart';
import '../profile/profile_screen.dart';
import '../onboarding/welcome_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      // Boot sequence: paint the cached list first (instant, offline-
      // friendly), then reconcile with GitHub (fresh list + auto-watch
      // flags), then register this device for pushes once data exists.
      await ref.read(repoProvider.notifier).loadFromCache();
      await ref.read(repoProvider.notifier).syncFromGitHub();
      await FcmService().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Listen for auth state changes — redirect to Welcome on sign out.
    ref.listen(authProvider, (previous, next) {
      if (!next.isSignedIn && next.user == null && !next.isLoading) {
        Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder(
            transitionDuration: AppMotion.standard,
            pageBuilder: (_, __, ___) => const WelcomeScreen(),
            transitionsBuilder: (_, animation, __, child) => FadeTransition(
              opacity:
                  CurvedAnimation(parent: animation, curve: AppMotion.curve),
              child: child,
            ),
          ),
          (route) => false,
        );
      }
    });

    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [_HomeTab(), FeedScreen(), ProfileScreen()],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).extension<AppTokens>()!.surfaceHigh,
          border: Border(
            top: BorderSide(color: Theme.of(context).colorScheme.outline),
          ),
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Home'),
              NavigationDestination(
                  icon: Icon(Icons.dynamic_feed_outlined),
                  selectedIcon: Icon(Icons.dynamic_feed_rounded),
                  label: 'Feed'),
              NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: 'Profile'),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeTab extends ConsumerWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repoState = ref.watch(repoProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Repos'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(color: scheme.outline, height: 1),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(repoProvider.notifier).syncFromGitHub(),
        child: _buildBody(context, repoState, ref),
      ),
    );
  }

  Widget _buildBody(BuildContext context, RepoState repoState, WidgetRef ref) {
    // First load — shimmer the list.
    if (repoState.isLoading && repoState.repos.isEmpty) {
      return ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 20),
        itemCount: 6,
        itemBuilder: (context, index) => const RepoCardSkeleton(),
      );
    }

    // Hard error with nothing to show — guided retry.
    if (repoState.error != null && repoState.repos.isEmpty) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: "Couldn't load your repos",
        subtitle: 'Check the connection and try again.',
        actionLabel: 'Retry',
        onAction: () => ref.read(repoProvider.notifier).syncFromGitHub(),
      );
    }

    // Fresh account — sell the value, offer the action.
    if (repoState.repos.isEmpty) {
      return EmptyState(
        icon: Icons.radar_rounded,
        title: 'No repos yet',
        subtitle:
            'Chomp auto-watches your 3 most active repos after you connect GitHub. Scan them for AI-driven health scores.',
        actionLabel: 'Sync from GitHub',
        onAction: () => ref.read(repoProvider.notifier).syncFromGitHub(),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 20, bottom: 24),
      itemCount: repoState.repos.length,
      itemBuilder: (context, index) {
        final repo = repoState.repos[index];
        return Reveal(
          delayMs: (index * 45).clamp(0, 300).toDouble(),
          child: RepoCard(
            repo: repo,
            onTap: () => Navigator.of(context).push(
              PageRouteBuilder(
                transitionDuration: AppMotion.standard,
                pageBuilder: (context, animation, secondaryAnimation) =>
                    RepoDetailScreen(repo: repo),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) =>
                        FadeTransition(
                  opacity: CurvedAnimation(
                      parent: animation, curve: AppMotion.curve),
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
