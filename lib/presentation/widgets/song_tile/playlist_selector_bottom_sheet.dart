import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:constanza_player/core/theme/app_spacing.dart';
import 'package:constanza_player/domain/entities/song.dart';
import 'package:constanza_player/presentation/providers/playlist_provider.dart';
import 'package:go_router/go_router.dart';

class PlaylistSelectorBottomSheet extends ConsumerWidget {
  const PlaylistSelectorBottomSheet({super.key, required this.song});

  final Song song;

  static void show(BuildContext context, WidgetRef ref, Song song) {
    HapticFeedback.selectionClick();
    final colors = Theme.of(context).colorScheme;
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
      isScrollControlled: true,
      backgroundColor: colors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      builder: (_) => PlaylistSelectorBottomSheet(song: song),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final playlists = ref.watch(userPlaylistsProvider);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.6,
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
                    HapticFeedback.lightImpact();
                    context.pop();
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
      ),
    );
  }
}
