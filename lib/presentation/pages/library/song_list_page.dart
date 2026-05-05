import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:constanza_player/core/theme/app_spacing.dart';
import 'package:constanza_player/core/utils/background_helper.dart';
import 'package:constanza_player/domain/entities/song.dart';
import 'package:constanza_player/presentation/providers/player_provider.dart';
import 'package:constanza_player/presentation/providers/theme_provider.dart';
import 'package:constanza_player/presentation/widgets/song_tile/song_tile.dart';
import 'package:constanza_player/presentation/widgets/background_wrapper.dart';
import 'package:constanza_player/l10n/gen/app_localizations.dart';

/// Página reutilizável para exibir uma lista de músicas.
/// Usada como destino de "Ver tudo" nas seções da Home.
class SongListPage extends ConsumerWidget {
  const SongListPage({super.key, required this.title, required this.songs});

  final String title;
  final List<Song> songs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final themeState = ref.watch(themeProvider);
    final l10n = AppLocalizations.of(context);

    return BackgroundWrapper(
      child: Scaffold(
        backgroundColor: BackgroundHelper.scaffoldColor(colors, themeState),
        appBar: AppBar(
          backgroundColor: BackgroundHelper.appBarColor(colors, themeState),
          title: Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w300,
            ),
          ),
          actions: [
            // Shuffle all
            IconButton(
              icon: Icon(
                Icons.shuffle_rounded,
                color: colors.onSurface.withValues(alpha: 0.5),
                size: 22,
              ),
              onPressed: songs.isEmpty
                  ? null
                  : () => ref
                        .read(playerProvider.notifier)
                        .playSong(songs.first, queue: songs, shuffle: true),
            ),
            const SizedBox(width: AppSpacing.xxs),
          ],
        ),
        body: songs.isEmpty
            ? Center(
                child: Text(
                  l10n.songListNoSongs,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.35),
                  ),
                ),
              )
            : Column(
                children: [
                  // Song count header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.md,
                      AppSpacing.xs,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.librarySongCount(songs.length),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurface.withValues(alpha: 0.35),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => ref
                              .read(playerProvider.notifier)
                              .playSong(songs.first, queue: songs),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.play_arrow_rounded,
                                size: 16,
                                color: colors.primary.withValues(alpha: 0.7),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                l10n.songListPlayAll,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colors.primary.withValues(alpha: 0.7),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    indent: AppSpacing.md,
                    endIndent: AppSpacing.md,
                    color: colors.outline.withValues(alpha: 0.1),
                  ),
                  // Song list
                  Expanded(
                    child: ListView.builder(
                      itemCount: songs.length,
                      padding: const EdgeInsets.only(bottom: 100),
                      itemBuilder: (context, index) {
                        final song = songs[index];
                        return SongTile(
                          song: song,
                          onTap: () => ref
                              .read(playerProvider.notifier)
                              .playSong(song, queue: songs),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
