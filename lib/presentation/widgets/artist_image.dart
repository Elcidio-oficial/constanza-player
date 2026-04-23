import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:constanza_player/presentation/providers/artist_image_provider.dart';

/// Widget reutilizável para exibir foto de artista online.
///
/// Busca URL via [ArtistImageNotifier] (Deezer API) e usa
/// [CachedNetworkImage] para cache em disco e memória.
/// Fallback: avatar circular com inicial do nome.
///
/// Uso:
/// ```dart
/// ArtistImage(artistName: 'Adele', size: 60)
/// ```
class ArtistImage extends ConsumerWidget {
  const ArtistImage({
    super.key,
    required this.artistName,
    required this.size,
    this.isCircle = true,
    this.borderRadius,
  });

  final String artistName;
  final double size;
  final bool isCircle;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(artistImageProvider);
    final notifier = ref.read(artistImageProvider.notifier);
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final imageUrl = notifier.getImageUrl(artistName);

    final placeholder = _LetterAvatar(
      letter: artistName.isNotEmpty ? artistName[0].toUpperCase() : '?',
      size: size,
      colors: colors,
      theme: theme,
      isCircle: isCircle,
      borderRadius: borderRadius,
    );

    if (imageUrl == null) {
      return placeholder;
    }

    final image = CachedNetworkImage(
      imageUrl: imageUrl,
      width: size,
      height: size,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 300),
      placeholder: (_, __) => placeholder,
      errorWidget: (_, __, ___) => placeholder,
    );

    if (isCircle) {
      return ClipOval(
        child: SizedBox(width: size, height: size, child: image),
      );
    }

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(6),
      child: SizedBox(width: size, height: size, child: image),
    );
  }
}

/// Avatar com a inicial do nome do artista.
class _LetterAvatar extends StatelessWidget {
  const _LetterAvatar({
    required this.letter,
    required this.size,
    required this.colors,
    required this.theme,
    required this.isCircle,
    this.borderRadius,
  });

  final String letter;
  final double size;
  final ColorScheme colors;
  final ThemeData theme;
  final bool isCircle;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.outline.withValues(alpha: 0.1),
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircle
            ? null
            : (borderRadius ?? BorderRadius.circular(6)),
      ),
      child: Center(
        child: Text(
          letter,
          style: theme.textTheme.titleMedium?.copyWith(
            color: colors.onSurface.withValues(alpha: 0.3),
            fontWeight: FontWeight.w300,
            fontSize: (size * 0.4).clamp(14.0, 56.0),
          ),
        ),
      ),
    );
  }
}
