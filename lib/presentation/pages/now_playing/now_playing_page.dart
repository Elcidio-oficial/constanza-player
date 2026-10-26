// ignore_for_file: deprecated_member_use, unused_local_variable, curly_braces_in_flow_control_structures, unused_element_parameter

import 'dart:async';
import 'package:constanza_player/core/theme/color_scheme_x.dart';
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
import 'package:constanza_player/presentation/providers/waveform_provider.dart';
import 'package:constanza_player/presentation/widgets/artwork_image.dart';
import 'package:constanza_player/presentation/widgets/media_seek_bar.dart';
import 'package:constanza_player/presentation/widgets/artist_links_text.dart';
import 'package:constanza_player/presentation/widgets/background_wrapper.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:constanza_player/services/lyrics_fetch_service.dart';
import 'package:constanza_player/services/share_service.dart';
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

// Seções da tela
part 'parts/layout.dart';
part 'parts/artwork.dart';
part 'parts/controls.dart';
part 'parts/sheets.dart';
part 'parts/sleep_timer.dart';
part 'parts/queue.dart';
part 'parts/analysis_badge.dart';

// ============================================================
// NOW PLAYING PAGE — Professional with vibrant gradients
// ============================================================

class NowPlayingPage extends ConsumerStatefulWidget {
  const NowPlayingPage({super.key});

  /// Único caminho para abrir o leitor a partir da UI. Usa o navegador raiz:
  /// dentro de uma aba, `Navigator.of(context)` empilhava o leitor no
  /// navegador da aba, com a barra de navegação e o mini player por baixo.
  static Future<void> open(BuildContext context) {
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const NowPlayingPage(),
        transitionsBuilder: (_, animation, __, child) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: child,
        ),
        transitionDuration: AppConstants.normal,
      ),
    );
  }

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
    final isNeutral = hsl.saturation < 0.12;
    return hsl
        .withLightness(hsl.lightness.clamp(0.25, 0.55))
        .withSaturation(
          isNeutral ? hsl.saturation : (hsl.saturation * 1.1).clamp(0.25, 0.90),
        )
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

    // Segue o tema do app: no claro o fundo colorido recebe um véu claro
    // (ver _LightWash) e o conteúdo usa o esquema claro (texto escuro).
    final colors = baseColors;
    final isLight = colors.brightness == Brightness.light;
    // Cor de base do fundo e destino dos gradientes: quase preto no escuro,
    // superfície clara no claro.
    final npBase = isLight ? colors.surface : const Color(0xFF080808);

    // Aplica cores quando o AppShell atualiza a palette (fonte única de extração)
    ref.listen<ArtworkPalette?>(artworkPaletteProvider, (prev, next) {
      if (next != null) _applyColorsFromPalette(next);
    });

    // Ao trocar de música mantém as cores atuais até a nova palette chegar
    // (a transição é animada em _applyColors). Resetar para _kDark aqui fazia
    // o botão de play cair em colors.primary — um flash branco a cada skip.
    ref.listen<Song?>(playerProvider.select((s) => s.currentSong), (
      prev,
      next,
    ) {
      if (next != null) _lastSongId = next.numericId;
    });

    // Aplica palette já disponível no primeiro build
    if (hasSong && _lastSongId == -1) {
      _lastSongId = songId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final palette = ref.read(artworkPaletteProvider);
        if (palette != null) _applyColorsFromPalette(palette);
      });
    }

    // AnnotatedRegion (e não SystemChrome) para vencer a região global do app.

    final npStyleOuter = themeState.nowPlayingStyle;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
        statusBarBrightness: isLight ? Brightness.light : Brightness.dark,
        systemNavigationBarIconBrightness: isLight
            ? Brightness.dark
            : Brightness.light,
      ),
      child: Theme(
        data: baseTheme.copyWith(colorScheme: colors),
        child: Scaffold(
          extendBodyBehindAppBar: true,
          extendBody: true,
          backgroundColor: npBase,
          body: Stack(
            fit: StackFit.expand,
            children: [
              Container(color: npBase),
              // Cover-art mode tem precedência: capa nítida em tela cheia + scrim.
              if (themeState.nowPlayingColorStyle ==
                      NowPlayingColorStyle.artwork &&
                  hasSong) ...[
                _SharpArtworkBg(songId: songId),
                Container(
                  color: isLight
                      ? colors.surface.withValues(alpha: 0.45)
                      : Colors.black.withValues(alpha: 0.60),
                ),
              ] else ...[
                if (npStyleOuter == NowPlayingStyle.classic && hasSong)
                  _BlurredArtworkBg(songId: songId, opacity: 0.55),
                if (npStyleOuter == NowPlayingStyle.fullBlur && hasSong)
                  _BlurredArtworkBg(songId: songId, opacity: 0.92),
              ],

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
                    // No modo "capa em tela cheia" suprimimos os gradients —
                    // a artwork (já renderizada fora do AnimatedBuilder) substitui o fundo.
                    final isArtworkBg =
                        colorStyle == NowPlayingColorStyle.artwork;

                    // For degradê mode: use c1 as single base color with bright top
                    final dgBase = c1;
                    final Color dgTop;
                    if (useColor) {
                      final hsl = HSLColor.fromColor(c1);
                      dgTop = hsl
                          .withLightness(
                            (hsl.lightness * 1.3).clamp(0.18, 0.50),
                          )
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
                        if (useColor && !isGradient && !isArtworkBg) ...[
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
                                  Color.lerp(dgBase, npBase, 0.55)!,
                                  npBase.withValues(alpha: 0.95),
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
                        if (useColor && isGradient && !isArtworkBg) ...[
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
                        if (useColor && !isLight)
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.transparent,
                                  npBase.withValues(alpha: 0.30),
                                  npBase.withValues(alpha: 0.70),
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
              // Modo claro: véu claro sobre o fundo colorido → tons pastel da capa.
              if (isLight) const _LightWash(),
              _NowPlayingContent(rawVibrant: _rawVibrant),
            ],
          ),
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
    final hasSong = song != null;
    final themeState = ref.watch(themeProvider);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final mq = MediaQuery.of(context);
    final screenH = mq.size.height;
    final isCompact = screenH < 700;
    final isLight = colors.brightness == Brightness.light;

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
              AppLocalizations.of(context).npNoSongSelected,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colors.fadedText(0.3),
              ),
            ),
          ],
        ),
      );
    }

    final Song currentSong = song;
    final artColor = ref.watch(artworkColorProvider);
    final isLandscape = mq.orientation == Orientation.landscape;

    // Compute accent color from rawVibrant for controls
    final bool hasVibrant = rawVibrant != const Color(0xFF1A1A2E);
    final Color accentColor;
    if (hasVibrant) {
      final hsl = HSLColor.fromColor(rawVibrant);
      // Capas neutras (branco/cinza) mantêm o tom neutro; forçar saturação
      // mínima transformava cinza em vermelho/rosa.
      final isNeutral = hsl.saturation < 0.12;
      // Escuro: destaque clareado para brilhar sobre o preto. Claro: escurecido,
      // senão play e progresso ficam desbotados sobre o fundo pastel.
      accentColor = hsl
          .withLightness(
            isLight
                ? hsl.lightness.clamp(isNeutral ? 0.12 : 0.30, 0.45)
                : hsl.lightness.clamp(0.55, isNeutral ? 0.90 : 0.75),
          )
          .withSaturation(
            isNeutral
                ? hsl.saturation
                : (hsl.saturation * 1.3).clamp(0.50, 1.0),
          )
          .toColor();
    } else {
      accentColor = colors.primary;
    }

    final overlayGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isLight
          ? const [Colors.transparent, Colors.transparent, Colors.transparent]
          : switch (themeState.nowPlayingStyle) {
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
              color: colors.fadedText(0.55),
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
          dismissNowPlaying(context);
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

/// Véu claro do modo claro: transforma o fundo colorido (gradientes da paleta
/// e capa desfocada, pensados para o escuro) numa versão pastel. Mais leve no
/// topo para a cor da capa aparecer; mais opaco em baixo, onde texto e
/// controlos precisam de contraste.
class _LightWash extends StatelessWidget {
  const _LightWash();

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              surface.withValues(alpha: 0.55),
              surface.withValues(alpha: 0.68),
              surface.withValues(alpha: 0.86),
            ],
            stops: const [0.0, 0.45, 1.0],
          ),
        ),
      ),
    );
  }
}
