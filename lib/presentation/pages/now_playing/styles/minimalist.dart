// ignore_for_file: curly_braces_in_flow_control_structures, unused_element_parameter
part of '../now_playing_page.dart';

class _MinimalistAlbumArt extends ConsumerWidget {
  const _MinimalistAlbumArt({
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
    final size = MediaQuery.sizeOf(context).width * 0.70;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ArtworkImage.song(
            songId: songId,
            size: size,
            borderRadius: BorderRadius.zero,
            placeholderIconSize: 72,
          ),
          // Hairline border — understated frame
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.10),
                  width: 0.8,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// AURORA ALBUM ART — circle + animated aurora gradient behind
// ============================================================

