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
    // Índice da linha atual dentro da letra sem linhas vazias — é sobre
    // essa lista que cada modelo recorta o seu trecho.
    final clean = lines.where((l) => !l.isEmpty).toList();
    if (clean.isEmpty) {
      if (context.mounted) {
        await shareSongs(context: context, songs: [song], palette: palette);
      }
      return;
    }
    int? hl;
    if (highlightIndex != null &&
        highlightIndex >= 0 &&
        highlightIndex < lines.length) {
      final i = clean.indexOf(lines[highlightIndex]);
      if (i >= 0) hl = i;
    }
    if (!context.mounted) return;

    await _renderAndShare(
      context: context,
      kind: _PosterKind.lyrics,
      title: song.title,
      subtitle: song.artist,
      meta: song.album.isNotEmpty ? song.album : null,
      art: art,
      palette: pal,
      lyricsLines: clean,
      lyricsHighlight: hl,
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

    // Cada modelo é um poster 1080×1920 completo; a tela de pré-visualização
    // mostra-os reduzidos e captura o escolhido no tamanho real.
    final templates = <_PosterTemplate>[
      if (kind == _PosterKind.lyrics) ...[
        _PosterTemplate(
          'Cartão',
          Icons.style_rounded,
          _LyricsCardPoster(
            title: title,
            subtitle: subtitle,
            palette: palette,
            artImage: artImage,
            window: _pickLyricsWindow(
              lyricsLines ?? const [],
              lyricsHighlight,
              maxLines: 5,
            ),
          ),
        ),
        _PosterTemplate(
          'Citação',
          Icons.format_quote_rounded,
          _LyricsQuotePoster(
            title: title,
            subtitle: subtitle,
            palette: palette,
            artImage: artImage,
            window: _pickLyricsWindow(
              lyricsLines ?? const [],
              lyricsHighlight,
              maxLines: 2,
              highlightFirst: true,
            ),
          ),
        ),
        _PosterTemplate('Clássico', Icons.lyrics_rounded, () {
          final w = _pickLyricsWindow(
            lyricsLines ?? const [],
            lyricsHighlight,
            maxLines: 11,
          );
          return _LyricsPoster(
            title: title,
            subtitle: subtitle,
            palette: palette,
            artImage: artImage,
            lines: w.lines,
            highlightIndex: w.highlight,
          );
        }()),
      ] else ...[
        _PosterTemplate(
          'Capa',
          Icons.crop_square_rounded,
          _CoverPoster(
            kind: kind,
            title: title,
            subtitle: subtitle,
            meta: meta,
            palette: palette,
            artImage: artImage,
          ),
        ),
        if (kind != _PosterKind.artist)
          _PosterTemplate(
            'Vinil',
            Icons.album_rounded,
            _VinylPoster(
              kind: kind,
              title: title,
              subtitle: subtitle,
              meta: meta,
              palette: palette,
              artImage: artImage,
            ),
          ),
        _PosterTemplate(
          'Editorial',
          Icons.view_agenda_rounded,
          _SongPoster(
            kind: kind,
            title: title,
            subtitle: subtitle,
            meta: meta,
            palette: palette,
            artImage: artImage,
          ),
        ),
      ],
    ];

    if (!context.mounted) {
      artImage?.dispose();
      return;
    }
    // Ícone já decodificado: aparece no primeiro frame do preview e da captura.
    await precacheImage(const AssetImage(_appIconAsset), context);
    if (!context.mounted) {
      artImage?.dispose();
      return;
    }
    final Uint8List? png;
    try {
      png = await Navigator.of(context).push<Uint8List>(
        PageRouteBuilder(
          opaque: true,
          transitionDuration: const Duration(milliseconds: 320),
          pageBuilder: (_, _, _) =>
              _PosterPreviewPage(templates: templates, palette: palette),
          transitionsBuilder: (_, anim, _, child) => FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
            child: child,
          ),
        ),
      );
    } finally {
      artImage?.dispose();
    }

    // Fechou sem partilhar.
    if (png == null || png.isEmpty) return;

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
    // true: o trecho começa na linha atual (citação); false: centra nela.
    bool highlightFirst = false,
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
    var start = highlightFirst ? pivot : pivot - (maxLines ~/ 2);
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
// PRÉ-VISUALIZAÇÃO — escolhe o modelo e captura em 1080×1920
// ============================================================

class _PosterTemplate {
  const _PosterTemplate(this.label, this.icon, this.poster);
  final String label;
  final IconData icon;
  final Widget poster;
}

/// Mostra os modelos reduzidos (deslizar troca) e devolve o PNG do escolhido.
class _PosterPreviewPage extends StatefulWidget {
  const _PosterPreviewPage({required this.templates, required this.palette});
  final List<_PosterTemplate> templates;
  final ArtworkPalette palette;

  @override
  State<_PosterPreviewPage> createState() => _PosterPreviewPageState();
}

class _PosterPreviewPageState extends State<_PosterPreviewPage> {
  late final PageController _pages = PageController(viewportFraction: 0.84);
  late final List<GlobalKey> _keys = [
    for (final _ in widget.templates) GlobalKey(),
  ];
  int _index = 0;
  bool _busy = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    Uint8List? png;
    try {
      final boundary =
          _keys[_index].currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary != null) {
        // O poster é montado em 1080×1920 lógicos (o FittedBox só reduz na
        // tela), então pixelRatio 1 dá o PNG no tamanho real.
        final image = await boundary.toImage(pixelRatio: 1.0);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        png = data?.buffer.asUint8List();
      }
    } catch (e) {
      debugPrint('[Share] poster capture failed: $e');
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (png == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível gerar o poster')),
      );
      return;
    }
    Navigator.of(context).pop(png);
  }

  @override
  Widget build(BuildContext context) {
    final accent = _readableAccent(widget.palette.vibrant);
    final bg = HSLColor.fromColor(widget.palette.dominant);
    final base = bg.withLightness((bg.lightness * 0.18).clamp(0.04, 0.10));
    final many = widget.templates.length > 1;

    return Scaffold(
      backgroundColor: base.toColor(),
      body: Stack(
        children: [
          // Brilho suave da cor da capa atrás do preview.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.2),
                  radius: 1.1,
                  colors: [
                    widget.palette.dominant.withValues(alpha: 0.35),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Fechar',
                        icon: const Icon(Icons.close_rounded),
                        color: Colors.white,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 4),
                      const Expanded(
                        child: Text(
                          'Partilhar como poster',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: PageView.builder(
                    controller: _pages,
                    itemCount: widget.templates.length,
                    physics: many
                        ? const BouncingScrollPhysics()
                        : const NeverScrollableScrollPhysics(),
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (_, i) => AnimatedBuilder(
                      animation: _pages,
                      builder: (_, child) {
                        final page =
                            _pages.hasClients && _pages.position.haveDimensions
                            ? _pages.page ?? _index.toDouble()
                            : _index.toDouble();
                        final t = (1 - (page - i).abs()).clamp(0.0, 1.0);
                        return Transform.scale(
                          scale: 0.9 + 0.1 * t,
                          child: Opacity(
                            opacity: 0.45 + 0.55 * t,
                            child: child,
                          ),
                        );
                      },
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: ShareService._w / ShareService._h,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  blurRadius: 40,
                                  offset: const Offset(0, 18),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: FittedBox(
                                child: MediaQuery(
                                  // Poster idêntico em qualquer aparelho.
                                  data: MediaQuery.of(
                                    context,
                                  ).copyWith(textScaler: TextScaler.noScaling),
                                  child: RepaintBoundary(
                                    key: _keys[i],
                                    child: SizedBox(
                                      width: ShareService._w,
                                      height: ShareService._h,
                                      child: widget.templates[i].poster,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (many)
                  SizedBox(
                    height: 44,
                    // Encolhe em telas estreitas em vez de transbordar.
                    child: FittedBox(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < widget.templates.length; i++)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                              ),
                              child: _TemplateChip(
                                label: widget.templates[i].label,
                                icon: widget.templates[i].icon,
                                selected: i == _index,
                                accent: accent,
                                onTap: () => _pages.animateToPage(
                                  i,
                                  duration: const Duration(milliseconds: 380),
                                  curve: Curves.easeOutCubic,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onPressed: _busy ? null : _share,
                      icon: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.black,
                              ),
                            )
                          : const Icon(Icons.ios_share_rounded),
                      label: Text(_busy ? 'A preparar…' : 'Partilhar'),
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

class _TemplateChip extends StatelessWidget {
  const _TemplateChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.accent,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? accent : Colors.white.withValues(alpha: 0.10),
            width: 1.4,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? accent : Colors.white.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: selected ? 1 : 0.6),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Garante que a cor de destaque se lê sobre fundo escuro.
Color _readableAccent(Color c) {
  final hsl = HSLColor.fromColor(c);
  return hsl
      .withLightness(hsl.lightness.clamp(0.55, 0.78))
      .withSaturation(hsl.saturation.clamp(0.35, 1.0))
      .toColor();
}

/// Fundo quase preto com o tom da capa.
Color _deepBase(Color c, {double max = 0.10}) {
  final hsl = HSLColor.fromColor(c);
  return hsl
      .withLightness((hsl.lightness * 0.14).clamp(0.03, max))
      .withSaturation((hsl.saturation * 0.8).clamp(0.0, 0.6))
      .toColor();
}

/// Artwork ou, sem capa, um gradiente com as cores da paleta.
class _Art extends StatelessWidget {
  const _Art({required this.image, required this.palette});
  final ui.Image? image;
  final ArtworkPalette palette;

  @override
  Widget build(BuildContext context) {
    if (image != null) {
      return RawImage(
        image: image,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      );
    }
    return DecoratedBox(
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
      // Nota proporcional ao tamanho: serve à capa grande e à miniatura.
      child: FractionallySizedBox(
        widthFactor: 0.32,
        heightFactor: 0.32,
        child: FittedBox(
          child: Icon(
            Icons.music_note_rounded,
            color: Colors.white.withValues(alpha: 0.35),
          ),
        ),
      ),
    );
  }
}

/// Rótulo pequeno em maiúsculas com o tipo do conteúdo.
String _kindLabel(_PosterKind kind) => switch (kind) {
  _PosterKind.song => 'A OUVIR AGORA',
  _PosterKind.album => 'ÁLBUM',
  _PosterKind.artist => 'ARTISTA',
  _PosterKind.playlist => 'PLAYLIST',
  _PosterKind.lyrics => 'LETRA',
};

// ============================================================
// MODELO "CAPA" — capa em destaque sobre fundo desfocado
// ============================================================

class _CoverPoster extends StatelessWidget {
  const _CoverPoster({
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

  static const double _card = 820;

  @override
  Widget build(BuildContext context) {
    final base = _deepBase(palette.dominant);
    final accent = _readableAccent(palette.vibrant);
    final round = kind == _PosterKind.artist;

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: base),
        // Capa ampliada e muito desfocada: o fundo tem a "cor" da música.
        if (artImage != null)
          Opacity(
            opacity: 0.85,
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(
                sigmaX: 110,
                sigmaY: 110,
                tileMode: TileMode.clamp,
              ),
              child: Transform.scale(
                scale: 1.4,
                child: RawImage(image: artImage, fit: BoxFit.cover),
              ),
            ),
          ),
        // Escurece de cima para baixo para o texto ler bem.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                base.withValues(alpha: 0.35),
                base.withValues(alpha: 0.55),
                base.withValues(alpha: 0.92),
                base,
              ],
              stops: const [0.0, 0.42, 0.72, 1.0],
            ),
          ),
        ),
        const _Grain(),

        // Rótulo
        Positioned(
          top: 150,
          left: 0,
          right: 0,
          child: Center(
            child: _KindPill(label: _kindLabel(kind), accent: accent),
          ),
        ),

        // Capa
        Positioned(
          top: 270,
          left: (ShareService._w - _card) / 2,
          width: _card,
          height: _card,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: round ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: round ? null : BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  blurRadius: 90,
                  offset: const Offset(0, 40),
                ),
                BoxShadow(
                  color: palette.vibrant.withValues(alpha: 0.30),
                  blurRadius: 140,
                  spreadRadius: -20,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(round ? _card / 2 : 40),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _Art(image: artImage, palette: palette),
                  // Fio de luz na borda, como em vidro.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      shape: round ? BoxShape.circle : BoxShape.rectangle,
                      borderRadius: round ? null : BorderRadius.circular(40),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                        width: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Texto
        Positioned(
          top: 270 + _card + 90,
          left: 90,
          right: 90,
          child: Column(
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 78,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -2.4,
                  height: 1.02,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 38,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.5,
                ),
              ),
              if (meta != null && meta!.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  meta!.toUpperCase(),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.2,
                  ),
                ),
              ],
            ],
          ),
        ),

        const Positioned(
          left: 0,
          right: 0,
          bottom: 90,
          child: Center(child: _BrandMark()),
        ),
      ],
    );
  }
}

// ============================================================
// MODELO "VINIL" — capa como capa de disco, vinil saindo
// ============================================================

class _VinylPoster extends StatelessWidget {
  const _VinylPoster({
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

  // Disco cabe inteiro no canvas: sai ~55 % para fora da capa.
  static const double _sleeve = 640;
  static const double _disc = 620;
  static const double _top = 380;

  @override
  Widget build(BuildContext context) {
    final base = _deepBase(palette.dominant, max: 0.12);
    final accent = _readableAccent(palette.vibrant);

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: base),
        // Luz de palco atrás do disco.
        Positioned(
          top: _top - 260,
          left: 80,
          width: 1200,
          height: 1200,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  palette.vibrant.withValues(alpha: 0.38),
                  palette.vibrant.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
        const _Grain(),

        Positioned(
          top: 120,
          left: 90,
          right: 90,
          child: Row(
            children: [
              _KindPill(label: _kindLabel(kind), accent: accent),
              const Spacer(),
              const _BrandMark(compact: true),
            ],
          ),
        ),

        // Disco saindo da capa para a direita.
        Positioned(
          top: _top + (_sleeve - _disc) / 2,
          left: 90 + _sleeve - _disc * 0.45,
          width: _disc,
          height: _disc,
          child: _VinylDisc(artImage: artImage, palette: palette),
        ),

        // Capa do disco
        Positioned(
          top: _top,
          left: 90,
          width: _sleeve,
          height: _sleeve,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 60,
                  offset: const Offset(18, 30),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _Art(image: artImage, palette: palette),
                  // Brilho de capa plastificada.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.16),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.18),
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Texto
        Positioned(
          top: _top + _sleeve + 140,
          left: 90,
          right: 90,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 6,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 34),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 100,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -2.8,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: accent,
                  fontSize: 40,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.6,
                ),
              ),
              if (meta != null && meta!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  meta!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 26,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),

        Positioned(
          left: 90,
          right: 90,
          bottom: 100,
          child: Container(
            height: 1.5,
            color: Colors.white.withValues(alpha: 0.12),
          ),
        ),
        Positioned(
          left: 90,
          bottom: 52,
          child: Text(
            'CONSTANZA MÚSICAS',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 4,
            ),
          ),
        ),
      ],
    );
  }
}

/// Disco de vinil: sulcos, reflexo e selo central com a capa.
class _VinylDisc extends StatelessWidget {
  const _VinylDisc({required this.artImage, required this.palette});
  final ui.Image? artImage;
  final ArtworkPalette palette;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        final d = c.maxWidth;
        final label = d * 0.36;
        return Stack(
          alignment: Alignment.center,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 50,
                    offset: const Offset(10, 24),
                  ),
                ],
              ),
              child: CustomPaint(
                size: Size.square(d),
                painter: const _VinylPainter(),
              ),
            ),
            ClipOval(
              child: SizedBox.square(
                dimension: label,
                child: _Art(image: artImage, palette: palette),
              ),
            ),
            // Furo central
            Container(
              width: d * 0.03,
              height: d * 0.03,
              decoration: const BoxDecoration(
                color: Color(0xFF0B0B0B),
                shape: BoxShape.circle,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _VinylPainter extends CustomPainter {
  const _VinylPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF111111));

    // Sulcos
    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var rr = r * 0.22; rr < r * 0.97; rr += 5) {
      final a = 0.035 + 0.03 * ((rr / 5).floor() % 3 == 0 ? 1 : 0);
      groove.color = Colors.white.withValues(alpha: a);
      canvas.drawCircle(c, rr, groove);
    }

    // Reflexo em dois feixes opostos
    final sheen = Paint()
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: 0.13),
          Colors.transparent,
          Colors.transparent,
          Colors.white.withValues(alpha: 0.10),
          Colors.transparent,
        ],
        stops: const [0.0, 0.08, 0.18, 0.5, 0.58, 0.68],
        transform: const GradientRotation(-0.6),
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r * 0.97, sheen);

    // Borda
    canvas.drawCircle(
      c,
      r - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.08),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _KindPill extends StatelessWidget {
  const _KindPill({required this.label, required this.accent});
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
          width: 1.4,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: accent.withValues(alpha: 0.7), blurRadius: 12),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: 3.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ícone oficial do app (assets/icon/icon.png) com cantos de ícone Android.
class _AppIcon extends StatelessWidget {
  const _AppIcon({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.26);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: size * 0.4,
            offset: Offset(0, size * 0.08),
          ),
        ],
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.22),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Image.asset(
          _appIconAsset,
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

const _appIconAsset = 'assets/icon/icon.png';

/// Assinatura do app no rodapé.
class _BrandMark extends StatelessWidget {
  const _BrandMark({this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final mark = _AppIcon(size: compact ? 60 : 54);
    if (compact) return mark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 16),
        Text(
          'Constanza Músicas',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _Grain extends StatelessWidget {
  const _Grain();

  @override
  Widget build(BuildContext context) {
    return const Opacity(
      opacity: 0.05,
      child: CustomPaint(
        size: Size(ShareService._w, ShareService._h),
        painter: _GrainPainter(),
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
                    Container(
                      height: 1.5,
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
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

typedef _LyricsWindow = ({List<LyricLine> lines, int highlight});

/// Capa pequena com cantos arredondados (cabeçalhos dos posters de letra).
class _ArtThumb extends StatelessWidget {
  const _ArtThumb({
    required this.image,
    required this.palette,
    required this.size,
  });
  final ui.Image? image;
  final ArtworkPalette palette;
  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.18);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: _Art(image: image, palette: palette),
      ),
    );
  }
}

// ============================================================
// LETRA "CARTÃO" — cartão de cor sólida, letra em destaque
// ============================================================

class _LyricsCardPoster extends StatelessWidget {
  const _LyricsCardPoster({
    required this.title,
    required this.subtitle,
    required this.palette,
    required this.artImage,
    required this.window,
  });

  final String title;
  final String subtitle;
  final ArtworkPalette palette;
  final ui.Image? artImage;
  final _LyricsWindow window;

  @override
  Widget build(BuildContext context) {
    // Cor do cartão: tom da capa, escuro o bastante para texto branco.
    final hsl = HSLColor.fromColor(palette.vibrant);
    final card = hsl
        .withLightness(hsl.lightness.clamp(0.26, 0.34))
        .withSaturation(hsl.saturation.clamp(0.30, 0.75))
        .toColor();
    final deep = HSLColor.fromColor(card).withLightness(0.14).toColor();
    final n = window.lines.length;
    // Menos linhas → letra maior.
    final fontSize = n <= 2 ? 84.0 : (n <= 4 ? 72.0 : 64.0);

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [card, deep],
            ),
          ),
        ),
        Positioned(
          top: -300,
          left: -300,
          width: 1100,
          height: 1100,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.14),
                  Colors.white.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
        const _Grain(),

        // Cabeçalho
        Positioned(
          top: 150,
          left: 96,
          right: 96,
          child: Row(
            children: [
              _ArtThumb(image: artImage, palette: palette, size: 136),
              const SizedBox(width: 34),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 44,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.0,
                        height: 1.08,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 32,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Letra
        Positioned(
          top: 400,
          bottom: 300,
          left: 96,
          right: 96,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < n; i++)
                Padding(
                  padding: EdgeInsets.only(bottom: i < n - 1 ? 26 : 0),
                  child: Text(
                    window.lines[i].text,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(
                        alpha: i == window.highlight ? 1.0 : 0.58,
                      ),
                      fontSize: fontSize,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.4,
                      height: 1.18,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Rodapé
        Positioned(
          left: 96,
          right: 96,
          bottom: 110,
          child: Row(
            children: [
              const _BrandMark(),
              const Spacer(),
              Icon(
                Icons.format_quote_rounded,
                size: 56,
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================
// LETRA "CITAÇÃO" — o verso atual como frase em destaque
// ============================================================

class _LyricsQuotePoster extends StatelessWidget {
  const _LyricsQuotePoster({
    required this.title,
    required this.subtitle,
    required this.palette,
    required this.artImage,
    required this.window,
  });

  final String title;
  final String subtitle;
  final ArtworkPalette palette;
  final ui.Image? artImage;
  final _LyricsWindow window;

  @override
  Widget build(BuildContext context) {
    final base = _deepBase(palette.dominant);
    final accent = _readableAccent(palette.vibrant);
    final quote = window.lines.map((l) => l.text.trim()).join('\n');
    final long = quote.length > 90;

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: base),
        if (artImage != null)
          Opacity(
            opacity: 0.55,
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(
                sigmaX: 120,
                sigmaY: 120,
                tileMode: TileMode.clamp,
              ),
              child: Transform.scale(
                scale: 1.5,
                child: RawImage(image: artImage, fit: BoxFit.cover),
              ),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                base.withValues(alpha: 0.55),
                base.withValues(alpha: 0.80),
                base,
              ],
              stops: const [0.0, 0.6, 1.0],
            ),
          ),
        ),
        const _Grain(),

        Positioned(
          top: 120,
          left: 96,
          right: 96,
          child: Row(
            children: [
              _KindPill(label: 'LETRA', accent: accent),
              const Spacer(),
              const _BrandMark(compact: true),
            ],
          ),
        ),

        // Aspas gigantes + verso, centrados entre o topo e os créditos.
        Positioned(
          top: 260,
          left: 96,
          right: 96,
          bottom: 520,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // O glifo tem muito ar em cima; recorta só a parte visível.
              SizedBox(
                height: 130,
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  maxHeight: 400,
                  child: Transform.translate(
                    offset: const Offset(-8, -40),
                    child: Text(
                      '“',
                      style: TextStyle(
                        color: accent,
                        fontSize: 300,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Flexible(
                child: Text(
                  quote,
                  maxLines: 7,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: long ? 72 : 92,
                    fontWeight: FontWeight.w800,
                    letterSpacing: long ? -1.6 : -2.4,
                    height: 1.12,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Créditos
        Positioned(
          left: 96,
          right: 96,
          bottom: 250,
          child: Row(
            children: [
              _ArtThumb(image: artImage, palette: palette, size: 150),
              const SizedBox(width: 36),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 5,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 44,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.0,
                        height: 1.08,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 32,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        Positioned(
          left: 96,
          right: 96,
          bottom: 170,
          child: Container(
            height: 1.5,
            color: Colors.white.withValues(alpha: 0.12),
          ),
        ),
        Positioned(
          left: 96,
          bottom: 100,
          child: Text(
            'CONSTANZA MÚSICAS',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 4,
            ),
          ),
        ),
      ],
    );
  }
}

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

                Container(
                  height: 1.0,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
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
                Shadow(color: accent.withValues(alpha: 0.55), blurRadius: 28),
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
        const _AppIcon(size: 60),
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
            fontSize: 92,
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
            const _AppIcon(size: 46),
            const SizedBox(width: 14),
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
