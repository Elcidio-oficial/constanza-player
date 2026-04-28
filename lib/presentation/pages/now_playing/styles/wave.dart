// ignore_for_file: curly_braces_in_flow_control_structures, unused_element_parameter
part of '../now_playing_page.dart';

class _WaveAlbumArt extends ConsumerStatefulWidget {
  const _WaveAlbumArt({
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
  ConsumerState<_WaveAlbumArt> createState() => _WaveAlbumArtState();
}

class _WaveAlbumArtState extends ConsumerState<_WaveAlbumArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveCtrl;

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    if (widget.isCurrentPage) {
      _waveCtrl.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _WaveAlbumArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCurrentPage && !_waveCtrl.isAnimating) {
      _waveCtrl.repeat();
    } else if (!widget.isCurrentPage && _waveCtrl.isAnimating) {
      _waveCtrl.stop();
    }
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final artSize = MediaQuery.sizeOf(context).width * 0.70;
    final isPlaying = ref.watch(playerProvider.select((s) => s.isPlaying));
    final palette = ref.watch(artworkPaletteProvider);
    final waveColor = palette?.vibrant ?? widget.colors.primary;

    return SizedBox(
      width: artSize,
      height: artSize + 28,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: artSize,
            height: artSize - 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  child: ArtworkImage.song(
                    songId: widget.songId,
                    size: artSize,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    placeholderIconSize: 72,
                  ),
                ),
                IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusMd,
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 0.8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _waveCtrl,
              builder: (_, __) => CustomPaint(
                size: Size(artSize, 24),
                painter: _WavePainter(
                  phase: _waveCtrl.value,
                  color: waveColor,
                  isPlaying: isPlaying,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.phase,
    required this.color,
    required this.isPlaying,
  });
  final double phase;
  final Color color;
  final bool isPlaying;

  @override
  void paint(Canvas canvas, Size size) {
    final amp = isPlaying ? 8.0 : 3.0;
    final cy = size.height / 2;

    for (int w = 0; w < 3; w++) {
      final path = Path();
      final alpha = (0.35 - w * 0.10).clamp(0.08, 0.35);
      final freq = 2.0 + w * 0.8;
      final phaseOff = phase * 2 * 3.14159 + w * 1.2;
      final wAmp = amp * (1.0 - w * 0.25);

      path.moveTo(0, cy);
      for (double x = 0; x <= size.width; x += 2) {
        final y =
            cy + wAmp * _sin((x / size.width) * freq * 3.14159 * 2 + phaseOff);
        path.lineTo(x, y);
      }

      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 - w * 0.5
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  static double _sin(double x) {
    // Fast sin approximation
    x = x % (2 * 3.14159);
    if (x < 0) x += 2 * 3.14159;
    if (x > 3.14159) return -_sinHalf(x - 3.14159);
    return _sinHalf(x);
  }

  static double _sinHalf(double x) {
    // Parabolic approximation of sin(x) for x in [0, pi]
    final y = 4 * x * (3.14159 - x) / (3.14159 * 3.14159);
    return y * (0.775 + 0.225 * y);
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.phase != phase || old.color != color || old.isPlaying != isPlaying;
}

// ============================================================
// MOSAIC ALBUM ART — art with asymmetric color blocks
// ============================================================

