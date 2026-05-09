import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:constanza_player/domain/entities/album.dart';
import 'package:constanza_player/domain/entities/artist.dart';
import 'package:constanza_player/domain/entities/playlist.dart';
import 'package:constanza_player/domain/entities/song.dart';
import 'package:constanza_player/domain/entities/lyric_line.dart';
import 'package:constanza_player/presentation/providers/artwork_provider.dart';

/// Tipo do conteúdo partilhado — controla o chip e o layout.
enum _PosterKind { song, album, artist, playlist, lyrics }

/// Serviço de partilha — gera posters editoriais 1080×1920 e abre
/// o sheet nativo de compartilhamento do Android.
class ShareService {
  ShareService._();

  // Canvas no formato 9:16 (Stories / Reels / Status / Snap).
  static const double _w = 1080;
  static const double _h = 1920;

  // ── API pública ─────────────────────────────────────────────

  static Future<void> shareSongs({
    required BuildContext context,
    required List<Song> songs,
    ArtworkPalette? palette,
  }) async {
    if (songs.isEmpty) return;
    final song = songs.first;
    final isSingle = songs.length == 1;
    final art = await _loadArt(song.numericId);
    final pal = palette ?? await _paletteFromBytes(art, song.numericId);
    if (!context.mounted) return;

    await _renderAndShare(
      context: context,
      kind: _PosterKind.song,
      title: isSingle ? song.title : '${songs.length} músicas',
      subtitle: isSingle
          ? song.artist
          : songs.map((s) => s.artist).toSet().take(3).join(' · '),
      meta: isSingle
          ? (song.album.isNotEmpty
                ? '${song.album}  ·  ${song.durationFormatted}'
                : song.durationFormatted)
          : null,
      art: art,
      palette: pal,
      shareText: isSingle
          ? '🎵 ${song.title} — ${song.artist}'
          : '🎵 ${songs.length} músicas via Constanza',
    );
  }

  static Future<void> shareAlbum({
    required BuildContext context,
    required Album album,
    required List<Song> songs,
    ArtworkPalette? palette,
  }) async {
    final artId = album.numericId != 0
        ? album.numericId
        : (songs.isNotEmpty ? songs.first.numericId : 0);
    // Tenta ALBUM type primeiro (mais nítido para álbuns), fallback p/ AUDIO.
    final art =
        await ArtworkNotifier.queryArtworkHighRes(
          artId,
          type: ArtworkType.ALBUM,
        ) ??
        await _loadArt(artId);
    final pal = palette ?? await _paletteFromBytes(art, artId);
    final totalDur = songs.fold<Duration>(
      Duration.zero,
      (s, x) => s + x.duration,
    );
    if (!context.mounted) return;

    await _renderAndShare(
      context: context,
      kind: _PosterKind.album,
      title: album.name,
      subtitle: album.artist,
      meta: [
        if (album.year != null) '${album.year}',
        '${songs.length} ${songs.length == 1 ? "faixa" : "faixas"}',
        _fmtDuration(totalDur),
      ].join('  ·  '),
      art: art,
      palette: pal,
      shareText: '📀 ${album.name} — ${album.artist}',
    );
  }

  static Future<void> shareArtist({
    required BuildContext context,
    required Artist artist,
    required List<Song> songs,
    ArtworkPalette? palette,
  }) async {
    final artId = songs.isNotEmpty ? songs.first.numericId : 0;
    final art = await _loadArt(artId);
    final pal = palette ?? await _paletteFromBytes(art, artId);
    if (!context.mounted) return;

    await _renderAndShare(
      context: context,
      kind: _PosterKind.artist,
      title: artist.name,
      subtitle:
          '${artist.songCount} ${artist.songCount == 1 ? "música" : "músicas"}'
          '  ·  ${artist.albumCount} ${artist.albumCount == 1 ? "álbum" : "álbuns"}',
      meta: null,
      art: art,
      palette: pal,
      shareText: '🎤 ${artist.name} — via Constanza',
    );
  }

  static Future<void> sharePlaylist({
    required BuildContext context,
    required Playlist playlist,
    required List<Song> songs,
    ArtworkPalette? palette,
  }) async {
    Uint8List? art;
    if (playlist.hasCustomImage) {
      try {
        final f = File(playlist.imagePath!);
        if (await f.exists()) art = await f.readAsBytes();
      } catch (_) {}
    }
    final firstId = songs.isNotEmpty ? songs.first.numericId : 0;
    art ??= await _loadArt(firstId);
    final pal = palette ?? await _paletteFromBytes(art, firstId);

    final totalDur = songs.fold<Duration>(
      Duration.zero,
      (s, x) => s + x.duration,
    );
    if (!context.mounted) return;

    await _renderAndShare(
      context: context,
      kind: _PosterKind.playlist,
      title: playlist.name,
      subtitle:
          '${songs.length} ${songs.length == 1 ? "música" : "músicas"}'
          '  ·  ${_fmtDuration(totalDur)}',
      meta: playlist.description,
      art: art,
      palette: pal,
      shareText: '🎶 ${playlist.name} — playlist via Constanza',
    );
  }

  static Future<void> shareLyrics({
    required BuildContext context,
    required Song song,
    required List<LyricLine> lines,
    int? highlightIndex,
    ArtworkPalette? palette,
  }) async {
    if (lines.isEmpty) {
      await shareSongs(context: context, songs: [song], palette: palette);
      return;
    }
    final art = await _loadArt(song.numericId);
    final pal = palette ?? await _paletteFromBytes(art, song.numericId);
    final selected = _pickLyricsWindow(lines, highlightIndex, maxLines: 11);
    if (!context.mounted) return;

    await _renderAndShare(
      context: context,
      kind: _PosterKind.lyrics,
      title: song.title,
      subtitle: song.artist,
      meta: song.album.isNotEmpty ? song.album : null,
      art: art,
      palette: pal,
      lyricsLines: selected.lines,
      lyricsHighlight: selected.highlight,
      shareText: '🎵 ${song.title} — ${song.artist}\nvia Constanza Músicas',
    );
  }

  // ── Núcleo ─────────────────────────────────────────────────

  static Future<void> _renderAndShare({
    required BuildContext context,
    required _PosterKind kind,
    required String title,
    required String subtitle,
    String? meta,
    Uint8List? art,
    required ArtworkPalette palette,
    required String shareText,
    List<LyricLine>? lyricsLines,
    int? lyricsHighlight,
  }) async {
    // Decodifica em alta resolução. Sem targetWidth → mantém o tamanho
    // original (até 1024px, conforme queryArtworkHighRes), evitando
    // upscaling pixelado.
    ui.Image? artImage;
    if (art != null && art.isNotEmpty) {
      try {
        final codec = await ui.instantiateImageCodec(art);
        final frame = await codec.getNextFrame();
        artImage = frame.image;
      } catch (_) {}
    }

    final key = GlobalKey();
    final widget = _PosterFrame(
      repaintKey: key,
      child: kind == _PosterKind.lyrics
          ? _LyricsPoster(
              title: title,
              subtitle: subtitle,
              palette: palette,
              artImage: artImage,
              lines: lyricsLines ?? const [],
              highlightIndex: lyricsHighlight,
            )
          : _SongPoster(
              kind: kind,
              title: title,
              subtitle: subtitle,
              meta: meta,
              palette: palette,
              artImage: artImage,
            ),
    );

    if (!context.mounted) return;
    final overlay = OverlayEntry(builder: (_) => widget);
    Overlay.of(context).insert(overlay);

    Uint8List? png;
    try {
      // Aguarda dois frames completos para garantir layout + paint.
      await WidgetsBinding.instance.endOfFrame;
      await Future.delayed(const Duration(milliseconds: 100));
      await WidgetsBinding.instance.endOfFrame;

      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        // pixelRatio 1.0 → poster final em 1080×1920 (já é alta resolução).
        final image = await boundary.toImage(pixelRatio: 1.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        png = byteData?.buffer.asUint8List();
        image.dispose();
      }
    } finally {
      overlay.remove();
      artImage?.dispose();
    }

    if (png == null || png.isEmpty) {
      await SharePlus.instance.share(ShareParams(text: shareText));
      return;
    }

    final tmp = await getTemporaryDirectory();
    final file = File(
      '${tmp.path}/constanza_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(png);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        text: shareText,
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────

  /// Carrega artwork em alta resolução para o poster.
  static Future<Uint8List?> _loadArt(int id) async {
    if (id == 0) return null;
    return ArtworkNotifier.queryArtworkHighRes(id);
  }

  static Future<ArtworkPalette> _paletteFromBytes(
    Uint8List? bytes,
    int id,
  ) async {
    if (bytes == null || bytes.isEmpty) return ArtworkPalette.fallback;
    final p = await ArtworkNotifier.extractPalette(bytes, songId: id);
    return p ?? ArtworkPalette.fallback;
  }

  static String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h${m > 0 ? " ${m}min" : ""}';
    return '$m min';
  }

  static ({List<LyricLine> lines, int highlight}) _pickLyricsWindow(
    List<LyricLine> all,
    int? around, {
    int maxLines = 6,
  }) {
    final clean = all.where((l) => !l.isEmpty).toList();
    if (clean.isEmpty) return (lines: const [], highlight: -1);
    if (clean.length <= maxLines) {
      final hl = around != null && around >= 0 && around < clean.length
          ? around
          : (clean.length / 2).floor();
      return (lines: clean, highlight: hl);
    }
    final pivot = (around != null && around >= 0 && around < clean.length)
        ? around
        : (clean.length / 2).floor();
    var start = pivot - (maxLines ~/ 2);
    if (start < 0) start = 0;
    var end = start + maxLines;
    if (end > clean.length) {
      end = clean.length;
      start = end - maxLines;
    }
    return (lines: clean.sublist(start, end), highlight: pivot - start);
  }
}

// ============================================================
// FRAME — offscreen + RepaintBoundary
// ============================================================

class _PosterFrame extends StatelessWidget {
  const _PosterFrame({required this.repaintKey, required this.child});
  final GlobalKey repaintKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: -99999,
      top: -99999,
      child: MediaQuery(
        // Garante densidade fixa, independente do device.
        data: const MediaQueryData(devicePixelRatio: 1.0),
        child: Material(
          type: MaterialType.transparency,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: RepaintBoundary(key: repaintKey, child: child),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// SONG / ALBUM / ARTIST / PLAYLIST POSTER — Artwork hero
// ============================================================

class _SongPoster extends StatelessWidget {
  const _SongPoster({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.palette,
    required this.artImage,
  });

  final _PosterKind kind;
  final String title;
  final String subtitle;
  final String? meta;
  final ArtworkPalette palette;
  final ui.Image? artImage;

  // Artwork fills a 1:1 square (1080×1080) at the top of the 1080×1920 canvas.
  static const double _artH = 1080.0;
  // Content starts inside the fade zone for visual continuity.
  static const double _contentTop = 868.0;

  @override
  Widget build(BuildContext context) {
    final base = _mkBase(palette.dominant);
    return SizedBox(
      width: ShareService._w,
      height: ShareService._h,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. Near-black base derived from dominant ──────
          Container(color: base),

          // ── 2. Artwork edge-to-edge at the top ───────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: _artH,
            child: Stack(
              fit: StackFit.expand,
              children: [
                artImage != null
                    ? RawImage(
                        image: artImage!,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.high,
                      )
                    : DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              palette.secondary ?? palette.muted,
                              palette.vibrant,
                              palette.dominant,
                            ],
                          ),
                        ),
                      ),
                // Side vignettes
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.45),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.45),
                      ],
                      stops: const [0.0, 0.42, 1.0],
                    ),
                  ),
                ),
                // Bottom fade — artwork dissolves into the dark base
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        base.withValues(alpha: 0.55),
                        base,
                      ],
                      stops: const [0.0, 0.46, 0.76, 1.0],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── 3. Subtle accent haze beneath artwork ─────────
          Positioned(
            top: 640,
            left: -220,
            right: -220,
            height: 640,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.28,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [palette.vibrant, Colors.transparent],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── 4. Grain texture ──────────────────────────────
          Opacity(
            opacity: 0.05,
            child: CustomPaint(
              size: const Size(ShareService._w, ShareService._h),
              painter: _GrainPainter(),
            ),
          ),

          // ── 5. Text content — bottom section ─────────────
          Positioned(
            top: _contentTop,
            left: 80,
            right: 80,
            bottom: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TopBar(palette: palette, kind: kind),
                    const SizedBox(height: 52),
                    _TitleBlock(
                      title: title,
                      subtitle: subtitle,
                      meta: meta,
                      palette: palette,
                    ),
                  ],
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Waveform(color: palette.vibrant),
                    const SizedBox(height: 44),
                    const Center(child: _Branding()),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _mkBase(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness * 0.10).clamp(0.0, 0.12)).toColor();
  }
}

// ============================================================
// LYRICS POSTER — compact header + lyrics as hero
// ============================================================

class _LyricsPoster extends StatelessWidget {
  const _LyricsPoster({
    required this.title,
    required this.subtitle,
    required this.palette,
    required this.artImage,
    required this.lines,
    required this.highlightIndex,
  });

  final String title;
  final String subtitle;
  final ArtworkPalette palette;
  final ui.Image? artImage;
  final List<LyricLine> lines;
  final int? highlightIndex;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: ShareService._w,
      height: ShareService._h,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Very dark, blob-free background
          _LyricsBackground(palette: palette, artImage: artImage),

          Padding(
            padding: const EdgeInsets.fromLTRB(80, 0, 80, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 96),
                _TopBar(palette: palette, kind: _PosterKind.lyrics),
                const SizedBox(height: 52),

                // Compact header: art thumbnail + title + artist in one row
                _LyricsHeader(
                  title: title,
                  subtitle: subtitle,
                  artImage: artImage,
                  palette: palette,
                ),
                const SizedBox(height: 52),

                Container(height: 1.0, color: Colors.white.withValues(alpha: 0.12)),
                const SizedBox(height: 36),

                // Lyrics — hero of the poster
                Expanded(
                  child: _LyricsLinesView(
                    lines: lines,
                    highlightIndex: highlightIndex,
                    accent: palette.vibrant,
                  ),
                ),

                const SizedBox(height: 44),
                const Center(child: _Branding()),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LyricsLinesView extends StatelessWidget {
  const _LyricsLinesView({
    required this.lines,
    required this.highlightIndex,
    required this.accent,
  });

  final List<LyricLine> lines;
  final int? highlightIndex;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();

    // Espelha exatamente a tela de Letras real (view_mode.dart):
    // weight w800/w600, alpha por distância, height 1.35.
    // Tamanho base ajustado ao canvas 1080 — equivale ao "lyricsFontLarge" do app.
    const baseFontSize = 38.0;
    final n = lines.length;
    final hasActive = highlightIndex != null && highlightIndex! >= 0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < n; i++) ...[
          _LyricLineRow(
            text: lines[i].text,
            isCurrent: hasActive && i == highlightIndex,
            isPast: hasActive && i < highlightIndex!,
            distance: hasActive ? (i - highlightIndex!).abs() : 0,
            hasActive: hasActive,
            baseFontSize: baseFontSize,
            accent: accent,
          ),
          if (i < n - 1) const SizedBox(height: 28),
        ],
      ],
    );
  }
}

class _LyricLineRow extends StatelessWidget {
  const _LyricLineRow({
    required this.text,
    required this.isCurrent,
    required this.isPast,
    required this.distance,
    required this.hasActive,
    required this.baseFontSize,
    required this.accent,
  });

  final String text;
  final bool isCurrent;
  final bool isPast;
  final int distance;
  final bool hasActive;
  final double baseFontSize;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    // Mesma fórmula de alpha do _LyricLineItem real.
    final alpha = isCurrent
        ? 1.0
        : !hasActive
            ? 0.45
            : isPast
                ? (0.35 - distance * 0.05).clamp(0.08, 0.35)
                : (0.45 - distance * 0.06).clamp(0.10, 0.45);

    final fontSize = isCurrent ? baseFontSize * 1.18 : baseFontSize;

    return Text(
      text,
      textAlign: TextAlign.left,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: Colors.white.withValues(alpha: alpha),
        fontSize: fontSize,
        fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
        height: 1.35,
        letterSpacing: -0.3,
        shadows: isCurrent
            ? [
                Shadow(
                  color: accent.withValues(alpha: 0.55),
                  blurRadius: 28,
                ),
                Shadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 14,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
    );
  }
}

// ============================================================
// LYRICS BACKGROUND — ultra-dark, artwork as ghost tint only
// ============================================================

class _LyricsBackground extends StatelessWidget {
  const _LyricsBackground({required this.palette, required this.artImage});
  final ArtworkPalette palette;
  final ui.Image? artImage;

  @override
  Widget build(BuildContext context) {
    final base = _mkBase(palette.dominant);
    final c2 = palette.secondary ?? palette.muted;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Near-black base derived from dominant color
        Container(color: base),

        // Artwork at ultra-low opacity — adds color soul without the blob
        if (artImage != null)
          Opacity(
            opacity: 0.22,
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(
                sigmaX: 90,
                sigmaY: 90,
                tileMode: TileMode.decal,
              ),
              child: SizedBox(
                width: ShareService._w,
                height: ShareService._h,
                child: RawImage(
                  image: artImage,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
          ),

        // Uniform dark overlay — eliminates the central blob effect
        Container(color: Colors.black.withValues(alpha: 0.42)),

        // Two gentle color bleeds — corners only, no center contamination
        _Blob(
          left: -320,
          top: -260,
          size: 860,
          color: palette.vibrant.withValues(alpha: 0.20),
        ),
        _Blob(
          right: -320,
          bottom: -260,
          size: 860,
          color: c2.withValues(alpha: 0.20),
        ),

        // Grain texture
        Opacity(
          opacity: 0.05,
          child: CustomPaint(
            size: const Size(ShareService._w, ShareService._h),
            painter: _GrainPainter(),
          ),
        ),
      ],
    );
  }

  Color _mkBase(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness * 0.08).clamp(0.0, 0.11)).toColor();
  }
}

// ============================================================
// LYRICS HEADER — art thumbnail + title + artist compact row
// ============================================================

class _LyricsHeader extends StatelessWidget {
  const _LyricsHeader({
    required this.title,
    required this.subtitle,
    required this.artImage,
    required this.palette,
  });

  final String title;
  final String subtitle;
  final ui.Image? artImage;
  final ArtworkPalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (artImage != null) ...[
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  width: 112,
                  height: 112,
                  child: RawImage(
                    image: artImage!,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
              Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                    width: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 32),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 3,
                decoration: BoxDecoration(
                  color: palette.vibrant,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: palette.vibrant.withValues(alpha: 0.55),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.1,
                  height: 1.06,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 14,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 28,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({
    this.left,
    this.right,
    this.top,
    this.bottom,
    required this.size,
    required this.color,
  });
  final double? left, right, top, bottom;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color, color.withValues(alpha: 0)],
              stops: const [0.0, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}

/// Grain leve — dois círculos por “tile” pseudo-aleatório.
class _GrainPainter extends CustomPainter {
  const _GrainPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFFFFFFF);
    // Pseudo-random determinístico — sem dependência externa.
    var seed = 1469598103;
    int next() {
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
      return seed;
    }

    const count = 1800;
    for (var i = 0; i < count; i++) {
      final x = (next() % size.width.toInt()).toDouble();
      final y = (next() % size.height.toInt()).toDouble();
      canvas.drawCircle(Offset(x, y), 0.6, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================
// SUBCOMPONENTES — barra superior, título, branding, waveform
// ============================================================

class _TopBar extends StatelessWidget {
  const _TopBar({required this.palette, required this.kind});
  final ArtworkPalette palette;
  final _PosterKind kind;

  @override
  Widget build(BuildContext context) {
    final (label, icon) = switch (kind) {
      _PosterKind.song => ('TOCANDO AGORA', Icons.graphic_eq_rounded),
      _PosterKind.album => ('ÁLBUM', Icons.album_rounded),
      _PosterKind.artist => ('ARTISTA', Icons.person_rounded),
      _PosterKind.playlist => ('PLAYLIST', Icons.queue_music_rounded),
      _PosterKind.lyrics => ('LETRA', Icons.lyrics_rounded),
    };
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.16),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: palette.vibrant, size: 22),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.6,
                ),
              ),
            ],
          ),
        ),
        // Logo mark — círculo com inicial.
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [palette.vibrant, palette.dominant],
            ),
            boxShadow: [
              BoxShadow(
                color: palette.vibrant.withValues(alpha: 0.45),
                blurRadius: 24,
                spreadRadius: -2,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Text(
            'C',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.palette,
  });

  final String title;
  final String subtitle;
  final String? meta;
  final ArtworkPalette palette;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Marca colorida acima do título — assinatura editorial.
        Container(
          width: 56,
          height: 4,
          decoration: BoxDecoration(
            color: palette.vibrant,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: palette.vibrant.withValues(alpha: 0.6),
                blurRadius: 12,
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Text(
          title,
          textAlign: TextAlign.left,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: 76,
            fontWeight: FontWeight.w800,
            letterSpacing: -2.0,
            height: 1.0,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 22,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          subtitle,
          textAlign: TextAlign.left,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.88),
            fontSize: 36,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.4,
          ),
        ),
        if (meta != null && meta!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            meta!,
            textAlign: TextAlign.left,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 22,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ],
    );
  }
}

/// “Waveform” ornamental — barras com alturas pseudo-aleatórias.
class _Waveform extends StatelessWidget {
  const _Waveform({required this.color});
  final Color color;

  static const _heights = <double>[
    8, 14, 22, 16, 28, 18, 36, 22, 44, 30,
    52, 38, 62, 42, 72, 48, 64, 40, 54, 32,
    44, 26, 38, 20, 30, 16, 22, 12, 16, 8,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < _heights.length; i++) ...[
            Container(
              width: 6,
              height: _heights[i],
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    color.withValues(alpha: 0.95),
                    color.withValues(alpha: 0.35),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
            if (i < _heights.length - 1) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _Branding extends StatelessWidget {
  const _Branding();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.headphones_rounded,
              size: 22,
              color: Colors.white.withValues(alpha: 0.85),
            ),
            const SizedBox(width: 12),
            Text(
              'Constanza Músicas',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Sua música. Seu silêncio. Seu momento.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 17,
            fontStyle: FontStyle.italic,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}
