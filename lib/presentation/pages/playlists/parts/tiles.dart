// ignore_for_file: curly_braces_in_flow_control_structures, unused_element_parameter
part of '../playlists_page.dart';

class _SmartPlaylistTile extends ConsumerWidget {
  const _SmartPlaylistTile({required this.playlist});
  final Playlist playlist;

  IconData get _icon => switch (playlist.id) {
    'fav' => Icons.favorite_rounded,
    'recent' => Icons.history_rounded,
    'most' => Icons.trending_up_rounded,
    _ => Icons.queue_music_rounded,
  };

  Color _accentColor(ColorScheme colors) => switch (playlist.id) {
    'fav' => colors.error,
    'recent' => colors.primary,
    'most' => Colors.amber.shade600,
    _ => colors.onSurface.withValues(alpha: 0.5),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accent = _accentColor(colors);

    // Para 'fav' puxar dados reais da library
    final songs = playlist.id == 'fav'
        ? ref.watch(
            libraryProvider.select(
              (s) => s.songs.where((s) => s.isFavorite).toList(),
            ),
          )
        : playlist.songs;

    final totalDuration = songs.fold<Duration>(
      Duration.zero,
      (sum, s) => sum + s.duration,
    );
    final hours = totalDuration.inHours;
    final mins = totalDuration.inMinutes.remainder(60);
    final durationStr = hours > 0 ? '${hours}h ${mins}min' : '$mins min';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      leading: songs.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              child: ArtworkImage.song(
                songId: songs.first.numericId,
                size: 52,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                placeholderIcon: _icon,
                placeholderIconSize: 24,
              ),
            )
          : Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Icon(_icon, size: 22, color: accent),
            ),
      title: Text(
        playlist.name,
        style: theme.textTheme.titleSmall?.copyWith(color: colors.onSurface),
      ),
      subtitle: Text(
        songs.isEmpty
            ? 'Nenhuma música'
            : '${songs.length} música${songs.length != 1 ? 's' : ''} · $durationStr',
        style: theme.textTheme.bodySmall?.copyWith(
          color: colors.onSurface.withValues(alpha: 0.35),
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 14,
        color: colors.onSurface.withValues(alpha: 0.2),
      ),
      onTap: () {
        Navigator.of(
          context,
        ).push(AppPageRoute(page: PlaylistDetailPage(playlist: playlist)));
      },
    );
  }
}

// ============================================================
// PLAYLIST THUMBNAIL — imagem custom → artwork → ícone
// ============================================================

class _PlaylistThumbnail extends StatelessWidget {
  const _PlaylistThumbnail({
    required this.playlist,
    this.size = 44,
    this.borderRadius,
  });
  final Playlist playlist;
  final double size;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final radius = borderRadius ?? BorderRadius.circular(AppSpacing.radiusSm);

    // 1. Imagem customizada
    if (playlist.hasCustomImage) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.file(
          File(playlist.imagePath!),
          key: ValueKey(playlist.imagePath),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallbackIcon(colors, radius),
        ),
      );
    }

    // 2. Artwork da primeira música
    if (playlist.songs.isNotEmpty) {
      return ClipRRect(
        borderRadius: radius,
        child: ArtworkImage.song(
          songId: playlist.songs.first.numericId,
          size: size,
          borderRadius: radius,
        ),
      );
    }

    // 3. Ícone fallback
    return _fallbackIcon(colors, radius);
  }

  Widget _fallbackIcon(ColorScheme colors, BorderRadius radius) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.outline.withValues(alpha: 0.12),
        borderRadius: radius,
      ),
      child: Icon(
        Icons.music_note_rounded,
        size: size * 0.5,
        color: colors.onSurface.withValues(alpha: 0.25),
      ),
    );
  }
}

// ============================================================
// USER PLAYLIST TILE — thumbnail + descrição + stats
// ============================================================
