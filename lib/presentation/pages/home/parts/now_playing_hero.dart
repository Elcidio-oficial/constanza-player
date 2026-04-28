// ignore_for_file: curly_braces_in_flow_control_structures, unused_element_parameter
part of '../home_page.dart';

class _NowPlayingHero extends StatelessWidget {
  const _NowPlayingHero({
    required this.song,
    required this.isPlaying,
    required this.progress,
    required this.colors,
    required this.theme,
    required this.onTap,
    required this.onPlayPause,
  });

  final Song song;
  final bool isPlaying;
  final double progress;
  final ColorScheme colors;
  final ThemeData theme;
  final VoidCallback onTap;
  final VoidCallback onPlayPause;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.primary.withValues(alpha: 0.15),
                colors.primaryContainer.withValues(alpha: 0.08),
                colors.surface.withValues(alpha: 0.4),
              ],
            ),
            border: Border.all(color: colors.primary.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMd,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colors.primary.withValues(alpha: 0.2),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ArtworkImage.song(
                        songId: song.numericId,
                        size: 64,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMd,
                        ),
                        placeholderIcon: Icons.music_note_rounded,
                        placeholderIconSize: 28,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (isPlaying)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: _PulsingDot(color: colors.primary),
                                ),
                              Expanded(
                                child: Text(
                                  isPlaying ? 'Tocando agora' : 'Pausado',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colors.primary.withValues(
                                      alpha: 0.7,
                                    ),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 10,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            song.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: colors.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            song.artist,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurface.withValues(alpha: 0.5),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    GestureDetector(
                      onTap: onPlayPause,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: colors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: colors.primary.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: colors.onPrimary,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(AppSpacing.radiusLg),
                  bottomRight: Radius.circular(AppSpacing.radiusLg),
                ),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 3,
                  backgroundColor: colors.onSurface.withValues(alpha: 0.06),
                  valueColor: AlwaysStoppedAnimation(
                    colors.primary.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// PREMIUM SONG CARD — with BPM/Key badge
// ============================================================
