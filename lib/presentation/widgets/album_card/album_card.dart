import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:constanza_player/core/theme/app_spacing.dart';
import 'package:constanza_player/core/constants/app_constants.dart';
import 'package:constanza_player/domain/entities/album.dart';
import 'package:constanza_player/presentation/widgets/artwork_image.dart';

/// Card de álbum para carrossel horizontal.
class AlbumCard extends ConsumerWidget {
  const AlbumCard({super.key, required this.album, this.onTap});

  final Album album;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: AppConstants.albumArtCarousel,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // === Capa ===
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    offset: const Offset(0, 2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: ArtworkImage.album(
                albumId: album.numericId,
                size: AppConstants.albumArtCarousel,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                placeholderIcon: Icons.album_rounded,
                placeholderIconSize: 40,
              ),
            ),

            const SizedBox(height: AppSpacing.xs),

            // === Nome ===
            Text(
              album.name,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 1),

            // === Artista ===
            Text(
              album.artist,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.4),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
