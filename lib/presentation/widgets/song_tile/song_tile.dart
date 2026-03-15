import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:constanza_player/core/theme/app_spacing.dart';
import 'package:constanza_player/domain/entities/song.dart';
import 'package:constanza_player/presentation/providers/player_provider.dart';
import 'package:constanza_player/presentation/providers/theme_provider.dart';
import 'package:constanza_player/presentation/providers/library_provider.dart';
import 'package:constanza_player/presentation/providers/playlist_provider.dart';
import 'package:constanza_player/presentation/widgets/artwork_image.dart';
import 'package:constanza_player/presentation/widgets/artist_links_text.dart';

/// Tile de música na lista — respeita densidade e exibição de capa.
class SongTile extends ConsumerWidget {
  const SongTile({
    super.key,
    required this.song,
    required this.onTap,
    this.onMoreTap,
    this.showIndex,
    this.useArtistLinks = false,
  });

  final Song song;
  final VoidCallback onTap;
  final VoidCallback? onMoreTap;
  final int? showIndex;

  /// Quando true, os nomes dos artistas no subtitle viram links tappáveis.
  final bool useArtistLinks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final listDensity = ref.watch(themeProvider.select((s) => s.listDensity));
    final showArt = ref.watch(themeProvider.select((s) => s.showAlbumArtInList));
    final isPlaying = ref.watch(
      playerProvider.select((s) => s.currentSong?.id == song.id),
    );
    final playingState = ref.watch(playerProvider.select((s) => s.isPlaying));

    // Densidade
    final verticalPad = switch (listDensity) {
      ListDensity.compact => 2.0,
      ListDensity.normal => AppSpacing.xxs,
      ListDensity.comfortable => AppSpacing.sm,
    };
    final thumbSize = switch (listDensity) {
      ListDensity.compact => 40.0,
      ListDensity.normal => 48.0,
      ListDensity.comfortable => 56.0,
    };

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: verticalPad,
        ),
        child: Row(
          children: [
            // Thumbnail ou índice
            if (showArt)
              Stack(
                children: [
                  ArtworkImage.song(
                    songId: song.numericId,
                    size: thumbSize,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  if (isPlaying && playingState)
                    Container(
                      width: thumbSize,
                      height: thumbSize,
                      decoration: BoxDecoration(
                        color: colors.tertiary.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.equalizer_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                ],
              )
            else if (showIndex != null)
              SizedBox(
                width: 32,
                child: Center(
                  child: isPlaying && playingState
                      ? Icon(
                          Icons.equalizer_rounded,
                          color: colors.tertiary,
                          size: 18,
                        )
                      : Text(
                          '$showIndex',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurface.withValues(alpha: 0.3),
                          ),
                        ),
                ),
              ),

            SizedBox(width: showArt ? AppSpacing.sm : AppSpacing.xs),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    song.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: isPlaying ? colors.tertiary : colors.onSurface,
                      fontWeight: isPlaying ? FontWeight.w600 : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  if (useArtistLinks)
                    ArtistLinksText(
                      artist: song.artist,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isPlaying
                            ? colors.tertiary.withValues(alpha: 0.7)
                            : colors.onSurface.withValues(alpha: 0.45),
                      ),
                      suffix: ' · ${song.album}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  else
                    Text(
                      '${song.artist} · ${song.album}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isPlaying
                            ? colors.tertiary.withValues(alpha: 0.7)
                            : colors.onSurface.withValues(alpha: 0.45),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),

            // Duração
            Text(
              song.durationFormatted,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.3),
              ),
            ),

            // Menu
            GestureDetector(
              onTap: onMoreTap ?? () => _showOptions(context, ref),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(left: AppSpacing.xs),
                child: Icon(
                  Icons.more_vert_rounded,
                  size: 20,
                  color: colors.onSurface.withValues(alpha: 0.3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOptions(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      builder: (ctx) => SafeArea(
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
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  ArtworkImage.song(
                    songId: song.numericId,
                    size: 48,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          style: theme.textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          song.artist,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Divider(color: colors.outline.withValues(alpha: 0.15)),
            ListTile(
              leading: const Icon(Icons.play_arrow_rounded),
              title: const Text('Reproduzir'),
              onTap: () {
                Navigator.pop(ctx);
                onTap();
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_play_rounded),
              title: const Text('Tocar em seguida'),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(playerProvider.notifier).addNextInQueue(song);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Adicionado à fila'),
                    backgroundColor: colors.onSurface,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
            StatefulBuilder(
              builder: (_, setState) {
                final isFav = ref.watch(
                  libraryProvider.select(
                    (s) =>
                        s.songs
                            .where((s) => s.id == song.id)
                            .firstOrNull
                            ?.isFavorite ??
                        song.isFavorite,
                  ),
                );
                return ListTile(
                  leading: Icon(
                    isFav
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: isFav ? colors.error : null,
                  ),
                  title: Text(
                    isFav
                        ? 'Remover dos Favoritos'
                        : 'Adicionar aos Favoritos',
                  ),
                  onTap: () {
                    ref
                        .read(libraryProvider.notifier)
                        .toggleFavorite(song.id);
                    final updatedSongs = ref.read(libraryProvider).songs;
                    ref
                        .read(playlistProvider.notifier)
                        .syncFavorites(updatedSongs);
                  },
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add_rounded),
              title: const Text('Adicionar a Playlist'),
              onTap: () {
                Navigator.pop(ctx);
                _showAddToPlaylistDialog(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('Detalhes'),
              onTap: () {
                Navigator.pop(ctx);
                _showDetails(context);
              },
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  void _showAddToPlaylistDialog(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final playlists = ref.read(userPlaylistsProvider);

    if (playlists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Crie uma playlist primeiro'),
          backgroundColor: colors.onSurface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      builder: (ctx) => SafeArea(
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
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(
                'Adicionar a Playlist',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
            Divider(
              color: colors.outline.withValues(alpha: 0.15),
              indent: AppSpacing.md,
              endIndent: AppSpacing.md,
            ),
            ...playlists.map(
              (p) => ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.outline.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Icon(
                    Icons.queue_music_rounded,
                    size: 20,
                    color: colors.onSurface.withValues(alpha: 0.4),
                  ),
                ),
                title: Text(p.name, style: theme.textTheme.titleSmall),
                subtitle: Text(
                  '${p.songCount} música${p.songCount != 1 ? 's' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.4),
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  ref
                      .read(playlistProvider.notifier)
                      .addSongToPlaylist(p.id, song);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Adicionado a "${p.name}"'),
                      backgroundColor: colors.onSurface,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusSm,
                        ),
                      ),
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
    );
  }

  void _showDetails(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        title: Text('Detalhes', style: theme.textTheme.titleMedium),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _row('Título', song.title, theme, colors),
            _row('Artista', song.artist, theme, colors),
            _row('Álbum', song.album, theme, colors),
            _row('Duração', song.durationFormatted, theme, colors),
            _row('Faixa', '${song.trackNumber}', theme, colors),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Fechar', style: TextStyle(color: colors.onSurface)),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, ThemeData theme, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
