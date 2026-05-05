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
import 'package:constanza_player/l10n/gen/app_localizations.dart';
import 'package:go_router/go_router.dart';

// ── Album-art styles (part files) ──
part 'styles/classic.dart';
part 'styles/circular.dart';
part 'styles/large.dart';
part 'styles/full_blur.dart';
part 'styles/vinyl.dart';
part 'styles/minimalist.dart';
part 'styles/aurora.dart';
part 'styles/elegant.dart';
part 'styles/wave.dart';
part 'styles/mosaic.dart';

// ── Lyrics subsystem (part files) ──
part 'lyrics/lyrics_page.dart';
part 'lyrics/mini_player.dart';
part 'lyrics/view_mode.dart';
part 'lyrics/landscape.dart';
part 'lyrics/quick_sync.dart';
part 'lyrics/edit_view.dart';
part 'lyrics/empty.dart';

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
                  final isGradient =
                      colorStyle == NowPlayingColorStyle.gradient;

                  // For degradê mode: use c1 as single base color with bright top
                  final dgBase = c1;
                  final Color dgTop;
                  if (useColor) {
                    final hsl = HSLColor.fromColor(c1);
                    dgTop = hsl
                        .withLightness((hsl.lightness * 1.3).clamp(0.18, 0.50))
                        .withSaturation(
                          (hsl.saturation * 1.1).clamp(0.25, 0.85),
                        )
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
                                Color.lerp(
                                  dgBase,
                                  const Color(0xFF080808),
                                  0.55,
                                )!,
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
                      Navigator.of(
                        context,
                      ).push(AppPageRoute(page: AlbumDetailPage(album: album)));
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
                        _MainControls(colors: colors, accentColor: accentColor),
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
    final targetSize = (mq.size.height * 0.78).clamp(0.0, mq.size.width * 0.48);
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
                        content: Text('Info da música copiada!'),
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

// ============================================================
// ESTILO 2: CIRCULAR — breathing pulse + colored glow
// ============================================================

// ============================================================
// ESTILO 3: LARGE — edge-to-edge + colored glow
// ============================================================

// ============================================================
// ESTILO 4: FULL BLUR — circle + immersive colored glow
// ============================================================

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
