import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:constanza_player/core/utils/app_page_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:constanza_player/presentation/providers/library_provider.dart';
import 'package:constanza_player/presentation/pages/library/artist_detail_page.dart';

/// Segmento parsed de uma string de artista.
class _ArtistSegment {
  _ArtistSegment(this.text, this.isArtist);
  final String text;
  final bool isArtist;
}

/// Widget que exibe nomes de artistas como links independentes.
///
/// Quando uma música possui dois ou mais artistas (separados por
/// `,`  `&`  `feat.`  `ft.`  `/`  `;`), cada nome é renderizado
/// como link tappable que navega para a respectiva tela do artista.
class ArtistLinksText extends ConsumerStatefulWidget {
  const ArtistLinksText({
    super.key,
    required this.artist,
    this.style,
    this.linkStyle,
    this.separatorStyle,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.suffix,
    this.suffixStyle,
    this.textAlign,
  });

  /// String crua do artista (ex: "Artist1 feat. Artist2 & Artist3").
  final String artist;

  /// Estilo base para todos os segmentos (nomes + separadores).
  final TextStyle? style;

  /// Estilo extra para nomes de artista encontrados na library (sublinhados, etc).
  /// Se null, usa [style] sem mudança.
  final TextStyle? linkStyle;

  /// Estilo para os separadores (", ", " feat. ", etc). Se null, usa [style].
  final TextStyle? separatorStyle;

  final int maxLines;
  final TextOverflow overflow;

  /// Texto adicional no final (ex: " · Album Name"). Não é tappable.
  final String? suffix;

  /// Estilo do suffix. Se null, usa [style].
  final TextStyle? suffixStyle;

  final TextAlign? textAlign;

  /// Regex para dividir a string em artistas e separadores.
  /// Captura: ", " / " & " / " feat. " / " feat " / " ft. " / " ft " / " / " / "; "
  static final _separatorPattern = RegExp(
    r'(\s*,\s+|\s+&\s+|\s+[Ff]eat\.?\s+|\s+[Ff]t\.?\s+|\s+/\s+|\s*;\s+)',
  );

  /// Retorna a lista de nomes de artista individuais (sem separadores).
  static List<String> splitArtists(String artist) {
    return artist
        .split(_separatorPattern)
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  @override
  ConsumerState<ArtistLinksText> createState() => _ArtistLinksTextState();
}

class _ArtistLinksTextState extends ConsumerState<ArtistLinksText> {
  List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers = [];
  }

  /// Faz o parse da string de artista em segmentos (artista / separador).
  List<_ArtistSegment> _parse(String input) {
    final segments = <_ArtistSegment>[];
    int lastEnd = 0;

    for (final match in ArtistLinksText._separatorPattern.allMatches(input)) {
      if (match.start > lastEnd) {
        final name = input.substring(lastEnd, match.start).trim();
        if (name.isNotEmpty) segments.add(_ArtistSegment(name, true));
      }
      segments.add(_ArtistSegment(match.group(0)!, false));
      lastEnd = match.end;
    }

    if (lastEnd < input.length) {
      final name = input.substring(lastEnd).trim();
      if (name.isNotEmpty) segments.add(_ArtistSegment(name, true));
    }

    return segments;
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();

    final segments = _parse(widget.artist);
    final allArtists = ref.read(libraryProvider).artists;
    final baseStyle = widget.style ?? DefaultTextStyle.of(context).style;
    final sepStyle = widget.separatorStyle ?? baseStyle;

    final spans = <InlineSpan>[];

    for (final seg in segments) {
      if (seg.isArtist) {
        // Tentar encontrar o artista na library
        final found = allArtists
            .where((a) => a.name.toLowerCase() == seg.text.toLowerCase())
            .firstOrNull;

        if (found != null) {
          final recognizer = TapGestureRecognizer()
            ..onTap = () {
              Navigator.of(
                context,
              ).push(AppPageRoute(page: ArtistDetailPage(artist: found)));
            };
          _recognizers.add(recognizer);
          spans.add(
            TextSpan(
              text: seg.text,
              style: widget.linkStyle ?? baseStyle,
              recognizer: recognizer,
            ),
          );
        } else {
          spans.add(TextSpan(text: seg.text, style: baseStyle));
        }
      } else {
        spans.add(TextSpan(text: seg.text, style: sepStyle));
      }
    }

    // Suffix (ex: " · Album Name")
    if (widget.suffix != null && widget.suffix!.isNotEmpty) {
      spans.add(
        TextSpan(text: widget.suffix, style: widget.suffixStyle ?? baseStyle),
      );
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: widget.maxLines,
      overflow: widget.overflow,
      textAlign: widget.textAlign,
    );
  }
}
