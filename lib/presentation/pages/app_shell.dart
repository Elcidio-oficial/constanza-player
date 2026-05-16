import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:constanza_player/core/theme/app_spacing.dart';
import 'package:go_router/go_router.dart';
import 'package:constanza_player/presentation/providers/theme_provider.dart';
import 'package:constanza_player/presentation/providers/library_provider.dart';
import 'package:constanza_player/presentation/providers/artwork_provider.dart';
import 'package:constanza_player/presentation/providers/artist_image_provider.dart';
import 'package:constanza_player/presentation/providers/audio_settings_provider.dart';
import 'package:constanza_player/presentation/providers/player_provider.dart';
import 'package:constanza_player/presentation/providers/playlist_provider.dart';
import 'package:constanza_player/presentation/widgets/mini_player/mini_player.dart';
import 'package:constanza_player/presentation/widgets/background_wrapper.dart';
import 'package:constanza_player/services/media_library/media_library_backend.dart';
import 'package:constanza_player/services/notification_color_service.dart';
import 'package:constanza_player/services/permission_service.dart';
import 'package:constanza_player/l10n/gen/app_localizations.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  bool _audioSettingsApplied = false;
  int _lastColorSongId = -1;
  Timer? _colorDebounce;
  DateTime? _lastBackPress;

  /// Token para invalidar extrações de palette em voo. Cada troca rápida
  /// de música incrementa o token; quando a extração anterior termina, se
  /// o token mudou, o resultado é descartado em vez de aplicado.
  int _colorExtractToken = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() async {
      if (!mounted) return;
      // Solicita permissão de notificação ANTES de carregar a biblioteca —
      // sem ela o foreground service de áudio é morto pelo OS em background.
      await PermissionService.requestNotificationPermission();
      if (!mounted) return;
      ref.read(playlistProvider.notifier).loadFromStorage();
      await ref.read(libraryProvider.notifier).initialize();
      if (!mounted) return;
      await ref.read(playerProvider.notifier).restorePlaybackState();
    });
  }

  @override
  void dispose() {
    _colorDebounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Salva posição em todos os estados que precedem o processo ser morto.
    // - paused: tela bloqueada ou app em background (Android)
    // - hidden: app totalmente oculto (Flutter ≥ 3.13, Android)
    // - detached: processo prestes a ser encerrado
    // Não usar inactive: dispara também em modais do sistema (chamadas, etc.)
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      ref.read(playerProvider.notifier).savePlaybackState();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final themeState = ref.watch(themeProvider);
    final currentIndex = widget.navigationShell.currentIndex;

    // Restaurar músicas das playlists sempre que a library transitar para loaded.
    // restoreSongsFromLibrary() é idempotente: retorna imediatamente se não há
    // IDs pendentes. Isto cobre tanto a carga inicial como o rescan pós-backup.
    ref.listen<LibraryState>(libraryProvider, (prev, next) {
      final wasNotLoaded = prev?.status != LibraryStatus.loaded;
      final nowLoaded = next.status == LibraryStatus.loaded;
      if (wasNotLoaded && nowLoaded) {
        Future.microtask(() {
          ref
              .read(playlistProvider.notifier)
              .restoreSongsFromLibrary(next.songs);
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
      if (prev?.eqEnabled != next.eqEnabled ||
          prev?.eqBands != next.eqBands ||
          prev?.bassBoost != next.bassBoost ||
          prev?.virtualizer != next.virtualizer) {
        player.applyEqSettings(
          enabled: next.eqEnabled,
          bands: next.eqBands,
          bassBoost: next.bassBoost,
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
        enabled: s.eqEnabled,
        bands: s.eqBands,
        bassBoost: s.bassBoost,
        virtualizer: s.virtualizer,
      );
    }

    // ── Extração de cor + re-apply na notificação (listener unificado) ─────
    // Combina extração de cor e reapply num único listener para evitar
    // duplicação e reduzir overhead de notificações.
    ref.listen<PlayerState>(playerProvider, (prev, next) {
      // Extração de cor ao trocar de música (debounce 300ms para skip rápido).
      // Cada nova troca cancela o timer anterior E invalida qualquer extração
      // em voo via _colorExtractToken — evita acúmulo de isolates paralelos.
      final songId = next.currentSong?.numericId ?? 0;
      if (songId != 0 && songId != _lastColorSongId) {
        _lastColorSongId = songId;
        _colorDebounce?.cancel();
        final token = ++_colorExtractToken;
        _colorDebounce = Timer(const Duration(milliseconds: 300), () {
          _extractAndSetColor(songId, token);
        });
      }

      // Re-aplicar cor na notificação após play/pause ou troca de música
      if (prev != null) {
        final songChanged = prev.currentSong?.id != next.currentSong?.id;
        final playStateChanged = prev.isPlaying != next.isPlaying;
        if (songChanged || playStateChanged) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (!mounted) return;
            NotificationColorService.reapplyColor();
          });
        }
      }
    });

    // ── Re-extrair cores quando custom NP colors mudam ────────────────────
    ref.listen<ThemeState>(themeProvider, (prev, next) {
      if (prev == null) return;
      final customChanged =
          prev.useCustomNpColors != next.useCustomNpColors ||
          prev.npCustomColor1 != next.npCustomColor1 ||
          prev.npCustomColor2 != next.npCustomColor2 ||
          prev.npCustomColor3 != next.npCustomColor3;
      if (customChanged) {
        final songId = ref.read(playerProvider).currentSong?.numericId ?? 0;
        if (songId > 0) {
          _lastColorSongId = 0; // force re-extraction
          final token = ++_colorExtractToken;
          _extractAndSetColor(songId, token);
        }
      }
    });

    // ── Biblioteca → Artwork e ArtistImages ──────────────────────────────────
    ref.listen<LibraryState>(libraryProvider, (prev, next) {
      final artNotifier = ref.read(artworkProvider.notifier);

      if (next.isLoaded || next.status == LibraryStatus.empty) {
        artNotifier.setReady(true);
        if (next.artists.isNotEmpty) {
          ref
              .read(artistImageProvider.notifier)
              .prefetch(next.artists.take(15).map((a) => a.name).toList());
        }
      } else if (next.status == LibraryStatus.noPermission ||
          next.status == LibraryStatus.error) {
        artNotifier.setReady(false);
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // Em qualquer aba que não seja a Home, o back volta pra Home
        // em vez de tentar sair do app.
        if (widget.navigationShell.currentIndex != 0) {
          widget.navigationShell.goBranch(0);
          return;
        }
        final now = DateTime.now();
        final lastPress = _lastBackPress;
        if (lastPress != null &&
            now.difference(lastPress) < const Duration(seconds: 2)) {
          SystemNavigator.pop();
          return;
        }
        _lastBackPress = now;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).snackbarExitTwice),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: BackgroundWrapper(
        child: Scaffold(
          backgroundColor: themeState.hasBackground
              ? Colors.transparent
              : colors.surface,
          body: widget.navigationShell,
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const MiniPlayer(),
              _PremiumNavBar(
                currentIndex: currentIndex,
                onTap: (i) {
                  HapticFeedback.lightImpact();
                  widget.navigationShell.goBranch(
                    i,
                    initialLocation: i == widget.navigationShell.currentIndex,
                  );
                },
                colors: colors,
                hasBackground: themeState.hasBackground,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Extrai e aplica a palette de cores da artwork.
  /// Tenta cache primeiro, depois query direta (bypassa cache sizing).
  /// Também envia artwork de alta qualidade ao plugin nativo para
  /// colorizar notificação e lock screen.
  ///
  /// [token] identifica esta extração. Se uma nova troca de música
  /// ocorrer antes de terminarmos, o token fica obsoleto e o resultado
  /// é descartado — evita aplicar palette de música antiga sobre a nova.
  Future<void> _extractAndSetColor(int songId, int token) async {
    if (!mounted || token != _colorExtractToken) return;

    // Se cores customizadas estão ativas, usa elas em vez de extrair
    final themeS = ref.read(themeProvider);
    if (themeS.useCustomNpColors && themeS.npCustomColor1 != null) {
      final c1 = themeS.npCustomColor1!;
      final c2 =
          themeS.npCustomColor2 ??
          HSLColor.fromColor(c1).withLightness(0.3).toColor();
      final c3 =
          themeS.npCustomColor3 ??
          HSLColor.fromColor(c1).withLightness(0.15).toColor();
      if (!mounted || token != _colorExtractToken) return;
      ref.read(artworkPaletteProvider.notifier).state = ArtworkPalette(
        dominant: c1,
        vibrant: c1,
        muted: c2,
        secondary: c2,
        tertiary: c3,
      );
      // ignore: deprecated_member_use
      NotificationColorService.updateColor(c1.value);
      return;
    }

    final artNotifier = ref.read(artworkProvider.notifier);
    var data = artNotifier.getArtwork(songId, ArtworkType.AUDIO);

    // Se não está em cache, query direta ao device (48px para extração)
    if (data == null || data.isEmpty) {
      data = await ArtworkNotifier.queryArtworkForColor(songId);
      if (!mounted || token != _colorExtractToken) return;
    }

    // Query de alta qualidade para notificação (se os 48px falharam)
    if (data == null || data.isEmpty) {
      try {
        data = await MediaLibrary.instance.queryArtwork(
          songId,
          ArtworkType.AUDIO,
          size: 300,
          quality: 85,
        );
      } catch (e) {
        debugPrint('[AppShell] artwork query error: $e');
      }
      if (!mounted || token != _colorExtractToken) return;
    }

    if (data == null || data.isEmpty) return;

    final palette = await ArtworkNotifier.extractPalette(data, songId: songId);
    if (!mounted || palette == null || token != _colorExtractToken) return;
    ref.read(artworkPaletteProvider.notifier).state = palette;

    // Envia artwork ao plugin nativo para colorizar notificação.
    NotificationColorService.updateFromArtwork(data);
    // ignore: deprecated_member_use
    NotificationColorService.updateColor(palette.vibrant.value);
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final items = [
      _NavItem(Icons.home_outlined, Icons.home_rounded, l10n.navHome),
      _NavItem(Icons.library_music_outlined, Icons.library_music_rounded, l10n.navSongs),
      _NavItem(Icons.queue_music_outlined, Icons.queue_music_rounded, l10n.navPlaylists),
      _NavItem(Icons.search_outlined, Icons.search_rounded, l10n.navSearch),
      _NavItem(Icons.settings_outlined, Icons.settings_rounded, l10n.navSettings),
    ];
    final navStyle = ref.watch(themeProvider.select((s) => s.navBarStyle));
    final artworkColor = ref.watch(artworkColorProvider);
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    // Determine blur and background color by style
    final useBlur =
        navStyle == NavBarStyle.glass || navStyle == NavBarStyle.artwork;
    final Color bgColor = switch (navStyle) {
      NavBarStyle.glass =>
        hasBackground ? colors.surface.withValues(alpha: 0.88) : colors.surface,
      NavBarStyle.artwork => colors.surface.withValues(alpha: 0.60),
      NavBarStyle.solid => colors.surface,
      NavBarStyle.minimal => Colors.transparent,
    };

    Widget content = AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
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
        children: List.generate(items.length, (i) {
          final item = items[i];
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
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusFull,
                      ),
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
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
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
              child: Container(color: artworkColor.withValues(alpha: 0.45)),
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
