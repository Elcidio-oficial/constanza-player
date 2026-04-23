import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:constanza_player/core/theme/app_spacing.dart';
import 'package:constanza_player/core/utils/app_page_route.dart';
import 'package:constanza_player/domain/entities/song.dart';
import 'package:constanza_player/presentation/pages/library/album_detail_page.dart';
import 'package:constanza_player/presentation/pages/library/song_edit_page.dart';
import 'package:constanza_player/presentation/providers/library_provider.dart';
import 'package:constanza_player/presentation/providers/player_provider.dart';
import 'package:constanza_player/presentation/providers/playlist_provider.dart';
import 'package:constanza_player/presentation/widgets/artwork_image.dart';
import 'package:constanza_player/services/media_tag_service.dart';

import 'playlist_selector_bottom_sheet.dart';
import 'artist_selector_bottom_sheet.dart';
import 'package:go_router/go_router.dart';

class SongOptionsBottomSheet extends ConsumerWidget {
  const SongOptionsBottomSheet({
    super.key,
    required this.song,
    required this.onTapPlay,
  });

  final Song song;
  final VoidCallback onTapPlay;

  static void show(BuildContext context, Song song, VoidCallback onTapPlay) {
    HapticFeedback.selectionClick();
    final colors = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      builder: (_) => SongOptionsBottomSheet(song: song, onTapPlay: onTapPlay),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
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
                  HapticFeedback.lightImpact();
                  context.pop();
                  onTapPlay();
                },
              ),
              ListTile(
                leading: const Icon(Icons.playlist_play_rounded),
                title: const Text('Tocar em seguida'),
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.pop();
                  ref.read(playerProvider.notifier).addNextInQueue(song);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Adicionado à fila'),
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
              Consumer(
                builder: (context, ref, _) {
                  final isFav =
                      ref
                          .watch(libraryProvider)
                          .songs
                          .where((s) => s.id == song.id)
                          .firstOrNull
                          ?.isFavorite ??
                      song.isFavorite;

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
                      HapticFeedback.mediumImpact();
                      ref
                          .read(libraryProvider.notifier)
                          .toggleFavorite(song.id);
                      final libSong = ref
                          .read(libraryProvider)
                          .songs
                          .where((s) => s.id == song.id)
                          .firstOrNull;
                      if (libSong != null) {
                        ref
                            .read(playerProvider.notifier)
                            .syncFavoriteFromLibrary(
                              song.id,
                              libSong.isFavorite,
                            );
                      }
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
                  HapticFeedback.lightImpact();
                  context.pop();
                  PlaylistSelectorBottomSheet.show(context, ref, song);
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_outline_rounded),
                title: const Text('Ir para Artista'),
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.pop();
                  ArtistSelectorBottomSheet.showOrNavigate(context, ref, song);
                },
              ),
              ListTile(
                leading: const Icon(Icons.album_rounded),
                title: const Text('Ir para Álbum'),
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.pop();
                  _navigateToAlbum(context, ref);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('Partilhar'),
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.pop();
                  final text =
                      '${song.title} - ${song.artist}\nÁlbum: ${song.album}';
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Info da música copiada!'),
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
              ListTile(
                leading: const Icon(Icons.edit_rounded),
                title: const Text('Editar / Detalhes'),
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.pop();
                  Navigator.push(
                    context,
                    AppPageRoute(page: SongEditPage(song: song)),
                  );
                },
              ),
              if (song.filePath.isNotEmpty)
                ListTile(
                  leading: Icon(
                    Icons.delete_forever_rounded,
                    color: colors.error,
                  ),
                  title: Text(
                    'Excluir do dispositivo',
                    style: TextStyle(color: colors.error),
                  ),
                  onTap: () => _deleteSong(context, ref),
                ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToAlbum(BuildContext context, WidgetRef ref) {
    final albums = ref.read(libraryProvider).albums;
    final album = albums
        .where((a) => a.name.toLowerCase() == song.album.toLowerCase())
        .firstOrNull;
    if (album != null) {
      Navigator.of(
        context,
      ).push(AppPageRoute(page: AlbumDetailPage(album: album)));
    }
  }

  Future<void> _deleteSong(BuildContext context, WidgetRef ref) async {
    HapticFeedback.heavyImpact();
    context.pop();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Excluir música'),
        content: Text(
          'Deseja excluir "${song.title}" do dispositivo?\n\nEssa ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => c.pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => c.pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final deleted = await MediaTagService.deleteSong(
      filePath: song.filePath,
      songId: song.numericId,
    );

    if (deleted && context.mounted) {
      ref.read(libraryProvider.notifier).removeSong(song.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Música excluída'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
