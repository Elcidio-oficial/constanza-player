import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:constanza_player/presentation/providers/artwork_provider.dart';

/// Widget reutilizável para exibir artwork de música/álbum.
///
/// Carrega artwork via [ArtworkNotifier] com cache LRU.
/// Mostra placeholder enquanto carrega, com fade-in suave.
///
/// A resolução é calculada automaticamente a partir do [size]
/// do widget × devicePixelRatio do dispositivo, garantindo
/// máxima nitidez em qualquer tela.
///
/// Uso:
/// ```dart
/// ArtworkImage.song(songId: song.numericId, size: 48)
/// ArtworkImage.album(albumId: album.numericId, size: 120)
/// ```
class ArtworkImage extends ConsumerWidget {
  const ArtworkImage({
    super.key,
    required this.id,
    required this.type,
    required this.size,
    this.borderRadius,
    this.isCircle = false,
    this.placeholderIcon,
    this.placeholderIconSize,
  });

  /// Artwork de uma música.
  const ArtworkImage.song({
    super.key,
    required int songId,
    required this.size,
    this.borderRadius,
    this.isCircle = false,
    this.placeholderIcon,
    this.placeholderIconSize,
  }) : id = songId,
       type = ArtworkType.AUDIO;

  /// Artwork de um álbum.
  const ArtworkImage.album({
    super.key,
    required int albumId,
    required this.size,
    this.borderRadius,
    this.isCircle = false,
    this.placeholderIcon,
    this.placeholderIconSize,
  }) : id = albumId,
       type = ArtworkType.ALBUM;

  final int id;
  final ArtworkType type;
  final double size;
  final BorderRadius? borderRadius;
  final bool isCircle;
  final IconData? placeholderIcon;
  final double? placeholderIconSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final notifier = ref.read(artworkProvider.notifier);

    // Resolução real em pixels: tamanho do widget × pixel ratio do device.
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final resolution = (size * dpr).ceil().clamp(100, 900);

    // Watch counter but only rebuild when OUR artwork becomes available.
    // Returns identity hashCode of the Uint8List — skips rebuild if same object.
    ref.watch(
      artworkProvider.select((_) {
        final d = notifier.getArtwork(id, type, size: resolution);
        return identityHashCode(d);
      }),
    );
    final data = notifier.getArtwork(id, type, size: resolution);

    final br = isCircle ? null : (borderRadius ?? BorderRadius.circular(6));
    final shape = isCircle ? BoxShape.circle : BoxShape.rectangle;
    final icon =
        placeholderIcon ??
        (type == ArtworkType.ALBUM
            ? Icons.album_rounded
            : Icons.music_note_rounded);
    final iconSize = placeholderIconSize ?? (size * 0.45).clamp(16.0, 80.0);

    return SizedBox(
      width: size,
      height: size,
      child: data != null && data.isNotEmpty
          ? _ArtworkDisplay(
              data: data,
              size: size,
              borderRadius: br,
              shape: shape,
            )
          : _Placeholder(
              size: size,
              borderRadius: br,
              shape: shape,
              icon: icon,
              iconSize: iconSize,
              colors: colors,
            ),
    );
  }
}

class _ArtworkDisplay extends StatelessWidget {
  const _ArtworkDisplay({
    required this.data,
    required this.size,
    required this.borderRadius,
    required this.shape,
  });

  final Uint8List data;
  final double size;
  final BorderRadius? borderRadius;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    final image = Image.memory(
      data,
      width: size,
      height: size,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      // Qualidade de renderização alta para imagens grandes
      filterQuality: size > 100 ? FilterQuality.medium : FilterQuality.low,
    );

    if (shape == BoxShape.circle) {
      return ClipOval(child: image);
    }

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: image,
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.size,
    required this.borderRadius,
    required this.shape,
    required this.icon,
    required this.iconSize,
    required this.colors,
  });

  final double size;
  final BorderRadius? borderRadius;
  final BoxShape shape;
  final IconData icon;
  final double iconSize;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: shape == BoxShape.circle ? null : borderRadius,
        shape: shape,
      ),
      child: Center(
        child: Icon(
          icon,
          size: iconSize,
          color: colors.onSurface.withValues(alpha: 0.15),
        ),
      ),
    );
  }
}
