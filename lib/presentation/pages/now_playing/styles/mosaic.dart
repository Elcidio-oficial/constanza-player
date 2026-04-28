// ignore_for_file: curly_braces_in_flow_control_structures, unused_element_parameter
part of '../now_playing_page.dart';

class _MosaicAlbumArt extends ConsumerWidget {
  const _MosaicAlbumArt({
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
    final totalSize = MediaQuery.sizeOf(context).width * 0.72;
    final artSize = totalSize * 0.72;
    final palette = ref.watch(artworkPaletteProvider);

    final c1 = palette?.vibrant ?? colors.primary;
    final c2 = palette?.secondary ?? colors.secondary;
    final c3 = palette?.tertiary ?? colors.tertiary;
    final blockR = BorderRadius.circular(6);

    return SizedBox(
      width: totalSize,
      height: totalSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            top: totalSize * 0.05,
            child: Container(
              width: totalSize * 0.18,
              height: totalSize * 0.30,
              decoration: BoxDecoration(
                color: c1.withValues(alpha: 0.25),
                borderRadius: blockR,
              ),
            ),
          ),
          Positioned(
            right: totalSize * 0.02,
            top: 0,
            child: Container(
              width: totalSize * 0.22,
              height: totalSize * 0.16,
              decoration: BoxDecoration(
                color: c2.withValues(alpha: 0.20),
                borderRadius: blockR,
              ),
            ),
          ),
          Positioned(
            left: totalSize * 0.04,
            bottom: totalSize * 0.02,
            child: Container(
              width: totalSize * 0.25,
              height: totalSize * 0.18,
              decoration: BoxDecoration(
                color: c3.withValues(alpha: 0.18),
                borderRadius: blockR,
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: totalSize * 0.08,
            child: Container(
              width: totalSize * 0.15,
              height: totalSize * 0.35,
              decoration: BoxDecoration(
                color: c2.withValues(alpha: 0.15),
                borderRadius: blockR,
              ),
            ),
          ),
          Positioned(
            right: totalSize * 0.20,
            top: totalSize * 0.03,
            child: Container(
              width: totalSize * 0.10,
              height: totalSize * 0.10,
              decoration: BoxDecoration(
                color: c1.withValues(alpha: 0.30),
                borderRadius: blockR,
              ),
            ),
          ),
          Container(
            width: artSize,
            height: artSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  child: ArtworkImage.song(
                    songId: songId,
                    size: artSize,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    placeholderIconSize: 72,
                  ),
                ),
                IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.10),
                        width: 0.8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SLEEP TIMER VISUAL CIRCLE
// ============================================================
