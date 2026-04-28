// ignore_for_file: curly_braces_in_flow_control_structures, unused_element_parameter
part of '../now_playing_page.dart';

class _AuroraAlbumArt extends ConsumerStatefulWidget {
  const _AuroraAlbumArt({
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
  ConsumerState<_AuroraAlbumArt> createState() => _AuroraAlbumArtState();
}

class _AuroraAlbumArtState extends ConsumerState<_AuroraAlbumArt>
    with TickerProviderStateMixin {
  late final AnimationController _auroraCtrl1;
  late final AnimationController _auroraCtrl2;

  @override
  void initState() {
    super.initState();
    _auroraCtrl1 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );
    _auroraCtrl2 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    );
    if (widget.isCurrentPage) {
      _auroraCtrl1.repeat(reverse: true);
      _auroraCtrl2.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _AuroraAlbumArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCurrentPage && !_auroraCtrl1.isAnimating) {
      _auroraCtrl1.repeat(reverse: true);
      _auroraCtrl2.repeat(reverse: true);
    } else if (!widget.isCurrentPage && _auroraCtrl1.isAnimating) {
      _auroraCtrl1.stop();
      _auroraCtrl2.stop();
    }
  }

  @override
  void dispose() {
    _auroraCtrl1.dispose();
    _auroraCtrl2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final artSize = MediaQuery.sizeOf(context).width * 0.65;
    final palette = ref.watch(artworkPaletteProvider);
    final c1 = palette?.vibrant ?? widget.colors.primary;
    final c2 = palette?.secondary ?? widget.colors.secondary;
    final c3 = palette?.tertiary ?? widget.colors.tertiary;

    return SizedBox(
      width: artSize + 40,
      height: artSize + 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: Listenable.merge([_auroraCtrl1, _auroraCtrl2]),
              builder: (_, __) => CustomPaint(
                size: Size(artSize + 40, artSize + 40),
                painter: _AuroraPainter(
                  t1: _auroraCtrl1.value,
                  t2: _auroraCtrl2.value,
                  c1: c1,
                  c2: c2,
                  c3: c3,
                ),
              ),
            ),
          ),
          SizedBox(
            width: artSize,
            height: artSize,
            child: ClipOval(
              child: ArtworkImage.song(
                songId: widget.songId,
                size: artSize,
                isCircle: true,
                placeholderIconSize: 72,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter({
    required this.t1,
    required this.t2,
    required this.c1,
    required this.c2,
    required this.c3,
  });
  final double t1, t2;
  final Color c1, c2, c3;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.55;

    // Blob 1 — moves in elliptical path
    final x1 = cx + r * 0.3 * (t1 * 2 - 1);
    final y1 = cy - r * 0.4 * t1;
    canvas.drawCircle(
      Offset(x1, y1),
      r * 0.6,
      Paint()
        ..shader = RadialGradient(
          colors: [c1.withValues(alpha: 0.50), c1.withValues(alpha: 0.0)],
        ).createShader(Rect.fromCircle(center: Offset(x1, y1), radius: r * 0.6))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
    );

    // Blob 2
    final x2 = cx - r * 0.35 * (t2 * 2 - 1);
    final y2 = cy + r * 0.3 * t2;
    canvas.drawCircle(
      Offset(x2, y2),
      r * 0.55,
      Paint()
        ..shader =
            RadialGradient(
              colors: [c2.withValues(alpha: 0.45), c2.withValues(alpha: 0.0)],
            ).createShader(
              Rect.fromCircle(center: Offset(x2, y2), radius: r * 0.55),
            )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );

    // Blob 3
    final x3 = cx + r * 0.2 * t1;
    final y3 = cy + r * 0.25 * (1 - t2);
    canvas.drawCircle(
      Offset(x3, y3),
      r * 0.45,
      Paint()
        ..shader =
            RadialGradient(
              colors: [c3.withValues(alpha: 0.35), c3.withValues(alpha: 0.0)],
            ).createShader(
              Rect.fromCircle(center: Offset(x3, y3), radius: r * 0.45),
            )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );
  }

  @override
  bool shouldRepaint(_AuroraPainter old) =>
      old.t1 != t1 ||
      old.t2 != t2 ||
      old.c1 != c1 ||
      old.c2 != c2 ||
      old.c3 != c3;
}

// ============================================================
// ELEGANT ALBUM ART — double border, warm shadow, refined
// ============================================================

