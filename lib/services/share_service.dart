import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:constanza_player/domain/entities/song.dart';
import 'package:constanza_player/presentation/providers/artwork_provider.dart';

/// Serviço de partilha — gera poster visual e abre o share intent do Android.
class ShareService {
  ShareService._();

  /// Partilha uma ou mais músicas gerando um poster visual.
  static Future<void> shareSongs({
    required BuildContext context,
    required List<Song> songs,
    ArtworkPalette? palette,
  }) async {
    if (songs.isEmpty) return;

    final song = songs.first;
    final isSingle = songs.length == 1;

    // Obtem artwork da música principal
    final artData = await ArtworkNotifier.queryArtworkForColor(song.numericId);

    ui.Image? artImage;
    if (artData != null && artData.isNotEmpty) {
      final codec = await ui.instantiateImageCodec(artData, targetWidth: 400);
      final frame = await codec.getNextFrame();
      artImage = frame.image;
    }

    // Renderiza poster off-screen
    final posterKey = GlobalKey();
    final poster = _buildPoster(
      song: song,
      songs: songs,
      isSingle: isSingle,
      palette: palette,
      artImage: artImage,
      repaintKey: posterKey,
    );

    // Insere widget na árvore de forma temporária para renderizar
    final overlay = OverlayEntry(builder: (_) => poster);
    if (!context.mounted) return;
    Overlay.of(context).insert(overlay);

    // Aguarda um frame para que o widget seja pintado
    await Future.delayed(const Duration(milliseconds: 120));

    Uint8List? pngBytes;
    try {
      final boundary =
          posterKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 3.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        pngBytes = byteData?.buffer.asUint8List();
      }
    } finally {
      overlay.remove();
    }

    if (pngBytes == null) {
      // Fallback: texto simples
      _shareAsText(songs);
      return;
    }

    // Salva em ficheiro temporário
    final tmp = await getTemporaryDirectory();
    final file = File(
      '${tmp.path}/constanza_share_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(pngBytes);

    final text = isSingle
        ? '🎵 ${song.title} — ${song.artist}'
        : '🎵 ${songs.length} músicas partilhadas via Constanza';

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        text: text,
      ),
    );
  }

  static void _shareAsText(List<Song> songs) {
    final lines = songs.map((s) => '• ${s.title} — ${s.artist}').join('\n');
    SharePlus.instance.share(
      ShareParams(text: '🎵 Constanza Músicas\n\n$lines'),
    );
  }

  static Widget _buildPoster({
    required Song song,
    required List<Song> songs,
    required bool isSingle,
    required ArtworkPalette? palette,
    required ui.Image? artImage,
    required GlobalKey repaintKey,
  }) {
    return Positioned(
      left: -9999,
      top: -9999,
      child: RepaintBoundary(
        key: repaintKey,
        child: _SharePoster(
          song: song,
          songs: songs,
          isSingle: isSingle,
          palette: palette,
          artImage: artImage,
        ),
      ),
    );
  }
}

// ── Widget do poster visual ───────────────────────────────────────────────────

class _SharePoster extends StatelessWidget {
  const _SharePoster({
    required this.song,
    required this.songs,
    required this.isSingle,
    required this.palette,
    required this.artImage,
  });

  final Song song;
  final List<Song> songs;
  final bool isSingle;
  final ArtworkPalette? palette;
  final ui.Image? artImage;

  @override
  Widget build(BuildContext context) {
    const w = 600.0;
    const h = 600.0;

    final c1 = palette?.dominant ?? const Color(0xFF1A1A2E);
    final c2 =
        palette?.secondary ??
        palette?.muted ??
        HSLColor.fromColor(c1).withLightness(0.25).toColor();
    final c3 =
        palette?.tertiary ??
        HSLColor.fromColor(c1).withLightness(0.12).toColor();

    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        children: [
          // ── Fundo com gradiente da palette ──
          Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.3, -0.4),
                radius: 1.2,
                colors: [c2, c1, c3],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // ── Círculos decorativos translúcidos ──
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c2.withValues(alpha: 0.25),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c1.withValues(alpha: 0.30),
              ),
            ),
          ),

          // ── Artwork central ──
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 24),
                // Artwork com sombra
                Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 40,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: artImage != null
                        ? RawImage(image: artImage, fit: BoxFit.cover)
                        : Container(
                            color: c2,
                            child: const Icon(
                              Icons.music_note_rounded,
                              color: Colors.white54,
                              size: 80,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 28),
                // Título
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    isSingle ? song.title : '${songs.length} músicas',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Artista / álbum
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    isSingle
                        ? '${song.artist} · ${song.album}'
                        : songs.map((s) => s.artist).toSet().take(3).join(', '),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                if (isSingle && song.album.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    song.durationFormatted,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Barra inferior com branding ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.45),
                  ],
                ),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.music_note_rounded,
                      color: Colors.white.withValues(alpha: 0.6),
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Constanza Músicas',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
