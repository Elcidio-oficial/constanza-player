import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:constanza_player/core/theme/app_spacing.dart';
import 'package:constanza_player/presentation/pages/home/home_page.dart';
import 'package:constanza_player/presentation/pages/playlists/playlists_page.dart';
import 'package:constanza_player/presentation/pages/search/search_page.dart';
import 'package:constanza_player/presentation/pages/settings/settings_page.dart';
import 'package:constanza_player/presentation/providers/theme_provider.dart';
import 'package:constanza_player/presentation/providers/navigation_provider.dart';
import 'package:constanza_player/presentation/providers/library_provider.dart';
import 'package:constanza_player/presentation/providers/artwork_provider.dart';
import 'package:constanza_player/presentation/providers/artist_image_provider.dart';
import 'package:constanza_player/presentation/providers/audio_settings_provider.dart';
import 'package:constanza_player/presentation/providers/player_provider.dart';
import 'package:constanza_player/presentation/providers/playlist_provider.dart';
import 'package:constanza_player/presentation/widgets/mini_player/mini_player.dart';
import 'package:constanza_player/presentation/widgets/background_wrapper.dart';
import 'package:on_audio_query/on_audio_query.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  static const _pages = [
    HomePage(),
    PlaylistsPage(),
    SearchPage(),
    SettingsPage(),
  ];

  bool _audioSettingsApplied = false;
  bool _playlistsRestored = false;
  int _lastColorSongId = -1;
  Timer? _colorDebounce;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(libraryProvider.notifier).initialize();
      ref.read(playlistProvider.notifier).loadFromStorage();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final themeState = ref.watch(themeProvider);
    final currentIndex = ref.watch(currentTabProvider);

    // Restaurar músicas das playlists quando a library carregar
    ref.listen<LibraryState>(libraryProvider, (prev, next) {
      if (next.isLoaded && !_playlistsRestored) {
        _playlistsRestored = true;
        Future.microtask(() {
          ref.read(playlistProvider.notifier).restoreSongsFromLibrary(next.songs);
        });
      }
    });

    // ── Aplicar AudioSettings ao player ao iniciar (1 vez) e a cada mudança ──
    //
    // ref.listen dispara para CADA mudança de estado.
    // Para a primeira aplicação ao iniciar, usamos _audioSettingsApplied.
    ref.listen<AudioSettingsState>(audioSettingsProvider, (prev, next) {
      final player = ref.read(playerProvider.notifier);

      // EQ: aplica quando enabled/bands/bassBoost/virtualizer mudam
      if (prev?.eqEnabled    != next.eqEnabled    ||
          prev?.eqBands      != next.eqBands       ||
          prev?.bassBoost    != next.bassBoost      ||
          prev?.virtualizer  != next.virtualizer) {
        player.applyEqSettings(
          enabled:    next.eqEnabled,
          bands:      next.eqBands,
          bassBoost:  next.bassBoost,
          virtualizer: next.virtualizer,
        );
      }

      // Velocidade: aplica quando muda
      if (prev?.playbackSpeed != next.playbackSpeed) {
        player.setSpeed(next.playbackSpeed);
      }

      // Crossfade: propaga a duração ao player
      if (prev?.crossfadeDuration != next.crossfadeDuration) {
        player.setCrossfadeDuration(next.crossfadeDuration);
      }
    });

    // Aplicação INICIAL das settings salvas (ao abrir o app pela primeira vez).
    // É necessário porque ref.listen não dispara para o estado inicial.
    if (!_audioSettingsApplied) {
      _audioSettingsApplied = true;
      final s = ref.read(audioSettingsProvider);
      final player = ref.read(playerProvider.notifier);

      // Velocidade salva → aplicar imediatamente ao AudioPlayer
      if (s.playbackSpeed != 1.0) {
        player.setSpeed(s.playbackSpeed);
      }

      // Crossfade salvo → aplicar ao player
      if (s.crossfadeDuration > 0) {
        player.setCrossfadeDuration(s.crossfadeDuration);
      }

      // EQ: guarda a config para ser reaplicada quando o sessionId chegar
      // (_reinitEq no player cuida disso automaticamente)
      player.applyEqSettings(
        enabled:    s.eqEnabled,
        bands:      s.eqBands,
        bassBoost:  s.bassBoost,
        virtualizer: s.virtualizer,
      );
    }

    // ── Extração automática de cor da artwork ao trocar de música ──────────
    // Garante que MiniPlayer e NavBar sempre recebem a cor certa,
    // sem depender do NowPlayingPage estar aberto.
    // Debounce de 150ms para skip rápido.
    ref.listen<PlayerState>(playerProvider, (prev, next) {
      final songId = next.currentSong?.numericId ?? 0;
      if (songId == 0 || songId == _lastColorSongId) return;
      _lastColorSongId = songId;
      _colorDebounce?.cancel();
      _colorDebounce = Timer(const Duration(milliseconds: 150), () {
        _extractAndSetColor(songId);
      });
    });

    // ── Re-extrair cores quando custom NP colors mudam ────────────────────
    ref.listen<ThemeState>(themeProvider, (prev, next) {
      if (prev == null) return;
      final customChanged = prev.useCustomNpColors != next.useCustomNpColors ||
          prev.npCustomColor1 != next.npCustomColor1 ||
          prev.npCustomColor2 != next.npCustomColor2 ||
          prev.npCustomColor3 != next.npCustomColor3;
      if (customChanged) {
        final songId = ref.read(playerProvider).currentSong?.numericId ?? 0;
        if (songId > 0) {
          _lastColorSongId = 0; // force re-extraction
          _extractAndSetColor(songId);
        }
      }
    });

    // ── Biblioteca → Artwork e ArtistImages ──────────────────────────────────
    ref.listen<LibraryState>(libraryProvider, (prev, next) {
      final artNotifier = ref.read(artworkProvider.notifier);

      if (next.isLoaded || next.status == LibraryStatus.empty) {
        artNotifier.setReady(true);
        if (next.artists.isNotEmpty) {
          ref.read(artistImageProvider.notifier).prefetch(
            next.artists.take(15).map((a) => a.name).toList(),
          );
        }
      } else if (next.status == LibraryStatus.noPermission ||
                 next.status == LibraryStatus.error) {
        artNotifier.setReady(false);
      }
    });

    return BackgroundWrapper(
      child: Scaffold(
        backgroundColor: themeState.hasBackground
            ? Colors.transparent
            : colors.surface,
        body: IndexedStack(index: currentIndex, children: _pages),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MiniPlayer(),
            _PremiumNavBar(
              currentIndex: currentIndex,
              onTap: (i) => ref.read(currentTabProvider.notifier).state = i,
              colors: colors,
              hasBackground: themeState.hasBackground,
            ),
          ],
        ),
      ),
    );
  }

  /// Extrai e aplica a palette de cores da artwork.
  /// Tenta cache primeiro, depois query direta (bypassa cache sizing).
  Future<void> _extractAndSetColor(int songId) async {
    // Se cores customizadas estão ativas, usa elas em vez de extrair
    final themeS = ref.read(themeProvider);
    if (themeS.useCustomNpColors && themeS.npCustomColor1 != null) {
      final c1 = themeS.npCustomColor1!;
      final c2 = themeS.npCustomColor2 ?? HSLColor.fromColor(c1).withLightness(0.3).toColor();
      final c3 = themeS.npCustomColor3 ?? HSLColor.fromColor(c1).withLightness(0.15).toColor();
      ref.read(artworkPaletteProvider.notifier).state = ArtworkPalette(
        dominant: c1,
        vibrant: c1,
        muted: c2,
        secondary: c2,
        tertiary: c3,
      );
      return;
    }

    final artNotifier = ref.read(artworkProvider.notifier);
    var data = artNotifier.getArtwork(songId, ArtworkType.AUDIO);

    // Se não está em cache, query direta ao device (48px para extração)
    if (data == null || data.isEmpty) {
      data = await ArtworkNotifier.queryArtworkForColor(songId);
    }
    if (data == null || data.isEmpty || !mounted) return;

    final palette = await ArtworkNotifier.extractPalette(data, songId: songId);
    if (!mounted || palette == null) return;
    ref.read(artworkPaletteProvider.notifier).state = palette;
  }
}

// ============================================================
// NAV BAR
// ============================================================

class _PremiumNavBar extends ConsumerWidget {
  const _PremiumNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.colors,
    required this.hasBackground,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final ColorScheme colors;
  final bool hasBackground;

  static const _items = [
    _NavItem(Icons.home_outlined,         Icons.home_rounded,        'Home'),
    _NavItem(Icons.queue_music_outlined,  Icons.queue_music_rounded, 'Playlists'),
    _NavItem(Icons.search_outlined,       Icons.search_rounded,      'Busca'),
    _NavItem(Icons.settings_outlined,     Icons.settings_rounded,    'Config'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final navStyle = ref.watch(themeProvider.select((s) => s.navBarStyle));
    final artworkColor = ref.watch(artworkColorProvider);
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    // Determine blur and background color by style
    final useBlur = navStyle == NavBarStyle.glass || navStyle == NavBarStyle.artwork;
    final Color bgColor = switch (navStyle) {
      NavBarStyle.glass => hasBackground
          ? colors.surface.withValues(alpha: 0.88)
          : colors.surface,
      NavBarStyle.artwork => colors.surface.withValues(alpha: 0.60),
      NavBarStyle.solid => colors.surface,
      NavBarStyle.minimal => Colors.transparent,
    };

    Widget content = Container(
      height: 68 + bottomPad,
      padding: EdgeInsets.only(bottom: bottomPad),
      decoration: BoxDecoration(
        color: bgColor,
        border: navStyle == NavBarStyle.minimal
            ? null
            : Border(
                top: BorderSide(
                  color: colors.outline.withValues(alpha: 0.06),
                  width: 0.5,
                ),
              ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_items.length, (i) {
          final item = _items[i];
          final active = i == currentIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(i),
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.symmetric(
                      horizontal: active ? 16 : 12,
                      vertical: active ? 6 : 4,
                    ),
                    decoration: BoxDecoration(
                      color: active
                          ? colors.primary.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusFull),
                    ),
                    child: Icon(
                      active ? item.activeIcon : item.icon,
                      size: active ? 24 : 22,
                      color: active
                          ? colors.primary
                          : colors.onSurface.withValues(alpha: 0.35),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 9,
                      fontWeight:
                          active ? FontWeight.w600 : FontWeight.w400,
                      color: active
                          ? colors.onSurface
                          : colors.onSurface.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );

    // Artwork style: overlay dominant color tint
    if (navStyle == NavBarStyle.artwork && artworkColor != null) {
      content = Stack(
        children: [
          content,
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: artworkColor.withValues(alpha: 0.45),
              ),
            ),
          ),
        ],
      );
    }

    if (useBlur) {
      return ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: content,
        ),
      );
    }
    return content;
  }
}

class _NavItem {
  const _NavItem(this.icon, this.activeIcon, this.label);
  final IconData icon;
  final IconData activeIcon;
  final String label;
}
