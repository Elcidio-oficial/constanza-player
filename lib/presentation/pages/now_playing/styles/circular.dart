// ignore_for_file: curly_braces_in_flow_control_structures, unused_element_parameter
part of '../now_playing_page.dart';

class _CircularAlbumArt extends ConsumerStatefulWidget {
  const _CircularAlbumArt({
    super.key,
    required this.colors,
    this.artColor,
    required this.songId,
    required this.isCurrentPage,
  });
  final ColorScheme colors;
  final Color? artColor;
  final int songId;
  final bool isCurrentPage;

  @override
  ConsumerState<_CircularAlbumArt> createState() => _CircularAlbumArtState();
}

class _CircularAlbumArtState extends ConsumerState<_CircularAlbumArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleCtrl;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
      lowerBound: 0.97,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context).width * 0.68;
    final isPlaying = ref.watch(playerProvider.select((s) => s.isPlaying));

    final shouldAnimate = widget.isCurrentPage && isPlaying;
    if (shouldAnimate && !_scaleCtrl.isAnimating) {
      _scaleCtrl.repeat(reverse: true);
    } else if (!shouldAnimate && _scaleCtrl.isAnimating) {
      _scaleCtrl.animateTo(1.0);
    }

    final glow = widget.artColor ?? widget.colors.primary;

    return AnimatedBuilder(
      animation: _scaleCtrl,
      builder: (_, child) =>
          Transform.scale(scale: _scaleCtrl.value, child: child),
      child: Container(
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
                songId: widget.songId,
                size: size,
                isCircle: true,
                placeholderIconSize: 80,
              ),
            ),
            // Outer accent ring (very thin, breathes with the pulse)
            IgnorePointer(
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: glow.withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                ),
              ),
            ),
            // Inner rim highlight — glass effect
            IgnorePointer(
              child: Container(
                width: size - 6,
                height: size - 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
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
    );
  }
}
