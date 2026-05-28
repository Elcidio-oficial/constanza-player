import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:constanza_player/core/theme/app_spacing.dart';
import 'package:constanza_player/domain/entities/song.dart';
import 'package:constanza_player/presentation/providers/player_provider.dart';
import 'package:constanza_player/presentation/providers/theme_provider.dart';
import 'package:constanza_player/presentation/widgets/artwork_image.dart';
import 'package:constanza_player/presentation/widgets/artist_links_text.dart';
import 'package:constanza_player/l10n/gen/app_localizations.dart';

import 'song_options_bottom_sheet.dart';

/// Tile de música na lista — respeita densidade e exibição de capa.
class SongTile extends ConsumerStatefulWidget {
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
  ConsumerState<SongTile> createState() => _SongTileState();
}

class _SongTileState extends ConsumerState<SongTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final song = widget.song;
    final onTap = widget.onTap;
    final onMoreTap = widget.onMoreTap;
    final showIndex = widget.showIndex;
    final useArtistLinks = widget.useArtistLinks;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final listDensity = ref.watch(themeProvider.select((s) => s.listDensity));
    final showArt = ref.watch(
      themeProvider.select((s) => s.showAlbumArtInList),
    );
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

    return AnimatedScale(
          scale: _pressed ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: InkWell(
            onTap: onTap,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapCancel: () => setState(() => _pressed = false),
            onTapUp: (_) => setState(() => _pressed = false),
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
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusSm,
                          ),
                        ),
                        if (isPlaying && playingState)
                          Semantics(
                            label: 'Tocando agora: ${song.title}',
                            excludeSemantics: true,
                            child: Container(
                              width: thumbSize,
                              height: thumbSize,
                              decoration: BoxDecoration(
                                color: colors.tertiary.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusSm,
                                ),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.equalizer_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
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
                            ? Semantics(
                                label: AppLocalizations.of(
                                  context,
                                ).homeListeningNow,
                                child: Icon(
                                  Icons.equalizer_rounded,
                                  color: colors.tertiary,
                                  size: 18,
                                ),
                              )
                            : Text(
                                '$showIndex',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.onSurface.withValues(
                                    alpha: 0.3,
                                  ),
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
                            color: isPlaying
                                ? colors.tertiary
                                : colors.onSurface,
                            fontWeight: isPlaying
                                ? FontWeight.w600
                                : FontWeight.w500,
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
                    onTap:
                        onMoreTap ??
                        () => SongOptionsBottomSheet.show(context, song, onTap),
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
          ),
        )
        .animate()
        .fadeIn(duration: 300.ms, curve: Curves.easeOut)
        .slideX(begin: 0.05, end: 0, duration: 300.ms, curve: Curves.easeOut);
  }
}
