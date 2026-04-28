// ignore_for_file: curly_braces_in_flow_control_structures, unused_element_parameter
part of '../now_playing_page.dart';

class _FullBlurAlbumArt extends ConsumerWidget {
  const _FullBlurAlbumArt({
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
    final size = MediaQuery.sizeOf(context).width * 0.64;
    final glow = artColor ?? colors.primary;

    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipOval(
            child: ArtworkImage.song(
              songId: songId,
              size: size,
              isCircle: true,
              placeholderIconSize: 72,
            ),
          ),
          // Outer thin accent ring
          IgnorePointer(
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: glow.withValues(alpha: 0.55),
                  width: 1.2,
                ),
              ),
            ),
          ),
          // Inner glass rim
          IgnorePointer(
            child: Container(
              width: size - 6,
              height: size - 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
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
