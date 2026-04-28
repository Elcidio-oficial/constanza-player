// ignore_for_file: curly_braces_in_flow_control_structures, unused_element_parameter
part of '../now_playing_page.dart';

class _ElegantAlbumArt extends ConsumerWidget {
  const _ElegantAlbumArt({
    super.key,
    required this.colors,
    this.artColor,
    required this.songId,
  });
  final ColorScheme colors;
  final Color? artColor;
  final int songId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.sizeOf(context).width * 0.72;
    final accentGold = artColor != null
        ? HSLColor.fromColor(
            artColor!,
          ).withSaturation(0.30).withLightness(0.55).toColor()
        : const Color(0xFFBFA76A);

    return Container(
      width: size + 14,
      height: size + 14,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accentGold.withValues(alpha: 0.45),
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: accentGold.withValues(alpha: 0.18),
              width: 0.8,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: ArtworkImage.song(
                    songId: songId,
                    size: size,
                    borderRadius: BorderRadius.circular(6),
                    placeholderIconSize: 72,
                  ),
                ),
                // Inner warm highlight — gives the gold frame weight
                IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 0.6,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// WAVE ALBUM ART — square art with animated sine waves below
// ============================================================

