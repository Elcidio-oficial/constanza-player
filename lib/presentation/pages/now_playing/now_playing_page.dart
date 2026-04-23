// ignore_for_file: curly_braces_in_flow_control_structures, unused_element_parameter

import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:constanza_player/domain/entities/lyric_line.dart';
import 'package:constanza_player/domain/entities/song.dart';
import 'package:constanza_player/presentation/pages/library/album_detail_page.dart';
import 'package:constanza_player/presentation/pages/library/artist_detail_page.dart';
import 'package:constanza_player/presentation/pages/library/song_edit_page.dart';
import 'package:constanza_player/presentation/providers/lyrics_provider.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:constanza_player/core/constants/app_constants.dart';
import 'package:constanza_player/core/theme/app_spacing.dart';
import 'package:constanza_player/presentation/providers/player_provider.dart';
import 'package:constanza_player/presentation/providers/theme_provider.dart';
import 'package:constanza_player/presentation/providers/library_provider.dart';
import 'package:constanza_player/presentation/providers/playlist_provider.dart';
import 'package:constanza_player/presentation/providers/artwork_provider.dart';
import 'package:constanza_player/presentation/providers/audio_settings_provider.dart';
import 'package:constanza_player/presentation/providers/audio_analysis_provider.dart';
import 'package:constanza_player/presentation/widgets/artwork_image.dart';
import 'package:constanza_player/presentation/widgets/artist_links_text.dart';
import 'package:constanza_player/presentation/widgets/background_wrapper.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:constanza_player/services/lyrics_fetch_service.dart';
import 'package:constanza_player/core/utils/app_page_route.dart';
import 'package:go_router/go_router.dart';

// ============================================================
// NOW PLAYING PAGE — Professional with vibrant gradients
// ============================================================

class NowPlayingPage extends ConsumerStatefulWidget {
  const NowPlayingPage({super.key});

  @override
  ConsumerState<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends ConsumerState<NowPlayingPage>
    with SingleTickerProviderStateMixin {
  static const _kDark = Color(0xFF1A1A2E);

  late final AnimationController _colorAnim;

  // Multi-color palette: 3 gradient colors + primary for mini player
  Color _toC1 = _kDark, _toC2 = _kDark, _toC3 = _kDark;
  Color _rawVibrant = _kDark;
  Animation<Color?> _animC1 = const AlwaysStoppedAnimation(null);
  Animation<Color?> _animC2 = const AlwaysStoppedAnimation(null);
  Animation<Color?> _animC3 = const AlwaysStoppedAnimation(null);

  int _lastSongId = -1;

  @override
  void initState() {
    super.initState();
    _colorAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _colorAnim.dispose();
    super.dispose();
  }

  /// Aplica as cores da palette extraída pelo AppShell.
  void _applyColorsFromPalette(ArtworkPalette palette) {
    _applyColors(
      _toVividGradient(palette.vibrant),
      _toVividGradient(palette.secondary ?? palette.vibrant),
      _toVividGradient(palette.tertiary ?? palette.vibrant),
      palette.vibrant,
    );
  }

  /// Aplica cores com animação suave
  void _applyColors(Color c1, Color c2, Color c3, Color vibrant) {
    if (!mounted) return;
    final curve = CurvedAnimation(parent: _colorAnim, curve: Curves.easeInOut);
    setState(() {
      final oldC1 = _toC1, oldC2 = _toC2, oldC3 = _toC3;
      _toC1 = c1;
      _toC2 = c2;
      _toC3 = c3;
      _rawVibrant = vibrant;
      _animC1 = ColorTween(begin: oldC1, end: c1).animate(curve);
      _animC2 = ColorTween(begin: oldC2, end: c2).animate(curve);
      _animC3 = ColorTween(begin: oldC3, end: c3).animate(curve);
    });
    _colorAnim.forward(from: 0);
  }

  /// Gradient color — faithful to artwork, subtle saturation lift
  static Color _toVividGradient(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness(hsl.lightness.clamp(0.25, 0.55))
        .withSaturation((hsl.saturation * 1.1).clamp(0.25, 0.90))
        .toColor();
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final currentSong = ref.watch(playerProvider.select((s) => s.currentSong));
    final hasSong = currentSong != null;
    final songId = currentSong?.numericId ?? 0;
    final baseTheme = Theme.of(context);
    final baseColors = baseTheme.colorScheme;

    final colors = baseColors.brightness == Brightness.dark
        ? baseColors
        : ColorScheme.dark(
            primary: baseColors.primary,
            onPrimary: baseColors.onPrimary,
            secondary: baseColors.secondary,
            tertiary: baseColors.tertiary,
            error: baseColors.error,
          );

    // Aplica cores quando o AppShell atualiza a palette (fonte única de extração)
    ref.listen<ArtworkPalette?>(artworkPaletteProvider, (prev, next) {
      if (next != null) _applyColorsFromPalette(next);
    });

    // Reseta para escuro imediatamente ao trocar de música
    ref.listen<Song?>(playerProvider.select((s) => s.currentSong), (
      prev,
      next,
    ) {
      if (next != null && next.numericId != _lastSongId) {
        _lastSongId = next.numericId;
        if (prev != null) _applyColors(_kDark, _kDark, _kDark, _kDark);
      }
    });

    // Aplica palette já disponível no primeiro build
    if (hasSong && _lastSongId == -1) {
      _lastSongId = songId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final palette = ref.read(artworkPaletteProvider);
        if (palette != null) _applyColorsFromPalette(palette);
      });
    }

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    final npStyleOuter = themeState.nowPlayingStyle;

    return Theme(
      data: baseTheme.copyWith(colorScheme: colors),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        extendBody: true,
        backgroundColor: const Color(0xFF080808),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: const Color(0xFF080808)),
            // Blurred artwork bg — fora do AnimatedBuilder pois não depende da cor animada
            if (npStyleOuter == NowPlayingStyle.classic && hasSong)
              _BlurredArtworkBg(songId: songId, opacity: 0.55),
            if (npStyleOuter == NowPlayingStyle.fullBlur && hasSong)
              _BlurredArtworkBg(songId: songId, opacity: 0.92),

            // Camada de gradientes animados — isolada em RepaintBoundary para
            // evitar que os 600ms de tween invalidem o Scaffold/content acima.
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: _colorAnim,
                builder: (_, __) {
                  // 3-color palette from animation
                  final c1 = _animC1.value ?? _toC1;
                  final c2 = _animC2.value ?? _toC2;
                  final c3 = _animC3.value ?? _toC3;
                  final useColor = c1 != _kDark;
                  final npStyle = themeState.nowPlayingStyle;
                  final colorStyle = themeState.nowPlayingColorStyle;
                  final isGradient = colorStyle == NowPlayingColorStyle.gradient;

                  // For degradê mode: use c1 as single base color with bright top
                  final dgBase = c1;
                  final Color dgTop;
                  if (useColor) {
                    final hsl = HSLColor.fromColor(c1);
                    dgTop = hsl
                        .withLightness((hsl.lightness * 1.3).clamp(0.18, 0.50))
                        .withSaturation((hsl.saturation * 1.1).clamp(0.25, 0.85))
                        .toColor();
                  } else {
                    dgTop = c1;
                  }

                  // For gradient mode: blended accents
                  final cMix12 = Color.lerp(c1, c2, 0.5)!;
                  final cMix13 = Color.lerp(c1, c3, 0.5)!;

                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      // ═══════════════════════════════════════════
                      // DEGRADÊ MODE — Single-color linear gradient
                      // ═══════════════════════════════════════════
                      if (useColor && !isGradient) ...[
                  // Linear gradient — faithful to artwork color
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          dgTop.withValues(alpha: 0.90),
                          dgBase.withValues(alpha: 0.80),
                          dgBase.withValues(alpha: 0.60),
                          Color.lerp(dgBase, const Color(0xFF080808), 0.55)!,
                          const Color(0xFF080808).withValues(alpha: 0.95),
                        ],
                        stops: const [0.0, 0.25, 0.50, 0.75, 1.0],
                      ),
                    ),
                  ),
                  // Subtle radial glow from top-center
                  Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0.0, -0.55),
                        radius: 1.4,
                        colors: [
                          dgTop.withValues(alpha: 0.30),
                          dgTop.withValues(alpha: 0.08),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ],

                // ═══════════════════════════════════════════
                // GRADIENT MODE — Multi-color radial blobs
                // ═══════════════════════════════════════════
                if (useColor && isGradient) ...[
                  // Blob 1 — Top-left (color 1)
                  Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(-0.85, -0.65),
                        radius: 1.35,
                        colors: [
                          c1.withValues(alpha: 0.45),
                          c1.withValues(alpha: 0.18),
                          c1.withValues(alpha: 0.04),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.3, 0.6, 1.0],
                      ),
                    ),
                  ),
                  // Blob 2 — Top-right (color 2)
                  Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0.85, -0.40),
                        radius: 1.15,
                        colors: [
                          c2.withValues(alpha: 0.40),
                          c2.withValues(alpha: 0.15),
                          c2.withValues(alpha: 0.03),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.3, 0.6, 1.0],
                      ),
                    ),
                  ),
                  // Blob 3 — Bottom-right (color 3)
                  Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0.60, 0.85),
                        radius: 1.20,
                        colors: [
                          c3.withValues(alpha: 0.35),
                          c3.withValues(alpha: 0.12),
                          c3.withValues(alpha: 0.03),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.3, 0.6, 1.0],
                      ),
                    ),
                  ),
                  // Blob 4 — Center (blend c1+c2)
                  Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0.0, -0.05),
                        radius: 0.90,
                        colors: [
                          cMix12.withValues(alpha: 0.20),
                          cMix12.withValues(alpha: 0.05),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                  // Blob 5 — Bottom-left (blend c1+c3)
                  Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(-0.70, 0.75),
                        radius: 1.0,
                        colors: [
                          cMix13.withValues(alpha: 0.25),
                          cMix13.withValues(alpha: 0.06),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.4, 1.0],
                      ),
                    ),
                  ),
                ],

                // ── Subtle vignette for controls readability ──
                if (useColor)
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.transparent,
                          const Color(0xFF080808).withValues(alpha: 0.30),
                          const Color(0xFF080808).withValues(alpha: 0.70),
                        ],
                        stops: const [0.0, 0.55, 0.82, 1.0],
                      ),
                    ),
                  ),
                      // ── Vinyl: extra radial glow center ──
                      if (npStyle == NowPlayingStyle.vinyl && useColor)
                        Container(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: Alignment.center,
                              radius: 0.85,
                              colors: [
                                c1.withValues(alpha: 0.25),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            _NowPlayingContent(rawVibrant: _rawVibrant),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// CONTENT LAYOUT — proportional to screen height
// ============================================================

class _NowPlayingContent extends ConsumerWidget {
  const _NowPlayingContent({required this.rawVibrant});
  final Color rawVibrant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only rebuild on song change — progress/controls watch their own state
    final song = ref.watch(playerProvider.select((s) => s.currentSong));
    final hasSong = ref.watch(playerProvider.select((s) => s.hasSong));
    final themeState = ref.watch(themeProvider);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final mq = MediaQuery.of(context);
    final screenH = mq.size.height;
    final isCompact = screenH < 700;

    if (!hasSong) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.music_note_rounded,
              size: 64,
              color: colors.onSurface.withValues(alpha: 0.15),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Nenhuma música selecionada',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      );
    }

    final Song currentSong = song!;
    final artColor = ref.watch(artworkColorProvider);
    final isLandscape = mq.orientation == Orientation.landscape;

    // Compute accent color from rawVibrant for controls
    final bool hasVibrant = rawVibrant != const Color(0xFF1A1A2E);
    final Color accentColor;
    if (hasVibrant) {
      final hsl = HSLColor.fromColor(rawVibrant);
      accentColor = hsl
          .withLightness(hsl.lightness.clamp(0.55, 0.75))
          .withSaturation((hsl.saturation * 1.3).clamp(0.50, 1.0))
          .toColor();
    } else {
      accentColor = colors.primary;
    }

    final overlayGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: switch (themeState.nowPlayingStyle) {
        NowPlayingStyle.classic => [
          Colors.transparent,
          Colors.transparent,
          const Color(0xFF080808).withValues(alpha: 0.35),
        ],
        NowPlayingStyle.circular => [
          Colors.transparent,
          Colors.transparent,
          const Color(0xFF050505).withValues(alpha: 0.40),
        ],
        NowPlayingStyle.large => [
          Colors.transparent,
          Colors.transparent,
          const Color(0xFF080808).withValues(alpha: 0.30),
        ],
        NowPlayingStyle.fullBlur => [
          Colors.transparent,
          Colors.transparent,
          const Color(0xFF0A0A0A).withValues(alpha: 0.20),
        ],
        NowPlayingStyle.vinyl => [
          Colors.transparent,
          Colors.transparent,
          const Color(0xFF080808).withValues(alpha: 0.35),
        ],
        NowPlayingStyle.minimalist => [
          Colors.transparent,
          Colors.transparent,
          Colors.transparent,
        ],
        NowPlayingStyle.aurora => [
          Colors.transparent,
          Colors.transparent,
          const Color(0xFF080808).withValues(alpha: 0.15),
        ],
        NowPlayingStyle.elegant => [
          Colors.transparent,
          Colors.transparent,
          const Color(0xFF0C0C0F).withValues(alpha: 0.30),
        ],
        NowPlayingStyle.wave => [
          Colors.transparent,
          Colors.transparent,
          const Color(0xFF080808).withValues(alpha: 0.30),
        ],
        NowPlayingStyle.mosaic => [
          Colors.transparent,
          Colors.transparent,
          const Color(0xFF080808).withValues(alpha: 0.25),
        ],
      },
    );

    final titleBlock = Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    final albums = ref.read(libraryProvider).albums;
                    final album = albums
                        .where(
                          (a) =>
                              a.name.toLowerCase() ==
                              currentSong.album.toLowerCase(),
                        )
                        .firstOrNull;
                    if (album != null) {
                      Navigator.of(context).push(
                        AppPageRoute(
                          page: AlbumDetailPage(album: album),
                        ),
                      );
                    }
                  },
                  child: Text(
                    currentSong.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _FavoriteBtn(colors: colors),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          ArtistLinksText(
            artist: currentSong.artist,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.55),
              fontWeight: FontWeight.w400,
            ),
            suffix: ' · ${currentSong.album}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          _AnalysisBadge(colors: colors),
        ],
      ),
    );

    final Widget body = isLandscape
        ? _LandscapeLayout(
            mq: mq,
            theme: theme,
            colors: colors,
            accentColor: accentColor,
            artColor: artColor,
            song: currentSong,
            npStyle: themeState.nowPlayingStyle,
            titleBlock: titleBlock,
          )
        : Column(
            children: [
              SizedBox(height: mq.padding.top),
              _Header(colors: colors, song: currentSong),
              SizedBox(height: isCompact ? 8 : screenH * 0.02),
              Expanded(
                flex: isCompact ? 4 : 5,
                child: Center(
                  child: _ArtworkCarousel(
                    npStyle: themeState.nowPlayingStyle,
                    colors: colors,
                    artColor: artColor,
                  ),
                ),
              ),
              SizedBox(height: isCompact ? 12 : screenH * 0.025),
              titleBlock,
              SizedBox(height: isCompact ? 16 : AppSpacing.lg),
              _ProgressBar(
                theme: theme,
                colors: colors,
                accentColor: accentColor,
              ),
              SizedBox(height: isCompact ? 8 : AppSpacing.md),
              _MainControls(colors: colors, accentColor: accentColor),
              SizedBox(height: isCompact ? 8 : AppSpacing.lg),
              _SecondaryActions(
                colors: colors,
                theme: theme,
                accentColor: accentColor,
              ),
              const SizedBox(height: AppSpacing.xs),
              _UpNextPreview(colors: colors, theme: theme),
              SizedBox(height: mq.padding.bottom + AppSpacing.sm),
            ],
          );

    return GestureDetector(
      onVerticalDragEnd: (d) {
        if (d.primaryVelocity != null && d.primaryVelocity! > 300) {
          Navigator.of(context).pop();
        }
      },
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: overlayGradient),
        child: body,
      ),
    );
  }
}

// ============================================================
// LANDSCAPE LAYOUT — artwork à esquerda, controles à direita
// ============================================================

class _LandscapeLayout extends StatelessWidget {
  const _LandscapeLayout({
    required this.mq,
    required this.theme,
    required this.colors,
    required this.accentColor,
    required this.artColor,
    required this.song,
    required this.npStyle,
    required this.titleBlock,
  });

  final MediaQueryData mq;
  final ThemeData theme;
  final ColorScheme colors;
  final Color accentColor;
  final Color? artColor;
  final Song song;
  final NowPlayingStyle npStyle;
  final Widget titleBlock;

  @override
  Widget build(BuildContext context) {
    // Em landscape, o width vira o eixo dominante. A altura disponível é
    // o limitante do artwork — uso height pra dimensionar o carousel.
    return Padding(
      padding: EdgeInsets.only(
        top: mq.padding.top,
        bottom: mq.padding.bottom,
        left: mq.padding.left,
        right: mq.padding.right,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Lado esquerdo: artwork ──
          Expanded(
            flex: 5,
            child: Center(
              child: _LandscapeArtworkCarousel(
                npStyle: npStyle,
                colors: colors,
                artColor: artColor,
              ),
            ),
          ),
          // ── Lado direito: header + info + controles ──
          Expanded(
            flex: 6,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Header(colors: colors, song: song),
                const SizedBox(height: AppSpacing.sm),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        titleBlock,
                        const SizedBox(height: AppSpacing.md),
                        _ProgressBar(
                          theme: theme,
                          colors: colors,
                          accentColor: accentColor,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _MainControls(
                          colors: colors,
                          accentColor: accentColor,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _SecondaryActions(
                          colors: colors,
                          theme: theme,
                          accentColor: accentColor,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        _UpNextPreview(colors: colors, theme: theme),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Carousel variant para landscape — dimensiona pelo height
class _LandscapeArtworkCarousel extends ConsumerWidget {
  const _LandscapeArtworkCarousel({
    required this.npStyle,
    required this.colors,
    required this.artColor,
  });

  final NowPlayingStyle npStyle;
  final ColorScheme colors;
  final Color? artColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Em landscape, o artwork cabe no menor dos dois: altura disponível
    // ou metade da largura. O _ArtworkCarousel interno já usa width do
    // MediaQuery; envolver em SizedBox quadrado mantém proporção.
    final mq = MediaQuery.of(context);
    final targetSize = (mq.size.height * 0.78).clamp(
      0.0,
      mq.size.width * 0.48,
    );
    return SizedBox(
      width: targetSize,
      height: targetSize,
      child: MediaQuery(
        // Força o _ArtworkCarousel a usar largura = targetSize (e não screen width)
        data: mq.copyWith(size: Size(targetSize, targetSize)),
        child: _ArtworkCarousel(
          npStyle: npStyle,
          colors: colors,
          artColor: artColor,
        ),
      ),
    );
  }
}

// ============================================================
// HEADER — minimal com indicadores
// ============================================================

class _Header extends ConsumerWidget {
  const _Header({required this.colors, required this.song});
  final ColorScheme colors;
  final Song song;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 32,
              color: colors.onSurface.withValues(alpha: 0.9),
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'TOCANDO AGORA',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.45),
                    letterSpacing: 2.5,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                // Status indicators row
                Consumer(
                  builder: (_, ref, __) {
                    final audioState = ref.watch(audioSettingsProvider);
                    final speed = audioState.playbackSpeed;
                    final hasTimer = audioState.hasSleepTimer;
                    final hasSpeed = (speed - 1.0).abs() > 0.01;
                    if (!hasTimer && !hasSpeed) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (hasTimer) ...[
                            Consumer(
                              builder: (_, cRef, __) {
                                final artColor = cRef.watch(
                                  artworkColorProvider,
                                );
                                return _SleepTimerCircle(
                                  endTime: audioState.sleepTimerEndTime,
                                  totalMinutes: audioState.sleepTimerMinutes,
                                  color: artColor ?? colors.primary,
                                );
                              },
                            ),
                            const SizedBox(width: 4),
                            Text(
                              audioState.sleepTimerLabel,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colors.onSurface.withValues(alpha: 0.35),
                                fontSize: 9,
                              ),
                            ),
                          ],
                          if (hasTimer && hasSpeed) const SizedBox(width: 8),
                          if (hasSpeed)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: colors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusXs,
                                ),
                              ),
                              child: Text(
                                audioState.speedLabel,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colors.primary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.more_vert_rounded,
              color: colors.onSurface.withValues(alpha: 0.6),
            ),
            onPressed: () => _showSongMenu(context, ref),
          ),
        ],
      ),
    );
  }

  void _showSongMenu(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final playerState = ref.read(playerProvider);
    final currentSong = playerState.currentSong;
    if (currentSong == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.75,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: AppSpacing.xs),
                Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                // Song header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      ArtworkImage.song(
                        songId: currentSong.numericId,
                        size: 48,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusSm,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentSong.title,
                              style: theme.textTheme.titleSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              currentSong.artist,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurface.withValues(alpha: 0.5),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Divider(color: colors.outline.withValues(alpha: 0.15)),
                // Actions
                // ── Favoritos ──
                StatefulBuilder(
                  builder: (_, setState) {
                    final isFav =
                        ref.read(playerProvider).currentSong?.isFavorite ??
                        false;
                    return ListTile(
                      leading: Icon(
                        isFav
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: isFav
                            ? colors.error
                            : colors.onSurface.withValues(alpha: 0.7),
                      ),
                      title: Text(
                        isFav
                            ? 'Remover dos Favoritos'
                            : 'Adicionar aos Favoritos',
                        style: theme.textTheme.bodyMedium,
                      ),
                      onTap: () {
                        ref.read(playerProvider.notifier).toggleFavorite();
                        final updatedSongs = ref.read(libraryProvider).songs;
                        ref
                            .read(playlistProvider.notifier)
                            .syncFavorites(updatedSongs);
                        setState(() {});
                      },
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.playlist_play_rounded,
                    color: colors.onSurface.withValues(alpha: 0.7),
                  ),
                  title: Text(
                    'Tocar em Seguida',
                    style: theme.textTheme.bodyMedium,
                  ),
                  onTap: () {
                    ctx.pop();
                    ref
                        .read(playerProvider.notifier)
                        .addNextInQueue(currentSong);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Adicionado à fila'),
                        backgroundColor: colors.onSurface,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusSm,
                          ),
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.playlist_add_rounded,
                    color: colors.onSurface.withValues(alpha: 0.7),
                  ),
                  title: Text(
                    'Adicionar a Playlist',
                    style: theme.textTheme.bodyMedium,
                  ),
                  onTap: () {
                    ctx.pop();
                    _showAddToPlaylistDialog(context, ref, currentSong);
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.person_outline_rounded,
                    color: colors.onSurface.withValues(alpha: 0.7),
                  ),
                  title: Text(
                    'Ir para Artista',
                    style: theme.textTheme.bodyMedium,
                  ),
                  onTap: () {
                    ctx.pop();
                    final allArtists = ref.read(libraryProvider).artists;
                    final names = ArtistLinksText.splitArtists(
                      currentSong.artist,
                    );
                    final found = names
                        .map(
                          (n) => allArtists
                              .where(
                                (a) => a.name.toLowerCase() == n.toLowerCase(),
                              )
                              .firstOrNull,
                        )
                        .nonNulls
                        .toList();
                    if (found.length == 1) {
                      Navigator.of(context).push(
                        AppPageRoute(
                          page: ArtistDetailPage(artist: found.first),
                        ),
                      );
                    } else if (found.length > 1) {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: colors.surfaceContainer,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(AppSpacing.radiusXl),
                          ),
                        ),
                        builder: (innerCtx) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: AppSpacing.xs),
                              Container(
                                width: 32,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: colors.outline.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                ),
                                child: Text(
                                  'Escolher Artista',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: colors.onSurface.withValues(
                                      alpha: 0.7,
                                    ),
                                  ),
                                ),
                              ),
                              Divider(
                                color: colors.outline.withValues(alpha: 0.15),
                              ),
                              for (final a in found)
                                ListTile(
                                  leading: const Icon(
                                    Icons.person_outline_rounded,
                                  ),
                                  title: Text(a.name),
                                  onTap: () {
                                    Navigator.pop(innerCtx);
                                    Navigator.of(context).push(
                                      AppPageRoute(
                                        page: ArtistDetailPage(artist: a),
                                      ),
                                    );
                                  },
                                ),
                              const SizedBox(height: AppSpacing.md),
                            ],
                          ),
                        ),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.album_outlined,
                    color: colors.onSurface.withValues(alpha: 0.7),
                  ),
                  title: Text(
                    'Ir para Álbum',
                    style: theme.textTheme.bodyMedium,
                  ),
                  onTap: () {
                    ctx.pop();
                    final albums = ref.read(libraryProvider).albums;
                    final album = albums
                        .where(
                          (a) =>
                              a.name.toLowerCase() ==
                              currentSong.album.toLowerCase(),
                        )
                        .firstOrNull;
                    if (album != null) {
                      Navigator.of(
                        context,
                      ).push(AppPageRoute(page: AlbumDetailPage(album: album)));
                    }
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.share_outlined,
                    color: colors.onSurface.withValues(alpha: 0.7),
                  ),
                  title: Text('Partilhar', style: theme.textTheme.bodyMedium),
                  onTap: () {
                    ctx.pop();
                    final text =
                        '${currentSong.title} - ${currentSong.artist}'
                        '\nÁlbum: ${currentSong.album}';
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Info da música copiada!',
                          style: TextStyle(color: colors.surface),
                        ),
                        backgroundColor: colors.onSurface,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusSm,
                          ),
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.edit_rounded,
                    color: colors.onSurface.withValues(alpha: 0.7),
                  ),
                  title: Text(
                    'Editar / Detalhes',
                    style: theme.textTheme.bodyMedium,
                  ),
                  onTap: () {
                    ctx.pop();
                    Navigator.push(
                      context,
                      AppPageRoute(page: SongEditPage(song: currentSong)),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddToPlaylistDialog(
    BuildContext context,
    WidgetRef ref,
    Song song,
  ) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final userPlaylists = ref.read(userPlaylistsProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.6,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: AppSpacing.xs),
                Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    'Adicionar a Playlist',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (userPlaylists.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      'Nenhuma playlist criada',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  )
                else
                  ...userPlaylists.map(
                    (p) => ListTile(
                      leading: Icon(
                        Icons.queue_music_rounded,
                        color: colors.onSurface.withValues(alpha: 0.5),
                      ),
                      title: Text(p.name),
                      subtitle: Text(
                        '${p.songCount} músicas',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                      onTap: () {
                        ref
                            .read(playlistProvider.notifier)
                            .addSongToPlaylist(p.id, song);
                        ctx.pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Adicionada a "${p.name}"'),
                            backgroundColor: colors.onSurface,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusSm,
                              ),
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// ARTWORK CAROUSEL — ViewPager2-style with PageTransformer
// ============================================================

class _ArtworkCarousel extends ConsumerStatefulWidget {
  const _ArtworkCarousel({
    required this.npStyle,
    required this.colors,
    this.artColor,
  });
  final NowPlayingStyle npStyle;
  final ColorScheme colors;
  final Color? artColor;

  @override
  ConsumerState<_ArtworkCarousel> createState() => _ArtworkCarouselState();
}

class _ArtworkCarouselState extends ConsumerState<_ArtworkCarousel> {
  late PageController _pageCtrl;
  int _currentPage = 0;
  bool _syncing = false; // prevents feedback loop on external changes

  @override
  void initState() {
    super.initState();
    final idx = ref.read(playerProvider).currentIndex;
    _currentPage = idx < 0 ? 0 : idx;
    _pageCtrl = PageController(
      viewportFraction: 0.82,
      initialPage: _currentPage,
    );
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    if (_syncing) return;
    _currentPage = index;
    ref.read(playerProvider.notifier).playIndex(index);
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final queue = playerState.queue;
    final currentIdx = playerState.currentIndex;

    // Sync carousel when song changes externally (notification, mini player)
    ref.listen<int>(playerProvider.select((s) => s.currentIndex), (prev, next) {
      if (next >= 0 && next != _currentPage && _pageCtrl.hasClients) {
        _syncing = true;
        _currentPage = next;
        _pageCtrl
            .animateToPage(
              next,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
            )
            .then((_) => _syncing = false);
      }
    });

    if (queue.isEmpty) {
      return SizedBox(
        width: MediaQuery.sizeOf(context).width * 0.74,
        height: MediaQuery.sizeOf(context).width * 0.74,
        child: const Center(
          child: Icon(
            Icons.music_note_rounded,
            size: 80,
            color: Colors.white24,
          ),
        ),
      );
    }

    final screenW = MediaQuery.sizeOf(context).width;
    // Height depends on style shape
    final isCircular =
        widget.npStyle == NowPlayingStyle.circular ||
        widget.npStyle == NowPlayingStyle.fullBlur ||
        widget.npStyle == NowPlayingStyle.vinyl ||
        widget.npStyle == NowPlayingStyle.aurora;
    final artSize = isCircular ? screenW * 0.68 : screenW * 0.74;

    return SizedBox(
      height: artSize + 16, // extra space for depth translation
      child: PageView.builder(
        controller: _pageCtrl,
        itemCount: queue.length,
        onPageChanged: _onPageChanged,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          return AnimatedBuilder(
            animation: _pageCtrl,
            builder: (context, child) {
              double page = _currentPage.toDouble();
              try {
                if (_pageCtrl.hasClients &&
                    _pageCtrl.position.hasContentDimensions) {
                  page = _pageCtrl.page ?? page;
                }
              } catch (_) {}

              final offset = index - page;
              final absOffset = offset.abs().clamp(0.0, 1.0);

              // PageTransformer: scale + vertical depth
              final scale = 1.0 - absOffset * 0.15; // 1.0 → 0.85
              final translateY = absOffset * 12.0; // depth effect

              return Transform.translate(
                offset: Offset(0, translateY),
                child: Transform.scale(
                  scale: scale,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: child,
                  ),
                ),
              );
            },
            child: RepaintBoundary(
              child: GestureDetector(
                onDoubleTap: () =>
                    ref.read(playerProvider.notifier).toggleFavorite(),
                child: Hero(
                  tag: 'artwork_${queue[index].numericId}',
                  child: _buildStyleWidget(
                    songId: queue[index].numericId,
                    isCurrentPage: index == currentIdx,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStyleWidget({required int songId, required bool isCurrentPage}) {
    switch (widget.npStyle) {
      case NowPlayingStyle.classic:
        return _ClassicAlbumArt(
          colors: widget.colors,
          artColor: widget.artColor,
          songId: songId,
        );
      case NowPlayingStyle.circular:
        return _CircularAlbumArt(
          colors: widget.colors,
          artColor: widget.artColor,
          songId: songId,
          isCurrentPage: isCurrentPage,
        );
      case NowPlayingStyle.large:
        return _LargeAlbumArt(
          colors: widget.colors,
          artColor: widget.artColor,
          songId: songId,
        );
      case NowPlayingStyle.fullBlur:
        return _FullBlurAlbumArt(
          colors: widget.colors,
          artColor: widget.artColor,
          songId: songId,
        );
      case NowPlayingStyle.vinyl:
        return _VinylAlbumArt(
          colors: widget.colors,
          artColor: widget.artColor,
          songId: songId,
          isCurrentPage: isCurrentPage,
        );
      case NowPlayingStyle.minimalist:
        return _MinimalistAlbumArt(
          colors: widget.colors,
          artColor: widget.artColor,
          songId: songId,
        );
      case NowPlayingStyle.aurora:
        return _AuroraAlbumArt(
          colors: widget.colors,
          artColor: widget.artColor,
          songId: songId,
          isCurrentPage: isCurrentPage,
        );
      case NowPlayingStyle.elegant:
        return _ElegantAlbumArt(
          colors: widget.colors,
          artColor: widget.artColor,
          songId: songId,
        );
      case NowPlayingStyle.wave:
        return _WaveAlbumArt(
          colors: widget.colors,
          artColor: widget.artColor,
          songId: songId,
          isCurrentPage: isCurrentPage,
        );
      case NowPlayingStyle.mosaic:
        return _MosaicAlbumArt(
          colors: widget.colors,
          artColor: widget.artColor,
          songId: songId,
        );
    }
  }
}

// ============================================================
// ESTILO 1: CLASSIC — square 74% + vivid colored shadow
// ============================================================

class _ClassicAlbumArt extends ConsumerWidget {
  const _ClassicAlbumArt({
    super.key,
    required this.colors,
    this.artColor,
    required this.songId,
  });
  final ColorScheme colors;
  final Color? artColor;
  final int songId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.sizeOf(context).width * 0.74;
    final glow = artColor ?? colors.primary;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: [
          BoxShadow(
            color: glow.withValues(alpha: 0.28),
            blurRadius: 38,
            spreadRadius: -4,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ArtworkImage.song(
              songId: songId,
              size: size,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              placeholderIconSize: 80,
            ),
            // Subtle inner rim light — lifts the artwork "off" the surface
            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 0.8,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ESTILO 2: CIRCULAR — breathing pulse + colored glow
// ============================================================

class _CircularAlbumArt extends ConsumerStatefulWidget {
  const _CircularAlbumArt({
    super.key,
    required this.colors,
    this.artColor,
    required this.songId,
    required this.isCurrentPage,
  });
  final ColorScheme colors;
  final Color? artColor;
  final int songId;
  final bool isCurrentPage;

  @override
  ConsumerState<_CircularAlbumArt> createState() => _CircularAlbumArtState();
}

class _CircularAlbumArtState extends ConsumerState<_CircularAlbumArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleCtrl;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
      lowerBound: 0.97,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context).width * 0.68;
    final isPlaying = ref.watch(playerProvider.select((s) => s.isPlaying));

    final shouldAnimate = widget.isCurrentPage && isPlaying;
    if (shouldAnimate && !_scaleCtrl.isAnimating) {
      _scaleCtrl.repeat(reverse: true);
    } else if (!shouldAnimate && _scaleCtrl.isAnimating) {
      _scaleCtrl.animateTo(1.0);
    }

    final glow = widget.artColor ?? widget.colors.primary;

    return AnimatedBuilder(
      animation: _scaleCtrl,
      builder: (_, child) =>
          Transform.scale(scale: _scaleCtrl.value, child: child),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: glow.withValues(alpha: 0.38),
              blurRadius: 50,
              spreadRadius: -2,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipOval(
              child: ArtworkImage.song(
                songId: widget.songId,
                size: size,
                isCircle: true,
                placeholderIconSize: 80,
              ),
            ),
            // Outer accent ring (very thin, breathes with the pulse)
            IgnorePointer(
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: glow.withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                ),
              ),
            ),
            // Inner rim highlight — glass effect
            IgnorePointer(
              child: Container(
                width: size - 6,
                height: size - 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                    width: 0.8,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ESTILO 3: LARGE — edge-to-edge + colored glow
// ============================================================

class _LargeAlbumArt extends ConsumerWidget {
  const _LargeAlbumArt({
    super.key,
    required this.colors,
    this.artColor,
    required this.songId,
  });
  final ColorScheme colors;
  final Color? artColor;
  final int songId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = MediaQuery.sizeOf(context).width;
    final size = w - AppSpacing.xs * 2;
    final glow = artColor ?? colors.primary;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: [
          BoxShadow(
            color: glow.withValues(alpha: 0.28),
            blurRadius: 48,
            spreadRadius: -6,
            offset: const Offset(0, 22),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ArtworkImage.song(
              songId: songId,
              size: size,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              placeholderIconSize: 100,
            ),
            // Cinematic top vignette — darkens the upper edge subtly
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.18),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.22),
                    ],
                    stops: const [0.0, 0.22, 0.78, 1.0],
                  ),
                ),
              ),
            ),
            // Rim light
            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 0.8,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ESTILO 4: FULL BLUR — circle + immersive colored glow
// ============================================================

class _FullBlurAlbumArt extends ConsumerWidget {
  const _FullBlurAlbumArt({
    super.key,
    required this.colors,
    this.artColor,
    required this.songId,
  });
  final ColorScheme colors;
  final Color? artColor;
  final int songId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.sizeOf(context).width * 0.64;
    final glow = artColor ?? colors.primary;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          // Outer aurora glow
          BoxShadow(
            color: glow.withValues(alpha: 0.45),
            blurRadius: 60,
            spreadRadius: 4,
          ),
          BoxShadow(
            color: glow.withValues(alpha: 0.25),
            blurRadius: 90,
            spreadRadius: 10,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipOval(
            child: ArtworkImage.song(
              songId: songId,
              size: size,
              isCircle: true,
              placeholderIconSize: 72,
            ),
          ),
          // Outer thin accent ring
          IgnorePointer(
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: glow.withValues(alpha: 0.55),
                  width: 1.2,
                ),
              ),
            ),
          ),
          // Inner glass rim
          IgnorePointer(
            child: Container(
              width: size - 6,
              height: size - 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 0.8,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Blurred artwork background ──
class _BlurredArtworkBg extends ConsumerWidget {
  const _BlurredArtworkBg({required this.songId, this.opacity = 0.4});
  final int songId;
  final double opacity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(artworkProvider.notifier);
    ref.watch(
      artworkProvider.select((_) {
        return identityHashCode(notifier.getArtwork(songId, ArtworkType.AUDIO));
      }),
    );
    final data = notifier.getArtwork(songId, ArtworkType.AUDIO);
    if (data == null || data.isEmpty) return const SizedBox.shrink();
    return RepaintBoundary(
      child: Opacity(
        opacity: opacity,
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 38, sigmaY: 38),
          child: Image.memory(
            data,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            gaplessPlayback: true,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// PROGRESS BAR — with remaining time display
// ============================================================

class _ProgressBar extends ConsumerWidget {
  const _ProgressBar({
    required this.theme,
    required this.colors,
    required this.accentColor,
  });
  final ThemeData theme;
  final ColorScheme colors;
  final Color accentColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(playerProvider.select((s) => s.progress));
    final position = ref.watch(playerProvider.select((s) => s.position));
    final duration = ref.watch(playerProvider.select((s) => s.duration));
    final positionFormatted = ref.watch(
      playerProvider.select((s) => s.positionFormatted),
    );
    final mediaBarStyle = ref.watch(
      themeProvider.select((s) => s.mediaBarStyle),
    );
    final sliderTheme = switch (mediaBarStyle) {
      MediaBarStyle.minimal => SliderTheme.of(context).copyWith(
        trackHeight: 2.0,
        thumbShape: SliderComponentShape.noThumb,
        overlayShape: SliderComponentShape.noOverlay,
        activeTrackColor: colors.onSurface.withValues(alpha: 0.8),
        inactiveTrackColor: colors.onSurface.withValues(alpha: 0.10),
      ),
      MediaBarStyle.glow => SliderTheme.of(context).copyWith(
        trackHeight: 3.5,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
        activeTrackColor: accentColor,
        inactiveTrackColor: accentColor.withValues(alpha: 0.15),
        thumbColor: Colors.white,
        overlayColor: accentColor.withValues(alpha: 0.35),
      ),
      MediaBarStyle.gradient => SliderTheme.of(context).copyWith(
        trackHeight: 4.5,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
        activeTrackColor: accentColor,
        inactiveTrackColor: colors.onSurface.withValues(alpha: 0.10),
        thumbColor: Colors.white,
        trackShape: _GradientSliderTrackShape(
          gradientColors: [accentColor, colors.secondary, colors.tertiary],
        ),
      ),
      MediaBarStyle.thick => SliderTheme.of(context).copyWith(
        trackHeight: 10,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 22),
        activeTrackColor: accentColor,
        inactiveTrackColor: colors.onSurface.withValues(alpha: 0.12),
        thumbColor: Colors.white,
      ),
      MediaBarStyle.classic => SliderTheme.of(context).copyWith(
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
        activeTrackColor: Colors.white,
        inactiveTrackColor: Colors.white.withValues(alpha: 0.20),
        thumbColor: Colors.white,
      ),
    };

    // Remaining time as negative
    final remaining = duration - position;
    final remMin = remaining.inMinutes;
    final remSec = remaining.inSeconds.remainder(60).abs();
    final remStr = '-$remMin:${remSec.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        children: [
          SliderTheme(
            data: sliderTheme,
            child: Slider(
              value: progress.clamp(0.0, 1.0),
              onChanged: (value) {
                ref
                    .read(playerProvider.notifier)
                    .seek(
                      Duration(
                        milliseconds: (value * duration.inMilliseconds).round(),
                      ),
                    );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  positionFormatted,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.4),
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                  ),
                ),
                Text(
                  remStr,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.4),
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// MAIN CONTROLS — with colored prev/next
// ============================================================

class _MainControls extends ConsumerWidget {
  const _MainControls({required this.colors, required this.accentColor});
  final ColorScheme colors;
  final Color accentColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlaying = ref.watch(playerProvider.select((s) => s.isPlaying));
    final shuffleEnabled = ref.watch(
      playerProvider.select((s) => s.shuffleEnabled),
    );
    final repeatMode = ref.watch(playerProvider.select((s) => s.repeatMode));
    final n = ref.read(playerProvider.notifier);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _accentIcon(
            Icons.shuffle_rounded,
            22,
            active: shuffleEnabled,
            onTap: n.toggleShuffle,
            activeColor: accentColor,
          ),
          _TapScaleWidget(
            onTap: n.previous,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: Icon(
                Icons.skip_previous_rounded,
                size: AppSpacing.iconXl,
                color: accentColor.withValues(alpha: 0.85),
              ),
            ),
          ),
          _PlayPauseBtn(
            isPlaying: isPlaying,
            onTap: n.togglePlayPause,
            colors: colors,
            accentColor: accentColor,
          ),
          _TapScaleWidget(
            onTap: n.next,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: Icon(
                Icons.skip_next_rounded,
                size: AppSpacing.iconXl,
                color: accentColor.withValues(alpha: 0.85),
              ),
            ),
          ),
          _accentIcon(
            repeatMode == RepeatMode.one
                ? Icons.repeat_one_rounded
                : Icons.repeat_rounded,
            22,
            active: repeatMode != RepeatMode.off,
            onTap: n.cycleRepeatMode,
            activeColor: accentColor,
          ),
        ],
      ),
    );
  }

  Widget _accentIcon(
    IconData icon,
    double size, {
    required bool active,
    VoidCallback? onTap,
    Color? activeColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Icon(
          icon,
          size: size,
          color: active
              ? (activeColor ?? accentColor)
              : colors.onSurface.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

// ── Play/Pause button with tap scale ──
class _PlayPauseBtn extends StatefulWidget {
  const _PlayPauseBtn({
    required this.isPlaying,
    required this.onTap,
    required this.colors,
    required this.accentColor,
  });
  final bool isPlaying;
  final VoidCallback onTap;
  final ColorScheme colors;
  final Color accentColor;

  @override
  State<_PlayPauseBtn> createState() => _PlayPauseBtnState();
}

class _PlayPauseBtnState extends State<_PlayPauseBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.88,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _c.reverse(),
      onTapUp: (_) {
        _c.forward();
        widget.onTap();
      },
      onTapCancel: () => _c.forward(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) => Transform.scale(scale: _c.value, child: child),
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: widget.accentColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.accentColor.withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: AppConstants.fast,
            child: Icon(
              widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              key: ValueKey(widget.isPlaying),
              color: widget.accentColor.computeLuminance() > 0.5
                  ? Colors.black
                  : Colors.white,
              size: 36,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// FAVORITE BUTTON
// ============================================================

class _FavoriteBtn extends ConsumerWidget {
  const _FavoriteBtn({required this.colors});
  final ColorScheme colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav = ref.watch(
      playerProvider.select((s) => s.currentSong?.isFavorite ?? false),
    );
    return GestureDetector(
      onTap: () => ref.read(playerProvider.notifier).toggleFavorite(),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, anim) =>
              ScaleTransition(scale: anim, child: child),
          child: Icon(
            isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            key: ValueKey(isFav),
            size: 26,
            color: isFav
                ? Colors.redAccent
                : colors.onSurface.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// SECONDARY ACTIONS — fila, letras, EQ, velocidade
// ============================================================

class _SecondaryActions extends ConsumerWidget {
  const _SecondaryActions({
    required this.colors,
    required this.theme,
    required this.accentColor,
  });
  final ColorScheme colors;
  final ThemeData theme;
  final Color accentColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _action(
            icon: Icons.queue_music_rounded,
            label: 'Fila',
            onTap: () => Navigator.of(
              context,
            ).push(AppPageRoute(page: const _QueuePage())),
          ),
          _action(
            icon: Icons.lyrics_outlined,
            label: 'Letras',
            onTap: () {
              final song = ref.read(playerProvider).currentSong;
              if (song != null) {
                Navigator.of(
                  context,
                ).push(AppPageRoute(page: _LyricsPage(song: song)));
              }
            },
          ),
          Consumer(
            builder: (_, ref, __) {
              final eqOn = ref.watch(
                audioSettingsProvider.select((s) => s.eqEnabled),
              );
              return _action(
                icon: Icons.equalizer_rounded,
                label: 'EQ',
                active: eqOn,
                onTap: () => _showEqSheet(context, ref),
              );
            },
          ),
          Consumer(
            builder: (_, ref, __) {
              final speed = ref.watch(
                audioSettingsProvider.select((s) => s.playbackSpeed),
              );
              final isCustom = (speed - 1.0).abs() > 0.01;
              return _action(
                icon: Icons.speed_rounded,
                label: 'Veloc.',
                active: isCustom,
                onTap: () => _showSpeedSheet(context, ref),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _action({
    required IconData icon,
    required String label,
    bool active = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xxs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 21,
              color: active
                  ? accentColor
                  : colors.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 10,
                color: active
                    ? accentColor
                    : colors.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Equalizer Bottom Sheet ──
  void _showEqSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => const _EqBottomSheet(),
    );
  }

  // ── Speed Bottom Sheet ──
  void _showSpeedSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _SpeedBottomSheet(),
    );
  }
}

// ============================================================
// EQ BOTTOM SHEET — inline mini-EQ premium
// ============================================================

class _EqBottomSheet extends ConsumerWidget {
  const _EqBottomSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baseColors = Theme.of(context).colorScheme;
    final colors = baseColors.brightness == Brightness.dark
        ? baseColors
        : ColorScheme.dark(primary: baseColors.primary);
    final theme = Theme.of(context);
    final audioState = ref.watch(audioSettingsProvider);
    final notifier = ref.read(audioSettingsProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
        border: Border(
          top: BorderSide(color: colors.outline.withValues(alpha: 0.1)),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.xs),
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Header: título + toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  Icon(
                    Icons.equalizer_rounded,
                    size: 22,
                    color: audioState.eqEnabled
                        ? colors.primary
                        : Colors.white.withValues(alpha: 0.4),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Equalizador',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Switch.adaptive(
                    value: audioState.eqEnabled,
                    onChanged: (_) => notifier.toggleEq(),
                    activeTrackColor: colors.primary,
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                    thumbColor: WidgetStatePropertyAll(Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            // Presets
            AnimatedOpacity(
              opacity: audioState.eqEnabled ? 1.0 : 0.3,
              duration: const Duration(milliseconds: 200),
              child: AbsorbPointer(
                absorbing: !audioState.eqEnabled,
                child: Column(
                  children: [
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                        ),
                        itemCount: kEqPresets.length - 1,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: AppSpacing.xs),
                        itemBuilder: (_, i) {
                          final preset = kEqPresets[i];
                          final selected = audioState.eqPresetId == preset.id;
                          return GestureDetector(
                            onTap: () => notifier.setPreset(preset.id),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? colors.primary
                                    : Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusFull,
                                ),
                                border: Border.all(
                                  color: selected
                                      ? colors.primary
                                      : Colors.white.withValues(alpha: 0.12),
                                ),
                              ),
                              child: Text(
                                preset.name,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: selected
                                      ? colors.onPrimary
                                      : Colors.white.withValues(alpha: 0.6),
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // 5 Band mini-sliders
                    Container(
                      height: 180,
                      margin: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMd,
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Row(
                        children: [
                          // dB scale
                          Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '+12',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  fontSize: 8,
                                ),
                              ),
                              Text(
                                '0',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  fontSize: 8,
                                ),
                              ),
                              Text(
                                '-12',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  fontSize: 8,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 4),
                          ...List.generate(
                            5,
                            (i) => Expanded(
                              child: Column(
                                children: [
                                  Expanded(
                                    child: RotatedBox(
                                      quarterTurns: 3,
                                      child: SliderTheme(
                                        data: SliderTheme.of(context).copyWith(
                                          trackHeight: 2.5,
                                          thumbShape:
                                              const RoundSliderThumbShape(
                                                enabledThumbRadius: 6,
                                              ),
                                          activeTrackColor: colors.primary,
                                          inactiveTrackColor: Colors.white
                                              .withValues(alpha: 0.08),
                                          thumbColor: Colors.white,
                                          overlayShape:
                                              const RoundSliderOverlayShape(
                                                overlayRadius: 12,
                                              ),
                                        ),
                                        child: Slider(
                                          value: audioState.eqBands[i],
                                          min: -12,
                                          max: 12,
                                          onChanged: (v) =>
                                              notifier.setBand(i, v),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    kBandLabels[i],
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.35,
                                      ),
                                      fontSize: 8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // Bass Boost + Virtualizer compact
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _MiniEffectSlider(
                              label: 'Bass',
                              value: audioState.bassBoost,
                              max: 10,
                              color: colors.primary,
                              onChanged: notifier.setBassBoost,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: _MiniEffectSlider(
                              label: 'Virtual',
                              value: audioState.virtualizer,
                              max: 10,
                              color: colors.primary,
                              onChanged: notifier.setVirtualizer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

// Mini effect slider for EQ sheet
class _MiniEffectSlider extends StatelessWidget {
  const _MiniEffectSlider({
    required this.label,
    required this.value,
    required this.max,
    required this.color,
    required this.onChanged,
  });
  final String label;
  final double value;
  final double max;
  final Color color;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value == 0 ? 'Off' : value.round().toString(),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 10,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
            activeTrackColor: color,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.08),
            thumbColor: Colors.white,
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
          ),
          child: Slider(value: value, min: 0, max: max, onChanged: onChanged),
        ),
      ],
    );
  }
}

// ============================================================
// SPEED BOTTOM SHEET — premium speed selector
// ============================================================

class _SpeedBottomSheet extends ConsumerStatefulWidget {
  const _SpeedBottomSheet();

  @override
  ConsumerState<_SpeedBottomSheet> createState() => _SpeedBottomSheetState();
}

class _SpeedBottomSheetState extends ConsumerState<_SpeedBottomSheet> {
  late double _currentSpeed;

  static const _presets = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
  static const _presetLabels = [
    '0.5x',
    '0.75x',
    '1x',
    '1.25x',
    '1.5x',
    '1.75x',
    '2x',
  ];

  @override
  void initState() {
    super.initState();
    _currentSpeed = ref.read(audioSettingsProvider).playbackSpeed;
  }

  void _setSpeed(double speed) {
    setState(() => _currentSpeed = speed);
    ref.read(audioSettingsProvider.notifier).setPlaybackSpeed(speed);
    ref.read(playerProvider.notifier).setSpeed(speed);
  }

  @override
  Widget build(BuildContext context) {
    final baseColors = Theme.of(context).colorScheme;
    final colors = baseColors.brightness == Brightness.dark
        ? baseColors
        : ColorScheme.dark(primary: baseColors.primary);
    final theme = Theme.of(context);
    final isCustom = (_currentSpeed - 1.0).abs() > 0.01;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
        border: Border(
          top: BorderSide(color: colors.outline.withValues(alpha: 0.1)),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.xs),
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Current speed display
            Text(
              '${_currentSpeed.toStringAsFixed(_currentSpeed == _currentSpeed.roundToDouble() ? 1 : 2)}x',
              style: theme.textTheme.displaySmall?.copyWith(
                color: isCustom ? colors.primary : Colors.white,
                fontWeight: FontWeight.w300,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Velocidade de reprodução',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Slider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 8,
                      ),
                      activeTrackColor: colors.primary,
                      inactiveTrackColor: Colors.white.withValues(alpha: 0.08),
                      thumbColor: Colors.white,
                      overlayColor: colors.primary.withValues(alpha: 0.2),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 18,
                      ),
                    ),
                    child: Slider(
                      value: _currentSpeed,
                      min: 0.5,
                      max: 2.0,
                      divisions: 30, // 0.05 steps
                      onChanged: _setSpeed,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xxs,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '0.5x',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.25),
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          '2.0x',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.25),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Preset chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                alignment: WrapAlignment.center,
                children: List.generate(_presets.length, (i) {
                  final speed = _presets[i];
                  final selected = (_currentSpeed - speed).abs() < 0.01;
                  final isNormal = speed == 1.0;
                  return GestureDetector(
                    onTap: () => _setSpeed(speed),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? colors.primary
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusFull,
                        ),
                        border: Border.all(
                          color: selected
                              ? colors.primary
                              : isNormal
                              ? Colors.white.withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Text(
                        _presetLabels[i],
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: selected
                              ? colors.onPrimary
                              : Colors.white.withValues(alpha: 0.6),
                          fontWeight: selected || isNormal
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            // Reset button
            if (isCustom) ...[
              const SizedBox(height: AppSpacing.md),
              GestureDetector(
                onTap: () => _setSpeed(1.0),
                child: Text(
                  'Redefinir para 1x',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.primary.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// UP NEXT PREVIEW — polished with transition
// ============================================================

class _UpNextPreview extends ConsumerWidget {
  const _UpNextPreview({required this.colors, required this.theme});
  final ColorScheme colors;
  final ThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ps = ref.watch(playerProvider);
    if (!ps.hasNext ||
        ps.currentIndex < 0 ||
        ps.currentIndex + 1 >= ps.queue.length) {
      return const SizedBox(height: AppSpacing.xl);
    }
    final nextSong = ps.queue[ps.currentIndex + 1];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: GestureDetector(
        onTap: () => ref.read(playerProvider.notifier).next(),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: colors.onSurface.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.onSurface.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                ),
                child: Text(
                  'A SEGUIR',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.35),
                    letterSpacing: 1.2,
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              ArtworkImage.song(
                songId: nextSong.numericId,
                size: 34,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      nextSong.title,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.65),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      nextSong.artist,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.3),
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.skip_next_rounded,
                size: 18,
                color: colors.onSurface.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// TAP SCALE ANIMATION WIDGET
// ============================================================

class _TapScaleWidget extends StatefulWidget {
  const _TapScaleWidget({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_TapScaleWidget> createState() => _TapScaleWidgetState();
}

class _TapScaleWidgetState extends State<_TapScaleWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.85,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _c.reverse(),
      onTapUp: (_) {
        _c.forward();
        widget.onTap?.call();
      },
      onTapCancel: () => _c.forward(),
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) => Transform.scale(scale: _c.value, child: child),
        child: widget.child,
      ),
    );
  }
}

// ============================================================
// LYRICS PAGE — Spotify-premium style com scroll inteligente
// ============================================================

class _LyricsPage extends ConsumerStatefulWidget {
  const _LyricsPage({required this.song});
  final Song song;

  @override
  ConsumerState<_LyricsPage> createState() => _LyricsPageState();
}

class _LyricsPageState extends ConsumerState<_LyricsPage> {
  final ScrollController _scroll = ScrollController();
  final Map<int, GlobalKey> _lineKeys = {};
  int _lastScrolledIndex = -1;
  bool _userIsScrolling = false;
  Timer? _userScrollTimer;
  static const _scrollCooldown = Duration(seconds: 5);

  bool _isSearching = false;

  /// Tamanho da fonte (3 níveis)
  double _baseFontSize = 22.0;
  static const _fontSizes = [18.0, 22.0, 28.0];
  static const _fontLabels = ['Pequena', 'Média', 'Grande'];
  int _fontIdx = 1;

  GlobalKey _keyFor(int idx) => _lineKeys.putIfAbsent(idx, () => GlobalKey());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(lyricsProvider.notifier).loadForSong(widget.song.id);
    });
  }

  @override
  void dispose() {
    _userScrollTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  // ── Scroll inteligente ──────────────────────────────────────

  void _onUserScrollStart() {
    _userScrollTimer?.cancel();
    if (!_userIsScrolling) setState(() => _userIsScrolling = true);
  }

  void _onUserScrollEnd() {
    _userScrollTimer?.cancel();
    _userScrollTimer = Timer(_scrollCooldown, () {
      if (mounted) {
        setState(() => _userIsScrolling = false);
        _lastScrolledIndex = -1;
      }
    });
  }

  void _resumeAutoScroll() {
    _userScrollTimer?.cancel();
    setState(() {
      _userIsScrolling = false;
      _lastScrolledIndex = -1;
    });
  }

  void _scrollToLine(int idx) {
    if (idx < 0 || _userIsScrolling) return;
    if (idx == _lastScrolledIndex) return;
    _lastScrolledIndex = idx;

    final ctx = _lineKeys[idx]?.currentContext;
    if (ctx == null || !mounted) return;

    // alignment: 0.5 → centraliza o widget no viewport, independente da
    // altura variável da linha (fontes maiores ou texto que quebra).
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      alignment: 0.5,
    );
  }

  void _cycleFontSize() {
    setState(() {
      _fontIdx = (_fontIdx + 1) % _fontSizes.length;
      _baseFontSize = _fontSizes[_fontIdx];
      _lastScrolledIndex = -1;
    });
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tamanho: ${_fontLabels[_fontIdx]}'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _seekToLine(Duration? ts) {
    if (ts == null) return;
    ref.read(playerProvider.notifier).seek(ts);
    _resumeAutoScroll();
  }

  void _copyLyrics(ColorScheme c) {
    final text = ref.read(lyricsProvider).lines.map((l) => l.text).join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Letras copiadas!'),
        backgroundColor: c.onSurface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Busca online ────────────────────────────────────────────

  Future<void> _searchOnline() async {
    if (_isSearching) return;
    setState(() => _isSearching = true);
    try {
      // Sempre usar a música atual do player — não a que abriu a tela.
      final song = ref.read(playerProvider).currentSong ?? widget.song;
      // Garante que o lyricsProvider está vinculado a esta música
      // antes de importar (evita salvar letras na chave errada).
      await ref.read(lyricsProvider.notifier).loadForSong(song.id);
      final lines = await LyricsFetchService.fetch(
        title: song.title,
        artist: song.artist,
        album: song.album,
        duration: song.duration,
      );
      if (!mounted) return;
      if (lines != null && lines.isNotEmpty) {
        final notifier = ref.read(lyricsProvider.notifier);
        // Import synced lines and persist
        final lrcText = lines
            .where((l) => l.isSynced)
            .map((l) {
              final ts = l.timestamp!;
              final m = ts.inMinutes.remainder(60).toString().padLeft(2, '0');
              final s = ts.inSeconds.remainder(60).toString().padLeft(2, '0');
              final ms = (ts.inMilliseconds.remainder(1000) ~/ 10)
                  .toString()
                  .padLeft(2, '0');
              return '[$m:$s.$ms]${l.text}';
            })
            .join('\n');
        if (lrcText.isNotEmpty) {
          await notifier.importLrc(lrcText);
        } else {
          // Plain text lines — import as unsynchronized text
          final plainText = lines.map((l) => l.text).join('\n');
          await notifier.importPlainText(plainText);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${lines.length} linhas encontradas!'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Nenhuma letra encontrada online'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro na busca: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  // ── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final baseColors = baseTheme.colorScheme;
    final colors = baseColors.brightness == Brightness.dark
        ? baseColors
        : ColorScheme.dark(
            primary: baseColors.primary,
            onPrimary: baseColors.onPrimary,
            secondary: baseColors.secondary,
            tertiary: baseColors.tertiary,
            error: baseColors.error,
          );
    final theme = baseTheme.copyWith(colorScheme: colors);
    final lyrics = ref.watch(lyricsProvider);
    final position = ref.watch(playerProvider.select((s) => s.position));
    final curIdx = lyrics.currentLineIndex(position);
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    // Song atual do player — se mudar (skip no mini player), recarrega letras.
    final currentSong =
        ref.watch(playerProvider.select((s) => s.currentSong)) ?? widget.song;
    final songId = currentSong.numericId;

    ref.listen<String?>(
      playerProvider.select((s) => s.currentSong?.id),
      (prev, next) {
        if (next != null && next != prev) {
          _lineKeys.clear();
          _lastScrolledIndex = -1;
          _userScrollTimer?.cancel();
          _userIsScrolling = false;
          ref.read(lyricsProvider.notifier).loadForSong(next);
        }
      },
    );

    // Auto-scroll no view mode
    if (!lyrics.isEditing && curIdx >= 0) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollToLine(curIdx),
      );
    }

    final Widget bodyContent = !lyrics.isLoaded
        ? const Center(child: CircularProgressIndicator())
        : lyrics.isEmpty && !lyrics.isEditing
        ? _EmptyLyrics(
            onAdd: () => ref.read(lyricsProvider.notifier).toggleEdit(),
            onImportLrc: () => _showImportDialog(context),
            onPasteText: () => _showPasteTextDialog(context),
            onSearchOnline: _searchOnline,
            isSearching: _isSearching,
            colors: colors,
            theme: theme,
          )
        : lyrics.isEditing
        ? _EditView(song: widget.song)
        : _LyricsViewMode(
            lines: lyrics.lines,
            currentIndex: curIdx,
            scroll: _scroll,
            baseFontSize: _baseFontSize,
            colors: colors,
            onSeek: _seekToLine,
            onUserScrollStart: _onUserScrollStart,
            onUserScrollEnd: _onUserScrollEnd,
            keyFor: _keyFor,
            horizontalPadding: isLandscape
                ? AppSpacing.xl
                : AppSpacing.lg,
            textAlign: isLandscape ? TextAlign.left : TextAlign.left,
          );

    // Em landscape, quebra body em Row: lado esquerdo (arte+info+mini controles),
    // lado direito (letras centradas). Não usa bottomNavigationBar.
    final Widget scaffoldBody = isLandscape && !lyrics.isEditing
        ? _LyricsLandscapeBody(
            song: currentSong,
            colors: colors,
            theme: theme,
            lyricsContent: bodyContent,
          )
        : bodyContent;

    return Theme(
      data: theme,
      child: BackgroundWrapper(
        child: Stack(
          children: [
            _BlurredArtworkBg(songId: songId, opacity: 0.35),
            Container(color: Colors.black.withValues(alpha: 0.5)),
            Scaffold(
              backgroundColor: Colors.transparent,
              // Mini-player só em portrait — landscape já mostra controles no pane
              bottomNavigationBar: (!isLandscape && !lyrics.isEditing)
                  ? const _LyricsMiniPlayer()
                  : null,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
                  onPressed: () => context.pop(),
                ),
                title: Column(
                  children: [
                    Text(
                      currentSong.title,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      currentSong.artist,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.4),
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                actions: _buildActions(lyrics, colors),
              ),
              floatingActionButton: lyrics.isEditing
                  ? FloatingActionButton(
                      mini: true,
                      backgroundColor: colors.primary,
                      foregroundColor: colors.onPrimary,
                      onPressed: () => _showAddLineDialog(context),
                      child: const Icon(Icons.add_rounded),
                    )
                  : _userIsScrolling && !lyrics.isEmpty && lyrics.hasSyncedLines
                  ? FloatingActionButton.small(
                      backgroundColor: colors.surface.withValues(alpha: 0.85),
                      foregroundColor: colors.primary,
                      onPressed: _resumeAutoScroll,
                      child: const Icon(Icons.my_location_rounded, size: 20),
                    )
                  : null,
              body: scaffoldBody,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildActions(LyricsState lyrics, ColorScheme colors) {
    if (lyrics.isEditing) {
      return [
        if (lyrics.lines.any((l) => !l.isSynced))
          IconButton(
            icon: Icon(Icons.timer_rounded, size: 20, color: colors.primary),
            tooltip: 'Sync rápido',
            onPressed: () {
              ref.read(lyricsProvider.notifier).save();
              Navigator.of(
                context,
              ).push(AppPageRoute(page: _QuickSyncPage(song: widget.song)));
            },
          ),
        if (!lyrics.isEmpty)
          IconButton(
            icon: Icon(Icons.delete_outline, size: 20, color: colors.error),
            onPressed: () => _confirmDelete(context),
          ),
        TextButton(
          onPressed: () => ref.read(lyricsProvider.notifier).save(),
          child: Text('Salvar', style: TextStyle(color: colors.primary)),
        ),
      ];
    }
    if (!lyrics.isLoaded || lyrics.isEmpty) return [];
    return [
      IconButton(
        icon: const Icon(Icons.text_fields_rounded, size: 20),
        onPressed: _cycleFontSize,
      ),
      IconButton(
        icon: const Icon(Icons.more_vert_rounded, size: 20),
        onPressed: () => _showMenu(context, colors, lyrics),
      ),
    ];
  }

  // ── Menu ⋮ ──

  void _showMenu(BuildContext context, ColorScheme colors, LyricsState lyrics) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.xs),
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: colors.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ListTile(
              leading: const Icon(Icons.travel_explore_rounded),
              title: const Text('Buscar online'),
              subtitle: Text(
                'Substituir pelas letras da internet',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.4),
                ),
              ),
              onTap: () {
                ctx.pop();
                _searchOnline();
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Copiar letras'),
              onTap: () {
                ctx.pop();
                _copyLyrics(colors);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Editar letras'),
              onTap: () {
                ctx.pop();
                ref.read(lyricsProvider.notifier).toggleEdit();
              },
            ),
            if (lyrics.lines.any((l) => !l.isSynced))
              ListTile(
                leading: Icon(Icons.timer_rounded, color: colors.primary),
                title: const Text('Sync rápido'),
                subtitle: Text(
                  'Sincronize linha por linha em tempo real',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.4),
                  ),
                ),
                onTap: () {
                  ctx.pop();
                  ref.read(lyricsProvider.notifier).save();
                  Navigator.of(
                    context,
                  ).push(AppPageRoute(page: _QuickSyncPage(song: widget.song)));
                },
              ),
            ListTile(
              leading: const Icon(Icons.download_rounded),
              title: const Text('Importar LRC'),
              onTap: () {
                ctx.pop();
                _showImportDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.text_snippet_outlined),
              title: const Text('Colar texto simples'),
              onTap: () {
                ctx.pop();
                _showPasteTextDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Exportar LRC'),
              onTap: () {
                ctx.pop();
                _exportLrc(context);
              },
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  // ── Dialogs ─────────────────────────────────────────────────

  void _showAddLineDialog(BuildContext context) {
    final position = ref.read(playerProvider).position;
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        final c = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: const Text('Nova linha'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: c.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '⏱ ${_fmtDuration(position)}',
                  style: TextStyle(
                    color: c.primary,
                    fontSize: 13,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Letra...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => ctx.pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  ref
                      .read(lyricsProvider.notifier)
                      .addLine(
                        timestamp: position,
                        text: controller.text.trim(),
                      );
                }
                ctx.pop();
              },
              child: const Text('Adicionar'),
            ),
          ],
        );
      },
    );
  }

  void _showImportDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Importar LRC'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Cole texto LRC com timestamps [mm:ss.xx]',
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  ctx,
                ).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '[00:12.50]Primeira linha...',
                border: OutlineInputBorder(),
              ),
              maxLines: 10,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => ctx.pop(), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty)
                ref.read(lyricsProvider.notifier).importLrc(text);
              ctx.pop();
            },
            child: const Text('Importar'),
          ),
        ],
      ),
    );
  }

  void _showPasteTextDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        final dc = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: const Text('Colar letras'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Cole as letras — cada linha vira uma entrada. Sincronize depois com Sync Rápido.',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                  color: dc.onSurface.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Primeira linha\nSegunda linha...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 10,
                textCapitalization: TextCapitalization.sentences,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => ctx.pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  final n = ref.read(lyricsProvider.notifier);
                  for (final l
                      in text
                          .split('\n')
                          .map((l) => l.trim())
                          .where((l) => l.isNotEmpty)) {
                    n.addLine(text: l);
                  }
                  n.save();
                }
                ctx.pop();
              },
              child: const Text('Adicionar'),
            ),
          ],
        );
      },
    );
  }

  void _exportLrc(BuildContext context) {
    final lrc = ref.read(lyricsProvider.notifier).exportLrc();
    showDialog(
      context: context,
      builder: (ctx) {
        final c = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: const Text('Exportar LRC'),
          content: Container(
            constraints: const BoxConstraints(maxHeight: 300),
            child: SingleChildScrollView(
              child: SelectableText(
                lrc,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => ctx.pop(),
              child: Text('Fechar', style: TextStyle(color: c.onSurface)),
            ),
            FilledButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: lrc));
                ctx.pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('LRC copiado!'),
                    backgroundColor: c.onSurface,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );
              },
              child: const Text('Copiar'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        final c = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: const Text('Apagar letras'),
          content: const Text(
            'Todas as letras serão apagadas permanentemente.',
          ),
          actions: [
            TextButton(
              onPressed: () => ctx.pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                ref.read(lyricsProvider.notifier).deleteAll();
                ctx.pop();
              },
              child: Text('Apagar', style: TextStyle(color: c.error)),
            ),
          ],
        );
      },
    );
  }

  static String _fmtDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    final cs = (d.inMilliseconds.remainder(1000) / 10).round();
    return '$m:${s.toString().padLeft(2, '0')}.${cs.toString().padLeft(2, '0')}';
  }
}

// ============================================================
// LYRICS MINI-PLAYER — barra inferior fixa na tela de letras
// Premium: título/artista + heart, slider e transport compacto.
// ============================================================

class _LyricsMiniPlayer extends ConsumerWidget {
  const _LyricsMiniPlayer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = ref.watch(playerProvider.select((s) => s.currentSong));
    if (song == null) return const SizedBox.shrink();

    final isPlaying = ref.watch(playerProvider.select((s) => s.isPlaying));
    final position = ref.watch(playerProvider.select((s) => s.position));
    final duration = ref.watch(playerProvider.select((s) => s.duration));
    final shuffleOn = ref.watch(
      playerProvider.select((s) => s.shuffleEnabled),
    );
    final palette = ref.watch(artworkPaletteProvider);
    final isFavorite = ref.watch(
      libraryProvider.select(
        (s) => s.songs.any((x) => x.id == song.id && x.isFavorite),
      ),
    );

    final accent = palette?.vibrant ?? Theme.of(context).colorScheme.primary;
    final durMs = duration.inMilliseconds.clamp(1, 1 << 30);
    final progress = (position.inMilliseconds / durMs).clamp(0.0, 1.0);
    final remaining = duration - position;

    String fmt(Duration d) {
      final m = d.inMinutes;
      final s = d.inSeconds.remainder(60);
      return '$m:${s.toString().padLeft(2, '0')}';
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
          AppSpacing.xs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Linha 1: título/artista + favorito ──
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _MiniIconBtn(
                  icon: isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isFavorite
                      ? accent
                      : Colors.white.withValues(alpha: 0.75),
                  size: 22,
                  onTap: () =>
                      ref.read(playerProvider.notifier).toggleFavorite(),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // ── Linha 2: slider fino ──
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                activeTrackColor: accent,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
                thumbColor: accent,
                overlayColor: accent.withValues(alpha: 0.15),
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 5,
                ),
                overlayShape: const RoundSliderOverlayShape(
                  overlayRadius: 12,
                ),
              ),
              child: Slider(
                value: progress,
                onChanged: (v) {
                  if (duration.inMilliseconds > 0) {
                    ref
                        .read(playerProvider.notifier)
                        .seek(
                          Duration(
                            milliseconds:
                                (v * duration.inMilliseconds).round(),
                          ),
                        );
                  }
                },
              ),
            ),
            // ── Linha 3: tempos ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    fmt(position),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    '-${fmt(remaining.isNegative ? Duration.zero : remaining)}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // ── Linha 4: transport ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _MiniIconBtn(
                  icon: Icons.shuffle_rounded,
                  color: shuffleOn
                      ? accent
                      : Colors.white.withValues(alpha: 0.75),
                  size: 22,
                  onTap: () =>
                      ref.read(playerProvider.notifier).toggleShuffle(),
                ),
                _MiniIconBtn(
                  icon: Icons.skip_previous_rounded,
                  color: Colors.white,
                  size: 30,
                  onTap: () => ref.read(playerProvider.notifier).previous(),
                ),
                _MiniPlayButton(
                  isPlaying: isPlaying,
                  accent: accent,
                  onTap: () =>
                      ref.read(playerProvider.notifier).togglePlayPause(),
                ),
                _MiniIconBtn(
                  icon: Icons.skip_next_rounded,
                  color: Colors.white,
                  size: 30,
                  onTap: () => ref.read(playerProvider.notifier).next(),
                ),
                _MiniIconBtn(
                  icon: Icons.graphic_eq_rounded,
                  color: Colors.white.withValues(alpha: 0.75),
                  size: 22,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniIconBtn extends StatelessWidget {
  const _MiniIconBtn({
    required this.icon,
    required this.color,
    required this.onTap,
    this.size = 24,
  });
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 24,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, color: color, size: size),
      ),
    );
  }
}

class _MiniPlayButton extends StatelessWidget {
  const _MiniPlayButton({
    required this.isPlaying,
    required this.accent,
    required this.onTap,
  });
  final bool isPlaying;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: accent,
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.45),
              blurRadius: 22,
              spreadRadius: -2,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: Colors.white,
          size: 30,
        ),
      ),
    );
  }
}

// ============================================================
// VIEW MODE — Spotify-premium: linha atual centralizada, bold,
// linhas anteriores sobem com fade, tap-to-seek
// ============================================================

class _LyricsViewMode extends StatelessWidget {
  const _LyricsViewMode({
    required this.lines,
    required this.currentIndex,
    required this.scroll,
    required this.baseFontSize,
    required this.colors,
    required this.onSeek,
    required this.onUserScrollStart,
    required this.onUserScrollEnd,
    required this.keyFor,
    this.horizontalPadding = AppSpacing.lg,
    this.textAlign = TextAlign.left,
  });
  final List<LyricLine> lines;
  final int currentIndex;
  final ScrollController scroll;
  final double baseFontSize;
  final ColorScheme colors;
  final ValueChanged<Duration?> onSeek;
  final VoidCallback onUserScrollStart;
  final VoidCallback onUserScrollEnd;
  final GlobalKey Function(int idx) keyFor;
  final double horizontalPadding;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    // Padding suficiente para a primeira/última linha alcançarem o centro.
    // LayoutBuilder dá o height real do viewport (portrait ou landscape).
    return LayoutBuilder(
      builder: (context, constraints) {
        final centerPad = constraints.maxHeight / 2;

        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n is UserScrollNotification) {
              if (n.direction != ScrollDirection.idle) {
                onUserScrollStart();
              } else {
                onUserScrollEnd();
              }
            }
            return false;
          },
          // ListView com children explícitos (não-lazy) — garante que todos
          // os GlobalKeys tenham context para o Scrollable.ensureVisible.
          child: ListView(
            controller: scroll,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(
              top: centerPad,
              bottom: centerPad,
              left: horizontalPadding,
              right: horizontalPadding,
            ),
            children: [
              for (int i = 0; i < lines.length; i++)
                _LyricLineItem(
                  key: keyFor(i),
                  line: lines[i],
                  isCurrent: i == currentIndex,
                  distance: currentIndex >= 0 ? (i - currentIndex).abs() : 0,
                  isPast: currentIndex >= 0 && i < currentIndex,
                  hasActive: currentIndex >= 0,
                  baseFontSize: baseFontSize,
                  colors: colors,
                  onSeek: onSeek,
                  textAlign: textAlign,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _LyricLineItem extends StatelessWidget {
  const _LyricLineItem({
    super.key,
    required this.line,
    required this.isCurrent,
    required this.distance,
    required this.isPast,
    required this.hasActive,
    required this.baseFontSize,
    required this.colors,
    required this.onSeek,
    required this.textAlign,
  });

  final LyricLine line;
  final bool isCurrent;
  final int distance;
  final bool isPast;
  final bool hasActive;
  final double baseFontSize;
  final ColorScheme colors;
  final ValueChanged<Duration?> onSeek;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final alpha = isCurrent
        ? 1.0
        : !hasActive
        ? 0.45
        : isPast
        ? (0.35 - distance * 0.05).clamp(0.08, 0.35)
        : (0.45 - distance * 0.06).clamp(0.1, 0.45);

    final fontSize = isCurrent ? baseFontSize * 1.15 : baseFontSize;

    return GestureDetector(
      onTap: line.isSynced ? () => onSeek(line.timestamp) : null,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          style: TextStyle(
            color: colors.onSurface.withValues(alpha: alpha),
            fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
            fontSize: fontSize,
            height: 1.35,
          ),
          textAlign: textAlign,
          child: Text(line.text, textAlign: textAlign),
        ),
      ),
    );
  }
}

// ============================================================
// LYRICS LANDSCAPE BODY — artwork+controles à esquerda, letras à direita
// ============================================================

class _LyricsLandscapeBody extends ConsumerWidget {
  const _LyricsLandscapeBody({
    required this.song,
    required this.colors,
    required this.theme,
    required this.lyricsContent,
  });

  final Song song;
  final ColorScheme colors;
  final ThemeData theme;
  final Widget lyricsContent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Painel esquerdo: artwork + info + controles mini ──
        Expanded(
          flex: 4,
          child: _LyricsSidePanel(
            song: song,
            colors: colors,
            theme: theme,
          ),
        ),
        // Divisor vertical sutil
        Container(
          width: 1,
          margin: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          color: Colors.white.withValues(alpha: 0.06),
        ),
        // ── Painel direito: letras ──
        Expanded(flex: 7, child: lyricsContent),
      ],
    );
  }
}

class _LyricsSidePanel extends ConsumerWidget {
  const _LyricsSidePanel({
    required this.song,
    required this.colors,
    required this.theme,
  });

  final Song song;
  final ColorScheme colors;
  final ThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlaying = ref.watch(playerProvider.select((s) => s.isPlaying));
    final position = ref.watch(playerProvider.select((s) => s.position));
    final duration = ref.watch(playerProvider.select((s) => s.duration));
    final shuffleOn = ref.watch(
      playerProvider.select((s) => s.shuffleEnabled),
    );
    final palette = ref.watch(artworkPaletteProvider);
    final isFavorite = ref.watch(
      libraryProvider.select(
        (s) => s.songs.any((x) => x.id == song.id && x.isFavorite),
      ),
    );

    final accent = palette?.vibrant ?? colors.primary;
    final durMs = duration.inMilliseconds.clamp(1, 1 << 30);
    final progress = (position.inMilliseconds / durMs).clamp(0.0, 1.0);
    final remaining = duration - position;

    String fmt(Duration d) {
      final m = d.inMinutes;
      final s = d.inSeconds.remainder(60);
      return '$m:${s.toString().padLeft(2, '0')}';
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Reserva conservadora p/ título+artista+slider+tempos+transport.
        final isTight = constraints.maxHeight < 420;
        final reservedBelowArt = isTight ? 230.0 : 260.0;
        final maxArtByHeight =
            (constraints.maxHeight - reservedBelowArt).clamp(80.0, 320.0);
        final maxArtByWidth = constraints.maxWidth * 0.82;
        final artSize = maxArtByHeight < maxArtByWidth
            ? maxArtByHeight
            : maxArtByWidth;

        final gapTitleSlider = isTight ? 8.0 : AppSpacing.md;
        final gapArtTitle = isTight ? 8.0 : AppSpacing.md;
        final gapTransport = isTight ? 4.0 : AppSpacing.sm;
        final outerV = isTight ? 4.0 : AppSpacing.md;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            outerV,
            AppSpacing.md,
            outerV,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Artwork ──
              SizedBox(
                width: artSize,
                height: artSize,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusLg,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.25),
                          blurRadius: 30,
                          spreadRadius: -6,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: ArtworkImage.song(
                      songId: song.numericId,
                      size: artSize,
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusLg,
                      ),
                      placeholderIconSize: 56,
                    ),
                  ),
                ),
              ),
              SizedBox(height: gapArtTitle),
              // ── Título + artista ──
              Text(
                song.title,
                textAlign: TextAlign.center,
                maxLines: isTight ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                song.artist,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),
              SizedBox(height: gapTitleSlider),
              // ── Slider ──
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 3,
                  activeTrackColor: accent,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
                  thumbColor: accent,
                  overlayColor: accent.withValues(alpha: 0.15),
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 5,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 12,
                  ),
                ),
                child: Slider(
                  value: progress,
                  onChanged: (v) {
                    if (duration.inMilliseconds > 0) {
                      ref
                          .read(playerProvider.notifier)
                          .seek(
                            Duration(
                              milliseconds:
                                  (v * duration.inMilliseconds).round(),
                            ),
                          );
                    }
                  },
                ),
              ),
              // ── Tempos ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      fmt(position),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      '-${fmt(remaining.isNegative ? Duration.zero : remaining)}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: gapTransport),
              // ── Transport ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _MiniIconBtn(
                    icon: Icons.shuffle_rounded,
                    color: shuffleOn
                        ? accent
                        : Colors.white.withValues(alpha: 0.75),
                    size: 22,
                    onTap: () =>
                        ref.read(playerProvider.notifier).toggleShuffle(),
                  ),
                  _MiniIconBtn(
                    icon: Icons.skip_previous_rounded,
                    color: Colors.white,
                    size: 30,
                    onTap: () => ref.read(playerProvider.notifier).previous(),
                  ),
                  _MiniPlayButton(
                    isPlaying: isPlaying,
                    accent: accent,
                    onTap: () =>
                        ref.read(playerProvider.notifier).togglePlayPause(),
                  ),
                  _MiniIconBtn(
                    icon: Icons.skip_next_rounded,
                    color: Colors.white,
                    size: 30,
                    onTap: () => ref.read(playerProvider.notifier).next(),
                  ),
                  _MiniIconBtn(
                    icon: isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: isFavorite
                        ? accent
                        : Colors.white.withValues(alpha: 0.75),
                    size: 22,
                    onTap: () =>
                        ref.read(playerProvider.notifier).toggleFavorite(),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================
// QUICK SYNC PAGE — tela dedicada para sincronização rápida
// ============================================================

class _QuickSyncPage extends ConsumerStatefulWidget {
  const _QuickSyncPage({required this.song});
  final Song song;

  @override
  ConsumerState<_QuickSyncPage> createState() => _QuickSyncPageState();
}

class _QuickSyncPageState extends ConsumerState<_QuickSyncPage> {
  int _syncIdx = 0;

  @override
  void initState() {
    super.initState();
    // Começar na primeira linha sem sync
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final lines = ref.read(lyricsProvider).lines;
      for (int i = 0; i < lines.length; i++) {
        if (!lines[i].isSynced) {
          setState(() => _syncIdx = i);
          break;
        }
      }
    });
  }

  void _syncCurrentLine() {
    final lyrics = ref.read(lyricsProvider);
    if (_syncIdx >= lyrics.lines.length) {
      _finish();
      return;
    }
    final pos = ref.read(playerProvider).position;
    ref.read(lyricsProvider.notifier).updateLine(_syncIdx, timestamp: pos);
    setState(() => _syncIdx++);
    if (_syncIdx >= lyrics.lines.length) _finish();
  }

  void _finish() {
    ref.read(lyricsProvider.notifier).save();
    context.pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Sincronização concluída!'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final baseColors = baseTheme.colorScheme;
    final colors = baseColors.brightness == Brightness.dark
        ? baseColors
        : ColorScheme.dark(
            primary: baseColors.primary,
            onPrimary: baseColors.onPrimary,
            secondary: baseColors.secondary,
            tertiary: baseColors.tertiary,
            error: baseColors.error,
          );
    final theme = baseTheme.copyWith(colorScheme: colors);
    final lyrics = ref.watch(lyricsProvider);
    final lineCount = lyrics.lines.length;

    return Theme(
      data: theme,
      child: BackgroundWrapper(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                ref.read(lyricsProvider.notifier).save();
                context.pop();
              },
            ),
            title: Column(
              children: [
                Text(
                  'Sync Rápido',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.primary,
                  ),
                ),
                Text(
                  'Toque no momento certo · $_syncIdx/$lineCount',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.primary.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: _finish,
                child: Text(
                  'Concluir',
                  style: TextStyle(color: colors.primary),
                ),
              ),
            ],
          ),
          body: GestureDetector(
            onTap: _syncCurrentLine,
            behavior: HitTestBehavior.opaque,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                vertical: 40,
                horizontal: AppSpacing.lg,
              ),
              itemCount: lineCount,
              itemBuilder: (_, i) {
                final line = lyrics.lines[i];
                final isCurrent = i == _syncIdx;
                final isDone = i < _syncIdx;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 28,
                        child: Icon(
                          isDone
                              ? Icons.check_circle_rounded
                              : isCurrent
                              ? Icons.arrow_forward_rounded
                              : Icons.circle_outlined,
                          size: isDone
                              ? 16
                              : isCurrent
                              ? 18
                              : 14,
                          color: isDone
                              ? colors.primary
                              : isCurrent
                              ? colors.primary
                              : colors.onSurface.withValues(alpha: 0.12),
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (isDone && line.isSynced)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            line.formattedTimestamp,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.primary.withValues(alpha: 0.5),
                              fontSize: 10,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          line.text,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: isCurrent
                                ? colors.onSurface
                                : isDone
                                ? colors.onSurface.withValues(alpha: 0.5)
                                : colors.onSurface.withValues(alpha: 0.2),
                            fontWeight: isCurrent
                                ? FontWeight.w700
                                : FontWeight.w400,
                            fontSize: isCurrent ? 18 : 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: lineCount > 0 ? _syncIdx / lineCount : 0,
                      backgroundColor: colors.onSurface.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation(colors.primary),
                      minHeight: 3,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Toque em qualquer lugar para sincronizar a próxima linha',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.25),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// EDIT MODE — editor de linhas com timestamp + reorder
// ============================================================

class _EditView extends ConsumerStatefulWidget {
  const _EditView({required this.song});
  final Song song;

  @override
  ConsumerState<_EditView> createState() => _EditViewState();
}

class _EditViewState extends ConsumerState<_EditView> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final lines = ref.watch(lyricsProvider.select((s) => s.lines));
    final n = ref.read(lyricsProvider.notifier);

    if (lines.isEmpty) {
      return Center(
        child: Text(
          'Toque + para adicionar a primeira linha',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurface.withValues(alpha: 0.4),
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          color: colors.primary.withValues(alpha: 0.04),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: colors.onSurface.withValues(alpha: 0.3),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Toque no timestamp para sincronizar · Segure para limpar',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.35),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: lines.length,
            onReorder: n.reorderLines,
            itemBuilder: (_, i) {
              final line = lines[i];
              return _EditLineItem(
                key: ValueKey('line_${i}_${line.text}'),
                line: line,
                index: i,
                colors: colors,
                theme: theme,
                onEditText: (text) => n.updateLine(i, text: text),
                onSetTimestamp: () {
                  final pos = ref.read(playerProvider).position;
                  n.updateLine(i, timestamp: pos);
                },
                onClearTimestamp: () => n.updateLine(i, clearTimestamp: true),
                onDelete: () => n.removeLine(i),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EditLineItem extends StatefulWidget {
  const _EditLineItem({
    super.key,
    required this.line,
    required this.index,
    required this.colors,
    required this.theme,
    required this.onEditText,
    required this.onSetTimestamp,
    required this.onClearTimestamp,
    required this.onDelete,
  });
  final LyricLine line;
  final int index;
  final ColorScheme colors;
  final ThemeData theme;
  final ValueChanged<String> onEditText;
  final VoidCallback onSetTimestamp;
  final VoidCallback onClearTimestamp;
  final VoidCallback onDelete;

  @override
  State<_EditLineItem> createState() => _EditLineItemState();
}

class _EditLineItemState extends State<_EditLineItem> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.line.text);
  }

  @override
  void didUpdateWidget(_EditLineItem old) {
    super.didUpdateWidget(old);
    if (old.line.text != widget.line.text && _ctrl.text != widget.line.text)
      _ctrl.text = widget.line.text;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final t = widget.theme;
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onSetTimestamp,
            onLongPress: widget.onClearTimestamp,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
              child: Text(
                widget.line.formattedTimestamp,
                style: t.textTheme.labelSmall?.copyWith(
                  color: widget.line.isSynced
                      ? c.primary
                      : c.onSurface.withValues(alpha: 0.3),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _ctrl,
              onChanged: widget.onEditText,
              style: t.textTheme.bodyMedium,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.remove_circle_outline,
              size: 18,
              color: c.onSurface.withValues(alpha: 0.3),
            ),
            onPressed: widget.onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(
              Icons.drag_handle_rounded,
              size: 18,
              color: c.onSurface.withValues(alpha: 0.2),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// EMPTY STATE
// ============================================================

class _EmptyLyrics extends StatelessWidget {
  const _EmptyLyrics({
    required this.onAdd,
    required this.onImportLrc,
    required this.onPasteText,
    required this.onSearchOnline,
    required this.isSearching,
    required this.colors,
    required this.theme,
  });
  final VoidCallback onAdd;
  final VoidCallback onImportLrc;
  final VoidCallback onPasteText;
  final VoidCallback onSearchOnline;
  final bool isSearching;
  final ColorScheme colors;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTight = constraints.maxHeight < 420;
        final padding = EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: isTight ? AppSpacing.sm : AppSpacing.xl,
        );
        final col = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lyrics_outlined,
              size: isTight ? 40 : 56,
              color: colors.onSurface.withValues(alpha: 0.08),
            ),
            SizedBox(height: isTight ? AppSpacing.sm : AppSpacing.md),
            Text(
              'Sem letras',
              style: theme.textTheme.titleLarge?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.3),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Busque online, importe LRC\nou adicione manualmente',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.18),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isTight ? AppSpacing.md : AppSpacing.xxl),
            FilledButton.icon(
              onPressed: isSearching ? null : onSearchOnline,
              icon: isSearching
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.travel_explore_rounded, size: 18),
              label: Text(isSearching ? 'Buscando...' : 'Buscar online'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Adicionar manualmente'),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton.icon(
                  onPressed: onImportLrc,
                  icon: Icon(
                    Icons.download_rounded,
                    size: 16,
                    color: colors.onSurface.withValues(alpha: 0.35),
                  ),
                  label: Text(
                    'LRC',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.35),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                TextButton.icon(
                  onPressed: onPasteText,
                  icon: Icon(
                    Icons.content_paste_rounded,
                    size: 16,
                    color: colors.onSurface.withValues(alpha: 0.35),
                  ),
                  label: Text(
                    'Colar texto',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.35),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
        // Em landscape (tight), permite scroll. Em portrait, centraliza.
        return isTight
            ? SingleChildScrollView(padding: padding, child: col)
            : Center(child: Padding(padding: padding, child: col));
      },
    );
  }
}

// ============================================================
// ESTILO 5: VINYL — disco giratório animado
// ============================================================

class _VinylAlbumArt extends ConsumerStatefulWidget {
  const _VinylAlbumArt({
    super.key,
    required this.colors,
    this.artColor,
    required this.songId,
    required this.isCurrentPage,
  });
  final ColorScheme colors;
  final Color? artColor;
  final int songId;
  final bool isCurrentPage;

  @override
  ConsumerState<_VinylAlbumArt> createState() => _VinylAlbumArtState();
}

class _VinylAlbumArtState extends ConsumerState<_VinylAlbumArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotCtrl;
  ProviderSubscription<bool>? _playSub;

  @override
  void initState() {
    super.initState();
    _rotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    // Escuta isPlaying fora do build — chamar repeat/stop dentro de build()
    // causa reentrância e "setState during build" em skip rápido.
    _playSub = ref.listenManual<bool>(
      playerProvider.select((s) => s.isPlaying),
      (prev, next) => _syncAnimation(next),
      fireImmediately: true,
    );
  }

  @override
  void didUpdateWidget(covariant _VinylAlbumArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isCurrentPage != widget.isCurrentPage) {
      _syncAnimation(ref.read(playerProvider).isPlaying);
    }
  }

  void _syncAnimation(bool isPlaying) {
    final shouldAnimate = widget.isCurrentPage && isPlaying;
    if (shouldAnimate && !_rotCtrl.isAnimating) {
      _rotCtrl.repeat();
    } else if (!shouldAnimate && _rotCtrl.isAnimating) {
      _rotCtrl.stop();
    }
  }

  @override
  void dispose() {
    _playSub?.close();
    _rotCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context).width * 0.66;
    final artSize = size * 0.38;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _rotCtrl,
        builder: (_, child) =>
            Transform.rotate(angle: _rotCtrl.value * 6.28318, child: child),
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _VinylPainter(accentColor: widget.artColor),
            child: Center(
              child: SizedBox(
                width: artSize,
                height: artSize,
                child: ClipOval(
                  child: ArtworkImage.song(
                    songId: widget.songId,
                    size: artSize,
                    isCircle: true,
                    placeholderIconSize: 36,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VinylPainter extends CustomPainter {
  const _VinylPainter({this.accentColor});
  final Color? accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;
    final accent = accentColor ?? const Color(0xFF6C63FF);

    // Main disc
    canvas.drawCircle(center, maxR, Paint()..color = const Color(0xFF181818));

    // Concentric grooves — colored with accent tint
    for (int i = 1; i <= 14; i++) {
      final r = maxR * (0.22 + i * 0.048);
      if (r >= maxR * 0.97) break;
      final isAccentGroove = i % 3 == 0;
      final groovePaint = Paint()
        ..color = isAccentGroove
            ? accent.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isAccentGroove ? 1.0 : 0.8;
      canvas.drawCircle(center, r, groovePaint);
    }

    // Slight reflection sheen (top-left arc)
    final sheenPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.5, -0.5),
        radius: 1.0,
        colors: [Colors.white.withValues(alpha: 0.06), Colors.transparent],
      ).createShader(Rect.fromCircle(center: center, radius: maxR));
    canvas.drawCircle(center, maxR, sheenPaint);

    // Label circle — tinted with accent color
    final labelPaint = Paint()
      ..color = Color.lerp(const Color(0xFF252525), accent, 0.15)!;
    canvas.drawCircle(center, maxR * 0.23, labelPaint);

    // Center hole
    canvas.drawCircle(
      center,
      maxR * 0.025,
      Paint()..color = const Color(0xFF0D0D0D),
    );
  }

  @override
  bool shouldRepaint(_VinylPainter old) => old.accentColor != accentColor;
}

// ── Gradient track shape for MediaBarStyle.gradient ───────────

class _GradientSliderTrackShape extends SliderTrackShape
    with BaseSliderTrackShape {
  const _GradientSliderTrackShape({required this.gradientColors});
  final List<Color> gradientColors;

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    final trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final double h = sliderTheme.trackHeight ?? 4;
    final radius = Radius.circular(h / 2);
    final activeRect = Rect.fromLTRB(
      trackRect.left,
      trackRect.top - additionalActiveTrackHeight / 2,
      thumbCenter.dx,
      trackRect.bottom + additionalActiveTrackHeight / 2,
    );
    final inactiveRect = Rect.fromLTRB(
      thumbCenter.dx,
      trackRect.top,
      trackRect.right,
      trackRect.bottom,
    );
    final activePaint = Paint()
      ..shader = LinearGradient(colors: gradientColors).createShader(trackRect);
    final inactivePaint = Paint()
      ..color = sliderTheme.inactiveTrackColor ?? Colors.white24;
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(activeRect, radius),
      activePaint,
    );
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(inactiveRect, radius),
      inactivePaint,
    );
  }
}

// ============================================================
// QUEUE PAGE — fila funcional com reorder e remoção
// ============================================================

class _QueuePage extends ConsumerWidget {
  const _QueuePage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final ps = ref.watch(playerProvider);
    final n = ref.read(playerProvider.notifier);

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text(
          'Fila  (${ps.queue.length})',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w300,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (ps.queue.length > 1)
            IconButton(
              icon: const Icon(Icons.clear_all_rounded),
              tooltip: 'Limpar fila',
              onPressed: () => _confirmClear(context, n),
            ),
        ],
      ),
      body: ps.queue.isEmpty
          ? Center(
              child: Text(
                'Fila vazia',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.4),
                ),
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: 80),
              itemCount: ps.queue.length,
              proxyDecorator: (child, _, __) => Material(
                color: colors.surfaceContainer,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                elevation: 4,
                child: child,
              ),
              onReorder: (oldIdx, newIdx) => n.reorderQueue(oldIdx, newIdx),
              itemBuilder: (context, index) {
                final song = ps.queue[index];
                final isCurrent = song.id == ps.currentSong?.id;

                return Dismissible(
                  key: ValueKey('q_${song.id}_$index'),
                  direction: isCurrent
                      ? DismissDirection.none
                      : DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: AppSpacing.lg),
                    color: colors.error.withValues(alpha: 0.08),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      color: colors.error,
                    ),
                  ),
                  onDismissed: (_) => n.removeFromQueue(index),
                  child: _QueueItem(
                    song: song,
                    isCurrent: isCurrent,
                    colors: colors,
                    theme: theme,
                    onTap: () {
                      n.playSong(song, queue: ps.queue);
                      context.pop();
                    },
                  ),
                );
              },
            ),
    );
  }

  void _confirmClear(BuildContext context, PlayerNotifier n) {
    showDialog(
      context: context,
      builder: (ctx) {
        final colors = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: const Text('Limpar fila'),
          content: const Text('Remove todas as músicas excepto a actual?'),
          actions: [
            TextButton(
              onPressed: () => ctx.pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                n.clearQueue();
                ctx.pop();
              },
              child: Text('Limpar', style: TextStyle(color: colors.error)),
            ),
          ],
        );
      },
    );
  }
}

class _QueueItem extends StatelessWidget {
  const _QueueItem({
    required this.song,
    required this.isCurrent,
    required this.colors,
    required this.theme,
    required this.onTap,
  });

  final Song song;
  final bool isCurrent;
  final ColorScheme colors;
  final ThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isCurrent ? null : onTap,
      child: Container(
        color: isCurrent ? colors.primary.withValues(alpha: 0.06) : null,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Icon(
                Icons.drag_handle_rounded,
                size: 20,
                color: isCurrent
                    ? colors.primary.withValues(alpha: 0.4)
                    : colors.onSurface.withValues(alpha: 0.2),
              ),
            ),
            // Artwork + equalizer overlay
            Stack(
              children: [
                ArtworkImage.song(
                  songId: song.numericId,
                  size: 44,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                if (isCurrent)
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.equalizer_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: AppSpacing.sm),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: isCurrent ? colors.primary : colors.onSurface,
                      fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    song.artist,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.45),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Text(
              song.durationFormatted,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// MINIMALIST ALBUM ART — clean, no shadows, thin border
// ============================================================

class _MinimalistAlbumArt extends ConsumerWidget {
  const _MinimalistAlbumArt({
    super.key,
    required this.colors,
    this.artColor,
    required this.songId,
  });
  final ColorScheme colors;
  final Color? artColor;
  final int songId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.sizeOf(context).width * 0.70;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ArtworkImage.song(
            songId: songId,
            size: size,
            borderRadius: BorderRadius.zero,
            placeholderIconSize: 72,
          ),
          // Hairline border — understated frame
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.10),
                  width: 0.8,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// AURORA ALBUM ART — circle + animated aurora gradient behind
// ============================================================

class _AuroraAlbumArt extends ConsumerStatefulWidget {
  const _AuroraAlbumArt({
    super.key,
    required this.colors,
    this.artColor,
    required this.songId,
    required this.isCurrentPage,
  });
  final ColorScheme colors;
  final Color? artColor;
  final int songId;
  final bool isCurrentPage;

  @override
  ConsumerState<_AuroraAlbumArt> createState() => _AuroraAlbumArtState();
}

class _AuroraAlbumArtState extends ConsumerState<_AuroraAlbumArt>
    with TickerProviderStateMixin {
  late final AnimationController _auroraCtrl1;
  late final AnimationController _auroraCtrl2;

  @override
  void initState() {
    super.initState();
    _auroraCtrl1 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );
    _auroraCtrl2 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    );
    if (widget.isCurrentPage) {
      _auroraCtrl1.repeat(reverse: true);
      _auroraCtrl2.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _AuroraAlbumArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCurrentPage && !_auroraCtrl1.isAnimating) {
      _auroraCtrl1.repeat(reverse: true);
      _auroraCtrl2.repeat(reverse: true);
    } else if (!widget.isCurrentPage && _auroraCtrl1.isAnimating) {
      _auroraCtrl1.stop();
      _auroraCtrl2.stop();
    }
  }

  @override
  void dispose() {
    _auroraCtrl1.dispose();
    _auroraCtrl2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final artSize = MediaQuery.sizeOf(context).width * 0.65;
    final palette = ref.watch(artworkPaletteProvider);
    final c1 = palette?.vibrant ?? widget.colors.primary;
    final c2 = palette?.secondary ?? widget.colors.secondary;
    final c3 = palette?.tertiary ?? widget.colors.tertiary;

    return SizedBox(
      width: artSize + 40,
      height: artSize + 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: Listenable.merge([_auroraCtrl1, _auroraCtrl2]),
              builder: (_, __) => CustomPaint(
                size: Size(artSize + 40, artSize + 40),
                painter: _AuroraPainter(
                  t1: _auroraCtrl1.value,
                  t2: _auroraCtrl2.value,
                  c1: c1,
                  c2: c2,
                  c3: c3,
                ),
              ),
            ),
          ),
          SizedBox(
            width: artSize,
            height: artSize,
            child: ClipOval(
              child: ArtworkImage.song(
                songId: widget.songId,
                size: artSize,
                isCircle: true,
                placeholderIconSize: 72,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter({
    required this.t1,
    required this.t2,
    required this.c1,
    required this.c2,
    required this.c3,
  });
  final double t1, t2;
  final Color c1, c2, c3;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.55;

    // Blob 1 — moves in elliptical path
    final x1 = cx + r * 0.3 * (t1 * 2 - 1);
    final y1 = cy - r * 0.4 * t1;
    canvas.drawCircle(
      Offset(x1, y1),
      r * 0.6,
      Paint()
        ..shader = RadialGradient(
          colors: [c1.withValues(alpha: 0.50), c1.withValues(alpha: 0.0)],
        ).createShader(Rect.fromCircle(center: Offset(x1, y1), radius: r * 0.6))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
    );

    // Blob 2
    final x2 = cx - r * 0.35 * (t2 * 2 - 1);
    final y2 = cy + r * 0.3 * t2;
    canvas.drawCircle(
      Offset(x2, y2),
      r * 0.55,
      Paint()
        ..shader =
            RadialGradient(
              colors: [c2.withValues(alpha: 0.45), c2.withValues(alpha: 0.0)],
            ).createShader(
              Rect.fromCircle(center: Offset(x2, y2), radius: r * 0.55),
            )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );

    // Blob 3
    final x3 = cx + r * 0.2 * t1;
    final y3 = cy + r * 0.25 * (1 - t2);
    canvas.drawCircle(
      Offset(x3, y3),
      r * 0.45,
      Paint()
        ..shader =
            RadialGradient(
              colors: [c3.withValues(alpha: 0.35), c3.withValues(alpha: 0.0)],
            ).createShader(
              Rect.fromCircle(center: Offset(x3, y3), radius: r * 0.45),
            )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );
  }

  @override
  bool shouldRepaint(_AuroraPainter old) =>
      old.t1 != t1 ||
      old.t2 != t2 ||
      old.c1 != c1 ||
      old.c2 != c2 ||
      old.c3 != c3;
}

// ============================================================
// ELEGANT ALBUM ART — double border, warm shadow, refined
// ============================================================

class _ElegantAlbumArt extends ConsumerWidget {
  const _ElegantAlbumArt({
    super.key,
    required this.colors,
    this.artColor,
    required this.songId,
  });
  final ColorScheme colors;
  final Color? artColor;
  final int songId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.sizeOf(context).width * 0.72;
    final accentGold = artColor != null
        ? HSLColor.fromColor(
            artColor!,
          ).withSaturation(0.30).withLightness(0.55).toColor()
        : const Color(0xFFBFA76A);

    return Container(
      width: size + 14,
      height: size + 14,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accentGold.withValues(alpha: 0.45),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: accentGold.withValues(alpha: 0.22),
            blurRadius: 34,
            spreadRadius: -2,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.32),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: accentGold.withValues(alpha: 0.18),
              width: 0.8,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: ArtworkImage.song(
                    songId: songId,
                    size: size,
                    borderRadius: BorderRadius.circular(6),
                    placeholderIconSize: 72,
                  ),
                ),
                // Inner warm highlight — gives the gold frame weight
                IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 0.6,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// WAVE ALBUM ART — square art with animated sine waves below
// ============================================================

class _WaveAlbumArt extends ConsumerStatefulWidget {
  const _WaveAlbumArt({
    super.key,
    required this.colors,
    this.artColor,
    required this.songId,
    required this.isCurrentPage,
  });
  final ColorScheme colors;
  final Color? artColor;
  final int songId;
  final bool isCurrentPage;

  @override
  ConsumerState<_WaveAlbumArt> createState() => _WaveAlbumArtState();
}

class _WaveAlbumArtState extends ConsumerState<_WaveAlbumArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveCtrl;

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    if (widget.isCurrentPage) {
      _waveCtrl.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _WaveAlbumArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCurrentPage && !_waveCtrl.isAnimating) {
      _waveCtrl.repeat();
    } else if (!widget.isCurrentPage && _waveCtrl.isAnimating) {
      _waveCtrl.stop();
    }
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final artSize = MediaQuery.sizeOf(context).width * 0.70;
    final isPlaying = ref.watch(playerProvider.select((s) => s.isPlaying));
    final palette = ref.watch(artworkPaletteProvider);
    final waveColor = palette?.vibrant ?? widget.colors.primary;

    return SizedBox(
      width: artSize,
      height: artSize + 28,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: artSize,
            height: artSize - 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              boxShadow: [
                BoxShadow(
                  color: waveColor.withValues(alpha: 0.28),
                  blurRadius: 32,
                  spreadRadius: -4,
                  offset: const Offset(0, 16),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.32),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  child: ArtworkImage.song(
                    songId: widget.songId,
                    size: artSize,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    placeholderIconSize: 72,
                  ),
                ),
                IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusMd,
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 0.8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _waveCtrl,
              builder: (_, __) => CustomPaint(
                size: Size(artSize, 24),
                painter: _WavePainter(
                  phase: _waveCtrl.value,
                  color: waveColor,
                  isPlaying: isPlaying,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.phase,
    required this.color,
    required this.isPlaying,
  });
  final double phase;
  final Color color;
  final bool isPlaying;

  @override
  void paint(Canvas canvas, Size size) {
    final amp = isPlaying ? 8.0 : 3.0;
    final cy = size.height / 2;

    for (int w = 0; w < 3; w++) {
      final path = Path();
      final alpha = (0.35 - w * 0.10).clamp(0.08, 0.35);
      final freq = 2.0 + w * 0.8;
      final phaseOff = phase * 2 * 3.14159 + w * 1.2;
      final wAmp = amp * (1.0 - w * 0.25);

      path.moveTo(0, cy);
      for (double x = 0; x <= size.width; x += 2) {
        final y =
            cy + wAmp * _sin((x / size.width) * freq * 3.14159 * 2 + phaseOff);
        path.lineTo(x, y);
      }

      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 - w * 0.5
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  static double _sin(double x) {
    // Fast sin approximation
    x = x % (2 * 3.14159);
    if (x < 0) x += 2 * 3.14159;
    if (x > 3.14159) return -_sinHalf(x - 3.14159);
    return _sinHalf(x);
  }

  static double _sinHalf(double x) {
    // Parabolic approximation of sin(x) for x in [0, pi]
    final y = 4 * x * (3.14159 - x) / (3.14159 * 3.14159);
    return y * (0.775 + 0.225 * y);
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.phase != phase || old.color != color || old.isPlaying != isPlaying;
}

// ============================================================
// MOSAIC ALBUM ART — art with asymmetric color blocks
// ============================================================

class _MosaicAlbumArt extends ConsumerWidget {
  const _MosaicAlbumArt({
    super.key,
    required this.colors,
    this.artColor,
    required this.songId,
  });
  final ColorScheme colors;
  final Color? artColor;
  final int songId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalSize = MediaQuery.sizeOf(context).width * 0.72;
    final artSize = totalSize * 0.72;
    final palette = ref.watch(artworkPaletteProvider);

    final c1 = palette?.vibrant ?? colors.primary;
    final c2 = palette?.secondary ?? colors.secondary;
    final c3 = palette?.tertiary ?? colors.tertiary;
    final blockR = BorderRadius.circular(6);

    return SizedBox(
      width: totalSize,
      height: totalSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            top: totalSize * 0.05,
            child: Container(
              width: totalSize * 0.18,
              height: totalSize * 0.30,
              decoration: BoxDecoration(
                color: c1.withValues(alpha: 0.25),
                borderRadius: blockR,
              ),
            ),
          ),
          Positioned(
            right: totalSize * 0.02,
            top: 0,
            child: Container(
              width: totalSize * 0.22,
              height: totalSize * 0.16,
              decoration: BoxDecoration(
                color: c2.withValues(alpha: 0.20),
                borderRadius: blockR,
              ),
            ),
          ),
          Positioned(
            left: totalSize * 0.04,
            bottom: totalSize * 0.02,
            child: Container(
              width: totalSize * 0.25,
              height: totalSize * 0.18,
              decoration: BoxDecoration(
                color: c3.withValues(alpha: 0.18),
                borderRadius: blockR,
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: totalSize * 0.08,
            child: Container(
              width: totalSize * 0.15,
              height: totalSize * 0.35,
              decoration: BoxDecoration(
                color: c2.withValues(alpha: 0.15),
                borderRadius: blockR,
              ),
            ),
          ),
          Positioned(
            right: totalSize * 0.20,
            top: totalSize * 0.03,
            child: Container(
              width: totalSize * 0.10,
              height: totalSize * 0.10,
              decoration: BoxDecoration(
                color: c1.withValues(alpha: 0.30),
                borderRadius: blockR,
              ),
            ),
          ),
          Container(
            width: artSize,
            height: artSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              boxShadow: [
                BoxShadow(
                  color: c1.withValues(alpha: 0.30),
                  blurRadius: 36,
                  spreadRadius: -4,
                  offset: const Offset(0, 16),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  child: ArtworkImage.song(
                    songId: songId,
                    size: artSize,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    placeholderIconSize: 72,
                  ),
                ),
                IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusMd,
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.10),
                        width: 0.8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SLEEP TIMER VISUAL CIRCLE
// ============================================================

class _SleepTimerCircle extends StatelessWidget {
  const _SleepTimerCircle({
    required this.endTime,
    required this.totalMinutes,
    required this.color,
  });

  final DateTime? endTime;
  final int totalMinutes;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (endTime == null || totalMinutes <= 0) {
      return Icon(
        Icons.bedtime_rounded,
        size: 10,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
      );
    }

    final now = DateTime.now();
    final total = Duration(minutes: totalMinutes);
    final remaining = endTime!.difference(now);
    final progress = remaining.inSeconds <= 0
        ? 0.0
        : (remaining.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);

    return SizedBox(
      width: 14,
      height: 14,
      child: CustomPaint(
        painter: _TimerCirclePainter(
          progress: progress,
          color: color,
          trackAlpha: 0.15,
        ),
        child: Center(
          child: Icon(
            Icons.bedtime_rounded,
            size: 7,
            color: color.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }
}

class _TimerCirclePainter extends CustomPainter {
  _TimerCirclePainter({
    required this.progress,
    required this.color,
    this.trackAlpha = 0.15,
  });

  final double progress;
  final Color color;
  final double trackAlpha;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1;
    const strokeWidth = 1.5;
    const startAngle = -1.5708; // -π/2 (top)

    // Track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withValues(alpha: trackAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    // Progress arc
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        progress * 2 * 3.14159265,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_TimerCirclePainter old) =>
      old.progress != progress || old.color != color;
}

// ============================================================
// ANALYSIS BADGE — BPM + Key/Scale + Camelot + Energy under song info
// ============================================================

class _AnalysisBadge extends ConsumerWidget {
  const _AnalysisBadge({required this.colors});
  final ColorScheme colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analysis = ref.watch(audioAnalysisProvider);
    final onlineResult = analysis.result;
    final isLoading = analysis.isLoading;
    final song = ref.watch(playerProvider.select((s) => s.currentSong));

    // Dispara análise para a música atual (nativa sempre; online se tiver credenciais)
    if (song != null && !isLoading && analysis.songId != song.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(audioAnalysisProvider.notifier)
            .analyzeSong(
              song.id,
              song.uri,
              title: song.title,
              artist: song.artist,
            );
      });
    }

    if (!analysis.hasAnyData && !isLoading && !analysis.failed)
      return const SizedBox.shrink();

    // Carregando — ainda sem nenhum dado
    if (!analysis.hasAnyData && isLoading) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: colors.onSurface.withValues(alpha: 0.25),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Analisando BPM e tonalidade...',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.3),
                fontSize: 10,
              ),
            ),
          ],
        ),
      );
    }

    // Falha — mostra botão de retry
    if (!analysis.hasAnyData && analysis.failed) {
      final currentSong = ref.read(playerProvider).currentSong;
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: GestureDetector(
          onTap: currentSong != null
              ? () => ref
                    .read(audioAnalysisProvider.notifier)
                    .retry(
                      currentSong.id,
                      currentSong.uri,
                      title: currentSong.title,
                      artist: currentSong.artist,
                    )
              : null,
          child: Row(
            children: [
              Icon(
                Icons.refresh_rounded,
                size: 12,
                color: colors.onSurface.withValues(alpha: 0.3),
              ),
              const SizedBox(width: 4),
              Text(
                'Toque para reanalisar',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.3),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Derivados para exibição
    final displayBpm = analysis.bpm;
    final displayKey = analysis.key;
    final displayScale = analysis.scale;
    final displayCamelot = analysis.camelotCode;

    final hasBpm = displayBpm != null && displayBpm > 0;
    final hasKey =
        displayKey != null && displayKey.isNotEmpty && displayScale != null;

    final bpmLabel = hasBpm ? '$displayBpm BPM' : '';
    final keyLabel = hasKey
        ? () {
            final scaleLabel = displayScale == 'Major' ? 'Maior' : 'Menor';
            final base = '$displayKey $scaleLabel';
            return displayCamelot != null ? '$base ($displayCamelot)' : base;
          }()
        : '';

    final energyCategory = () {
      if (displayBpm == null) return '';
      if (displayBpm < 80) return 'Relaxante';
      if (displayBpm < 110) return 'Moderado';
      if (displayBpm < 140) return 'Energético';
      return 'Intenso';
    }();

    if (!hasBpm && !hasKey && !isLoading) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Linha 1: BPM + Key + Energia ───
          Row(
            children: [
              if (hasBpm)
                _buildChip(
                  context,
                  icon: Icons.speed_rounded,
                  label: bpmLabel,
                  color: colors.primary,
                ),
              if (hasBpm && hasKey) const SizedBox(width: 5),
              if (hasKey)
                _buildChip(
                  context,
                  icon: Icons.music_note_rounded,
                  label: keyLabel,
                  color: colors.tertiary,
                ),
              if (hasBpm) ...[
                const SizedBox(width: 5),
                _buildChip(
                  context,
                  label: energyCategory,
                  color: colors.onSurface,
                  subtle: true,
                ),
              ],
              if (isLoading) ...[
                const SizedBox(width: 6),
                SizedBox(
                  width: 8,
                  height: 8,
                  child: CircularProgressIndicator(
                    strokeWidth: 1,
                    color: colors.onSurface.withValues(alpha: 0.2),
                  ),
                ),
              ],
            ],
          ),
          // ─── Linha 2: Energy/Dance/Happiness (só se online disponível) ───
          if (onlineResult != null &&
              (onlineResult.hasEnergyData ||
                  onlineResult.danceability != null)) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                if (onlineResult.energy != null)
                  _buildMiniStat(
                    context,
                    icon: Icons.local_fire_department_rounded,
                    label: 'Energia ${onlineResult.energyPercent}',
                    color: Colors.deepOrange,
                  ),
                if (onlineResult.energy != null &&
                    onlineResult.danceability != null)
                  const SizedBox(width: 8),
                if (onlineResult.danceability != null)
                  _buildMiniStat(
                    context,
                    icon: Icons.nightlife_rounded,
                    label: 'Dança ${onlineResult.danceabilityPercent}',
                    color: Colors.purpleAccent,
                  ),
                if (onlineResult.danceability != null &&
                    onlineResult.happiness != null)
                  const SizedBox(width: 8),
                if (onlineResult.happiness != null)
                  _buildMiniStat(
                    context,
                    icon: Icons.sentiment_very_satisfied_rounded,
                    label: '${(onlineResult.happiness! * 100).round()}%',
                    color: Colors.amber,
                  ),
              ],
            ),
          ],
          // ─── Fonte dos dados ───
          if (analysis.sourceLabel.isNotEmpty) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(
                  analysis.hasNativeData && !analysis.hasOnlineData
                      ? Icons.memory_rounded
                      : Icons.cloud_done_rounded,
                  size: 8,
                  color: colors.onSurface.withValues(alpha: 0.2),
                ),
                const SizedBox(width: 3),
                Text(
                  analysis.sourceLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.2),
                    fontSize: 8,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChip(
    BuildContext context, {
    IconData? icon,
    required String label,
    required Color color,
    bool confirmed = false,
    bool subtle = false,
  }) {
    if (label.isEmpty) return const SizedBox.shrink();
    final bgAlpha = subtle ? 0.06 : 0.12;
    final fgAlpha = subtle ? 0.4 : 0.8;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: bgAlpha),
        borderRadius: BorderRadius.circular(20),
        border: confirmed
            ? Border.all(color: color.withValues(alpha: 0.3), width: 0.5)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color.withValues(alpha: 0.7)),
            const SizedBox(width: 4),
          ],
          if (confirmed) ...[
            Icon(
              Icons.verified_rounded,
              size: 9,
              color: color.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color.withValues(alpha: fgAlpha),
              fontWeight: subtle ? FontWeight.w500 : FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: color.withValues(alpha: 0.5)),
        const SizedBox(width: 3),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colors.onSurface.withValues(alpha: 0.35),
            fontSize: 9,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
