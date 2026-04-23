import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:constanza_player/domain/entities/album.dart';
import 'package:constanza_player/domain/entities/artist.dart';
import 'package:constanza_player/domain/entities/song.dart';

import 'package:constanza_player/services/permission_service.dart';
import 'package:constanza_player/presentation/pages/splash/splash_page.dart';
import 'package:constanza_player/presentation/pages/onboarding/onboarding_page.dart';
import 'package:constanza_player/presentation/pages/app_shell.dart';
import 'package:constanza_player/presentation/pages/home/home_page.dart';
import 'package:constanza_player/presentation/pages/playlists/playlists_page.dart';
import 'package:constanza_player/presentation/pages/search/search_page.dart';
import 'package:constanza_player/presentation/pages/settings/settings_page.dart';
import 'package:constanza_player/presentation/pages/now_playing/now_playing_page.dart';
import 'package:constanza_player/presentation/pages/library/album_detail_page.dart';
import 'package:constanza_player/presentation/pages/library/artist_detail_page.dart';
import 'package:constanza_player/presentation/pages/library/song_edit_page.dart';
import 'package:constanza_player/presentation/pages/library/song_list_page.dart';
import 'package:constanza_player/presentation/pages/library/genres_page.dart';
import 'package:constanza_player/presentation/pages/library/composers_page.dart';
import 'package:constanza_player/presentation/pages/library/statistics_page.dart';
import 'package:constanza_player/presentation/pages/library/history_page.dart';
import 'package:constanza_player/presentation/pages/library/duplicates_page.dart';
import 'package:constanza_player/presentation/pages/settings/equalizer_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => SplashPage(
          onComplete: () async {
            final granted = await PermissionService.hasAudioPermission();
            if (context.mounted) {
              if (granted) {
                context.go('/home');
              } else {
                context.go('/onboarding');
              }
            }
          },
        ),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) =>
            OnboardingPage(onComplete: () => context.go('/home')),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                pageBuilder: (context, state) => buildPageWithDefaultTransition(
                  context,
                  state,
                  const HomePage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/playlists',
                pageBuilder: (context, state) => buildPageWithDefaultTransition(
                  context,
                  state,
                  const PlaylistsPage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/search',
                pageBuilder: (context, state) => buildPageWithDefaultTransition(
                  context,
                  state,
                  const SearchPage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                pageBuilder: (context, state) => buildPageWithDefaultTransition(
                  context,
                  state,
                  const SettingsPage(),
                ),
              ),
            ],
          ),
        ],
      ),
      // Top Level Routes
      GoRoute(
        path: '/now-playing',
        pageBuilder: (context, state) => buildPageWithDefaultTransition(
          context,
          state,
          const NowPlayingPage(),
        ),
      ),
      GoRoute(
        path: '/album',
        pageBuilder: (context, state) {
          final album = state.extra as Album;
          return buildPageWithDefaultTransition(
            context,
            state,
            AlbumDetailPage(album: album),
          );
        },
      ),
      GoRoute(
        path: '/artist',
        pageBuilder: (context, state) {
          final artist = state.extra as Artist;
          return buildPageWithDefaultTransition(
            context,
            state,
            ArtistDetailPage(artist: artist),
          );
        },
      ),
      GoRoute(
        path: '/song-edit',
        pageBuilder: (context, state) {
          final song = state.extra as Song;
          return buildPageWithDefaultTransition(
            context,
            state,
            SongEditPage(song: song),
          );
        },
      ),
      GoRoute(
        path: '/song-list',
        pageBuilder: (context, state) {
          final args = state.extra as Map<String, dynamic>;
          return buildPageWithDefaultTransition(
            context,
            state,
            SongListPage(
              title: args['title'] as String,
              songs: args['songs'] as List<Song>,
            ),
          );
        },
      ),
      GoRoute(
        path: '/genres',
        pageBuilder: (context, state) =>
            buildPageWithDefaultTransition(context, state, const GenresPage()),
      ),
      GoRoute(
        path: '/composers',
        pageBuilder: (context, state) => buildPageWithDefaultTransition(
          context,
          state,
          const ComposersPage(),
        ),
      ),
      GoRoute(
        path: '/statistics',
        pageBuilder: (context, state) => buildPageWithDefaultTransition(
          context,
          state,
          const StatisticsPage(),
        ),
      ),
      GoRoute(
        path: '/history',
        pageBuilder: (context, state) =>
            buildPageWithDefaultTransition(context, state, const HistoryPage()),
      ),
      GoRoute(
        path: '/duplicates',
        pageBuilder: (context, state) => buildPageWithDefaultTransition(
          context,
          state,
          const DuplicatesPage(),
        ),
      ),
      GoRoute(
        path: '/equalizer',
        pageBuilder: (context, state) => buildPageWithDefaultTransition(
          context,
          state,
          const EqualizerPage(),
        ),
      ),
    ],
  );
});

CustomTransitionPage<T> buildPageWithDefaultTransition<T>(
  BuildContext context,
  GoRouterState state,
  Widget child,
) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
