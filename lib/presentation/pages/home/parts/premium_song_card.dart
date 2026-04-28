// ignore_for_file: curly_braces_in_flow_control_structures, unused_element_parameter
part of '../home_page.dart';

class _PremiumSongCard extends StatelessWidget {
  const _PremiumSongCard({
    required this.song,
    required this.isPlaying,
    required this.size,
    required this.analysis,
    required this.colors,
    required this.theme,
    required this.onTap,
  });
  final Song song;
  final bool isPlaying;
  final double size;
  final AudioAnalysisResult? analysis;
  final ColorScheme colors;
  final ThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    boxShadow: [
                      BoxShadow(
                        color: isPlaying
                            ? colors.primary.withValues(alpha: 0.15)
                            : Colors.black.withValues(alpha: 0.1),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ArtworkImage.song(
                    songId: song.numericId,
                    size: size,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    placeholderIcon: Icons.music_note_rounded,
                    placeholderIconSize: size * 0.33,
                  ),
                ),
                // Now playing indicator
                if (isPlaying)
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colors.primary.withValues(alpha: 0.4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.equalizer_rounded,
                        size: 12,
                        color: colors.onPrimary,
                      ),
                    ),
                  ),
                // BPM badge
                if (analysis != null && analysis!.hasBpm)
                  Positioned(
                    left: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${analysis!.bpm} BPM',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w600,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              song.title,
              style: theme.textTheme.labelMedium?.copyWith(
                color: isPlaying ? colors.primary : colors.onSurface,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    song.artist,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.4),
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (analysis != null && analysis!.hasKey) ...[
                  const SizedBox(width: 4),
                  Text(
                    '${analysis!.key}${analysis!.scale == "Minor" ? "m" : ""}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.tertiary.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w600,
                      fontSize: 9,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// LIBRARY STATS BAR — compact summary
// ============================================================

