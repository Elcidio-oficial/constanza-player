// ignore_for_file: curly_braces_in_flow_control_structures, unused_element_parameter
part of '../now_playing_page.dart';

class _VinylAlbumArt extends ConsumerStatefulWidget {
  const _VinylAlbumArt({
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
  ConsumerState<_VinylAlbumArt> createState() => _VinylAlbumArtState();
}

class _VinylAlbumArtState extends ConsumerState<_VinylAlbumArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotCtrl;
  ProviderSubscription<bool>? _playSub;

  @override
  void initState() {
    super.initState();
    _rotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    // Escuta isPlaying fora do build — chamar repeat/stop dentro de build()
    // causa reentrância e "setState during build" em skip rápido.
    _playSub = ref.listenManual<bool>(
      playerProvider.select((s) => s.isPlaying),
      (prev, next) => _syncAnimation(next),
      fireImmediately: true,
    );
  }

  @override
  void didUpdateWidget(covariant _VinylAlbumArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isCurrentPage != widget.isCurrentPage) {
      _syncAnimation(ref.read(playerProvider).isPlaying);
    }
  }

  void _syncAnimation(bool isPlaying) {
    final shouldAnimate = widget.isCurrentPage && isPlaying;
    if (shouldAnimate && !_rotCtrl.isAnimating) {
      _rotCtrl.repeat();
    } else if (!shouldAnimate && _rotCtrl.isAnimating) {
      _rotCtrl.stop();
    }
  }

  @override
  void dispose() {
    _playSub?.close();
    _rotCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context).width * 0.66;
    final artSize = size * 0.38;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _rotCtrl,
        builder: (_, child) =>
            Transform.rotate(angle: _rotCtrl.value * 6.28318, child: child),
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _VinylPainter(accentColor: widget.artColor),
            child: Center(
              child: SizedBox(
                width: artSize,
                height: artSize,
                child: ClipOval(
                  child: ArtworkImage.song(
                    songId: widget.songId,
                    size: artSize,
                    isCircle: true,
                    placeholderIconSize: 36,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VinylPainter extends CustomPainter {
  const _VinylPainter({this.accentColor});
  final Color? accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;
    final accent = accentColor ?? const Color(0xFF6C63FF);

    // Main disc
    canvas.drawCircle(center, maxR, Paint()..color = const Color(0xFF181818));

    // Concentric grooves — colored with accent tint
    for (int i = 1; i <= 14; i++) {
      final r = maxR * (0.22 + i * 0.048);
      if (r >= maxR * 0.97) break;
      final isAccentGroove = i % 3 == 0;
      final groovePaint = Paint()
        ..color = isAccentGroove
            ? accent.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isAccentGroove ? 1.0 : 0.8;
      canvas.drawCircle(center, r, groovePaint);
    }

    // Slight reflection sheen (top-left arc)
    final sheenPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.5, -0.5),
        radius: 1.0,
        colors: [Colors.white.withValues(alpha: 0.06), Colors.transparent],
      ).createShader(Rect.fromCircle(center: center, radius: maxR));
    canvas.drawCircle(center, maxR, sheenPaint);

    // Label circle — tinted with accent color
    final labelPaint = Paint()
      ..color = Color.lerp(const Color(0xFF252525), accent, 0.15)!;
    canvas.drawCircle(center, maxR * 0.23, labelPaint);

    // Center hole
    canvas.drawCircle(
      center,
      maxR * 0.025,
      Paint()..color = const Color(0xFF0D0D0D),
    );
  }

  @override
  bool shouldRepaint(_VinylPainter old) => old.accentColor != accentColor;
}

// ── Gradient track shape for MediaBarStyle.gradient ───────────
