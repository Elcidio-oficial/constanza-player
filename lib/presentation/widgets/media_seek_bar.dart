import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:constanza_player/presentation/providers/theme_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
// MEDIA SEEK BAR — reusable progress/seek bar shared by Now Playing & Car Mode.
//
// Renders any [MediaBarStyle]:
//   • Simple slider family (minimal, glow, gradient, thick, classic) → styled
//     Material [Slider].
//   • Visualizer family (waveform, frequencyBars, bars, equalizer, steps,
//     segments, pulse, sineWave, wave, mirror, dots, dense) → interactive
//     [CustomPaint] with tap/drag seeking, deterministic per-song shapes and a
//     subtle living animation. Each visualizer mirrors one of the reference
//     audio-wave designs.
//
// All colours are passed in so the bar adapts to the artwork palette in Now
// Playing and to the accent colour in Car Mode.
// ════════════════════════════════════════════════════════════════════════════

class MediaSeekBar extends StatefulWidget {
  const MediaSeekBar({
    super.key,
    required this.progress,
    required this.style,
    required this.seed,
    required this.activeColor,
    required this.inactiveColor,
    required this.onSeek,
    this.neutralColor,
    this.secondaryColor,
    this.tertiaryColor,
    this.thumbColor = Colors.white,
    this.height = 44,
  });

  /// Playback progress in [0, 1].
  final double progress;
  final MediaBarStyle style;

  /// Deterministic seed (typically `songId.hashCode`) so each song keeps a
  /// stable shape across rebuilds.
  final int seed;

  final Color activeColor;
  final Color inactiveColor;

  /// Neutral colour used by the `minimal` slider track. Defaults to
  /// [activeColor] when not provided.
  final Color? neutralColor;

  /// Gradient stops for played visualizer pixels / the gradient slider.
  /// Default to [activeColor] (solid) when omitted.
  final Color? secondaryColor;
  final Color? tertiaryColor;

  final Color thumbColor;
  final double height;

  /// Called with a fraction in [0, 1] when the user seeks.
  final ValueChanged<double> onSeek;

  bool get _isVisualizer => switch (style) {
    MediaBarStyle.minimal ||
    MediaBarStyle.glow ||
    MediaBarStyle.gradient ||
    MediaBarStyle.thick ||
    MediaBarStyle.classic => false,
    _ => true,
  };

  @override
  State<MediaSeekBar> createState() => _MediaSeekBarState();
}

class _MediaSeekBarState extends State<MediaSeekBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late List<double> _bars;
  double? _dragFraction;

  @override
  void initState() {
    super.initState();
    _bars = _generateBars(widget.seed);
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant MediaSeekBar old) {
    super.didUpdateWidget(old);
    if (old.seed != widget.seed) _bars = _generateBars(widget.seed);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  // Smoothed deterministic amplitudes (~0.2 .. 1.0). A neutral source that each
  // visualizer reshapes with its own envelope.
  List<double> _generateBars(int seed) {
    final rnd = math.Random(seed == 0 ? 1 : seed);
    const res = 96;
    final raw = List<double>.generate(res, (_) => rnd.nextDouble());
    return List<double>.generate(res, (i) {
      var sum = 0.0;
      var count = 0;
      for (var k = -1; k <= 1; k++) {
        final j = i + k;
        if (j >= 0 && j < res) {
          sum += raw[j];
          count++;
        }
      }
      return 0.2 + 0.8 * (sum / count);
    });
  }

  void _handle(double dx, double width, {bool commit = false}) {
    final f = (dx / width).clamp(0.0, 1.0);
    setState(() => _dragFraction = commit ? null : f);
    if (commit) widget.onSeek(f);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget._isVisualizer) return _buildSlider(context);

    final fraction = _dragFraction ?? widget.progress.clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _handle(d.localPosition.dx, width, commit: true),
          onHorizontalDragStart: (d) => _handle(d.localPosition.dx, width),
          onHorizontalDragUpdate: (d) => _handle(d.localPosition.dx, width),
          onHorizontalDragEnd: (_) {
            if (_dragFraction != null) widget.onSeek(_dragFraction!);
            setState(() => _dragFraction = null);
          },
          child: SizedBox(
            height: widget.height,
            width: double.infinity,
            child: AnimatedBuilder(
              animation: _anim,
              builder: (context, _) => CustomPaint(
                painter: _MediaBarPainter(
                  style: widget.style,
                  bars: _bars,
                  progress: fraction,
                  phase: _anim.value,
                  dragging: _dragFraction != null,
                  activeColor: widget.activeColor,
                  inactiveColor: widget.inactiveColor,
                  secondaryColor: widget.secondaryColor ?? widget.activeColor,
                  tertiaryColor: widget.tertiaryColor ?? widget.activeColor,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Simple slider family ───────────────────────────────────────────────────
  Widget _buildSlider(BuildContext context) {
    final neutral = widget.neutralColor ?? widget.activeColor;
    final base = SliderTheme.of(context);
    final data = switch (widget.style) {
      MediaBarStyle.minimal => base.copyWith(
        trackHeight: 2.0,
        thumbShape: SliderComponentShape.noThumb,
        overlayShape: SliderComponentShape.noOverlay,
        activeTrackColor: neutral.withValues(alpha: 0.8),
        inactiveTrackColor: neutral.withValues(alpha: 0.10),
      ),
      MediaBarStyle.glow => base.copyWith(
        trackHeight: 3.5,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
        activeTrackColor: widget.activeColor,
        inactiveTrackColor: widget.activeColor.withValues(alpha: 0.15),
        thumbColor: widget.thumbColor,
        overlayColor: widget.activeColor.withValues(alpha: 0.35),
      ),
      MediaBarStyle.gradient => base.copyWith(
        trackHeight: 4.5,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
        activeTrackColor: widget.activeColor,
        inactiveTrackColor: neutral.withValues(alpha: 0.10),
        thumbColor: widget.thumbColor,
        trackShape: MediaGradientSliderTrackShape(
          gradientColors: [
            widget.activeColor,
            widget.secondaryColor ?? widget.activeColor,
            widget.tertiaryColor ?? widget.activeColor,
          ],
        ),
      ),
      MediaBarStyle.thick => base.copyWith(
        trackHeight: 10,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 22),
        activeTrackColor: widget.activeColor,
        inactiveTrackColor: neutral.withValues(alpha: 0.12),
        thumbColor: widget.thumbColor,
      ),
      MediaBarStyle.classic => base.copyWith(
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
        activeTrackColor: Colors.white,
        inactiveTrackColor: Colors.white.withValues(alpha: 0.20),
        thumbColor: Colors.white,
      ),
      _ => base,
    };

    return SliderTheme(
      data: data,
      child: Slider(
        value: widget.progress.clamp(0.0, 1.0),
        onChanged: widget.onSeek,
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// PAINTER — one switch, one design per reference image.
// ════════════════════════════════════════════════════════════════════════════

class _MediaBarPainter extends CustomPainter {
  _MediaBarPainter({
    required this.style,
    required this.bars,
    required this.progress,
    required this.phase,
    required this.dragging,
    required this.activeColor,
    required this.inactiveColor,
    required this.secondaryColor,
    required this.tertiaryColor,
  });

  final MediaBarStyle style;
  final List<double> bars;
  final double progress;
  final double phase;
  final bool dragging;
  final Color activeColor;
  final Color inactiveColor;
  final Color secondaryColor;
  final Color tertiaryColor;

  // Amplitude sampled from the smoothed source at fractional position [i/n].
  double _amp(int i, int n) {
    if (bars.isEmpty) return 0.5;
    final p = n <= 1 ? 0.0 : i / (n - 1);
    final idx = (p * (bars.length - 1)).round().clamp(0, bars.length - 1);
    return bars[idx];
  }

  // Horizontal gradient colour for played pixels.
  Color _played(double t) {
    final tt = t.clamp(0.0, 1.0);
    return tt <= 0.5
        ? Color.lerp(activeColor, secondaryColor, tt * 2)!
        : Color.lerp(secondaryColor, tertiaryColor, (tt - 0.5) * 2)!;
  }

  ui.Shader _playedShader(double width) => ui.Gradient.linear(
    Offset.zero,
    Offset(width, 0),
    [activeColor, secondaryColor, tertiaryColor],
    const [0.0, 0.5, 1.0],
  );

  @override
  void paint(Canvas canvas, Size size) {
    switch (style) {
      case MediaBarStyle.waveform:
        _bars(canvas, size, n: 46, gap: 0.42, envelope: true, wobble: true);
      case MediaBarStyle.frequencyBars:
        _bars(canvas, size, n: 64, gap: 0.55, envelope: true, wobble: true);
      case MediaBarStyle.dense:
        _bars(canvas, size, n: 104, gap: 0.30, envelope: false, wobble: false);
      case MediaBarStyle.bars:
        _columnBars(canvas, size, n: 30, quantize: 0);
      case MediaBarStyle.steps:
        _columnBars(canvas, size, n: 26, quantize: 6);
      case MediaBarStyle.equalizer:
        _ledEqualizer(canvas, size);
      case MediaBarStyle.segments:
        _segments(canvas, size);
      case MediaBarStyle.dots:
        _dotMatrix(canvas, size);
      case MediaBarStyle.pulse:
        _line(canvas, size, _ecgPoints(size));
      case MediaBarStyle.sineWave:
        _line(canvas, size, _sinePoints(size, beats: 3.2, amp: 0.62));
      case MediaBarStyle.wave:
        _line(canvas, size, _sinePoints(size, beats: 1.6, amp: 0.72),
            stroke: 4.0);
      case MediaBarStyle.mirror:
        _mirror(canvas, size);
      // Slider styles never reach the painter.
      default:
        break;
    }
    _playhead(canvas, size);
  }

  // ── Centered rounded-bar families (waveform / frequencyBars / dense) ────────
  void _bars(
    Canvas canvas,
    Size size, {
    required int n,
    required double gap,
    required bool envelope,
    required bool wobble,
  }) {
    final slot = size.width / n;
    final barW = slot * (1 - gap);
    final cy = size.height / 2;
    final maxH = size.height * 0.92;
    final radius = Radius.circular(barW / 2);
    final played = progress * n;
    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < n; i++) {
      final isPlayed = i < played;
      final env = envelope
          ? 0.45 + 0.55 * math.sin((i / (n - 1)) * math.pi)
          : 1.0;
      final wob = (wobble && isPlayed)
          ? 1 + 0.10 * math.sin(phase * 2 * math.pi + i * 0.55)
          : 1.0;
      final h = (_amp(i, n) * maxH * env * wob).clamp(barW, maxH);
      final x = i * slot + (slot - barW) / 2;
      paint.color = isPlayed ? _played(i / (n - 1)) : inactiveColor;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, cy - h / 2, barW, h),
          radius,
        ),
        paint,
      );
    }
  }

  // ── Bottom-anchored bar chart / stair steps ─────────────────────────────────
  void _columnBars(Canvas canvas, Size size, {required int n, required int quantize}) {
    final slot = size.width / n;
    final barW = slot * 0.6;
    final maxH = size.height * 0.96;
    final bottom = size.height * 0.96;
    final radius = Radius.circular(barW * 0.35);
    final played = progress * n;
    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < n; i++) {
      final isPlayed = i < played;
      var a = _amp(i, n);
      if (quantize > 0) a = (((a * quantize).round()) / quantize).clamp(0.16, 1.0);
      final wob = isPlayed ? 1 + 0.06 * math.sin(phase * 2 * math.pi + i) : 1.0;
      final h = (a * maxH * wob).clamp(barW, maxH);
      final x = i * slot + (slot - barW) / 2;
      paint.color = isPlayed ? _played(i / (n - 1)) : inactiveColor;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, bottom - h, barW, h),
          radius,
        ),
        paint,
      );
    }
  }

  // ── LED column equalizer (stacked segments) ─────────────────────────────────
  void _ledEqualizer(Canvas canvas, Size size) {
    const n = 22;
    final slot = size.width / n;
    final barW = slot * 0.62;
    final maxH = size.height * 0.96;
    final bottom = size.height * 0.98;
    const segGap = 2.2;
    final segH = (size.height / 7).clamp(3.0, 7.0);
    final unit = segH + segGap;
    final radius = Radius.circular(barW * 0.3);
    final played = progress * n;
    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < n; i++) {
      final isPlayed = i < played;
      final wob = isPlayed ? 1 + 0.08 * math.sin(phase * 2 * math.pi + i) : 1.0;
      final h = (_amp(i, n) * maxH * wob).clamp(unit, maxH);
      final segs = (h / unit).ceil();
      final x = i * slot + (slot - barW) / 2;
      for (var s = 0; s < segs; s++) {
        final top = bottom - (s + 1) * unit + segGap;
        final t = i / (n - 1);
        paint.color = isPlayed
            ? _played(t).withValues(alpha: 0.55 + 0.45 * (s / segs))
            : inactiveColor;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, top, barW, segH),
            radius,
          ),
          paint,
        );
      }
    }
  }

  // ── Chunky segmented LED progress ────────────────────────────────────────────
  void _segments(Canvas canvas, Size size) {
    const n = 28;
    final slot = size.width / n;
    final segW = slot * 0.74;
    final cy = size.height / 2;
    final played = progress * n;
    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < n; i++) {
      final isPlayed = i < played;
      final h = (size.height * (0.40 + 0.45 * _amp(i, n))).clamp(6.0, size.height);
      final x = i * slot + (slot - segW) / 2;
      paint.color = isPlayed ? _played(i / (n - 1)) : inactiveColor;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, cy - h / 2, segW, h),
          Radius.circular(segW * 0.28),
        ),
        paint,
      );
    }
  }

  // ── Halftone dot matrix ──────────────────────────────────────────────────────
  void _dotMatrix(Canvas canvas, Size size) {
    const cols = 30;
    const rows = 7;
    final cellW = size.width / cols;
    final rowGap = size.height / rows;
    final cy = size.height / 2;
    final maxR = math.min(cellW, rowGap) * 0.46;
    final played = progress * cols;
    final paint = Paint()..style = PaintingStyle.fill;

    for (var c = 0; c < cols; c++) {
      final isPlayed = c < played;
      final amp = _amp(c, cols);
      final cx = c * cellW + cellW / 2;
      for (var r = 0; r < rows; r++) {
        final ry = (r + 0.5) * rowGap;
        // Diamond falloff: bigger near the centre line.
        final vfactor = 1 - (ry - cy).abs() / (size.height / 2);
        final radius = (maxR * amp * vfactor).clamp(0.0, maxR);
        if (radius < 0.4) continue;
        paint.color = isPlayed ? _played(c / (cols - 1)) : inactiveColor;
        canvas.drawCircle(Offset(cx, ry), radius, paint);
      }
    }
  }

  // ── Line families (pulse / sineWave / wave) ──────────────────────────────────
  void _line(Canvas canvas, Size size, List<Offset> pts, {double stroke = 2.6}) {
    if (pts.length < 2) return;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    final headX = (progress * size.width).clamp(0.0, size.width);

    final playedPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = _playedShader(size.width);
    final inactivePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = inactiveColor;

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(headX, 0, size.width - headX, size.height));
    canvas.drawPath(path, inactivePaint);
    canvas.restore();

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, headX, size.height));
    canvas.drawPath(path, playedPaint);
    canvas.restore();
  }

  List<Offset> _sinePoints(Size size, {required double beats, required double amp}) {
    final cy = size.height / 2;
    final maxA = size.height / 2 * amp;
    const step = 3.0;
    final pts = <Offset>[];
    for (double x = 0; x <= size.width; x += step) {
      final t = x / size.width;
      // Beating envelope so amplitude swells/relaxes across the width.
      final env = 0.45 + 0.55 * (0.5 + 0.5 * math.sin(t * math.pi * 2 - math.pi / 2));
      final y = cy +
          math.sin(t * math.pi * 2 * beats + phase * 2 * math.pi) * maxA * env;
      pts.add(Offset(x, y));
    }
    return pts;
  }

  List<Offset> _ecgPoints(Size size) {
    final cy = size.height / 2;
    final maxA = size.height / 2 * 0.82;
    const step = 2.0;
    const beatW = 120.0; // pixels per heartbeat
    final pts = <Offset>[];
    for (double x = 0; x <= size.width; x += step) {
      final local = (x % beatW) / beatW; // 0..1 within a beat
      pts.add(Offset(x, cy - _ecg(local) * maxA));
    }
    return pts;
  }

  // Stylised single-lead ECG amplitude in [-1, 1].
  double _ecg(double t) {
    double bump(double c, double w, double h) {
      final d = (t - c) / w;
      return h * math.exp(-d * d);
    }

    var y = 0.0;
    y += bump(0.20, 0.030, 0.18); // P wave
    y -= bump(0.355, 0.012, 0.22); // Q
    y += bump(0.40, 0.012, 1.0); // R spike
    y -= bump(0.45, 0.016, 0.34); // S
    y += bump(0.66, 0.055, 0.30); // T wave
    return y.clamp(-1.0, 1.0);
  }

  // ── Symmetric mirrored filled waveform ───────────────────────────────────────
  void _mirror(Canvas canvas, Size size) {
    const n = 72;
    final cy = size.height / 2;
    final maxA = size.height / 2 * 0.94;
    final dx = size.width / (n - 1);

    final top = <Offset>[];
    final bottom = <Offset>[];
    for (var i = 0; i < n; i++) {
      final x = i * dx;
      final env = 0.35 + 0.65 * math.sin((i / (n - 1)) * math.pi);
      final a = (_amp(i, n) * maxA * env).clamp(1.5, maxA);
      top.add(Offset(x, cy - a));
      bottom.add(Offset(x, cy + a));
    }

    final path = Path()..moveTo(top.first.dx, top.first.dy);
    for (final p in top.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    for (final p in bottom.reversed) {
      path.lineTo(p.dx, p.dy);
    }
    path.close();

    final headX = (progress * size.width).clamp(0.0, size.width);

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(headX, 0, size.width - headX, size.height));
    canvas.drawPath(path, Paint()..color = inactiveColor);
    canvas.restore();

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, headX, size.height));
    canvas.drawPath(path, Paint()..shader = _playedShader(size.width));
    canvas.restore();
  }

  // ── Shared playhead ──────────────────────────────────────────────────────────
  void _playhead(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final headX = (progress * size.width).clamp(0.0, size.width);
    canvas.drawCircle(
      Offset(headX, cy),
      dragging ? 4.5 : 3,
      Paint()
        ..color = activeColor.withValues(alpha: dragging ? 0.9 : 0.55)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, dragging ? 4 : 2.5),
    );
    canvas.drawCircle(
      Offset(headX, cy),
      dragging ? 3.5 : 2.5,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _MediaBarPainter old) =>
      old.style != style ||
      old.progress != progress ||
      old.phase != phase ||
      old.dragging != dragging ||
      old.activeColor != activeColor ||
      old.inactiveColor != inactiveColor ||
      !identical(old.bars, bars);
}

// ════════════════════════════════════════════════════════════════════════════
// Gradient slider track (used by MediaBarStyle.gradient).
// ════════════════════════════════════════════════════════════════════════════

class MediaGradientSliderTrackShape extends SliderTrackShape
    with BaseSliderTrackShape {
  const MediaGradientSliderTrackShape({required this.gradientColors});
  final List<Color> gradientColors;

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    final trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final double h = sliderTheme.trackHeight ?? 4;
    final radius = Radius.circular(h / 2);
    final activeRect = Rect.fromLTRB(
      trackRect.left,
      trackRect.top - additionalActiveTrackHeight / 2,
      thumbCenter.dx,
      trackRect.bottom + additionalActiveTrackHeight / 2,
    );
    final inactiveRect = Rect.fromLTRB(
      thumbCenter.dx,
      trackRect.top,
      trackRect.right,
      trackRect.bottom,
    );
    final activePaint = Paint()
      ..shader = LinearGradient(colors: gradientColors).createShader(trackRect);
    final inactivePaint = Paint()
      ..color = sliderTheme.inactiveTrackColor ?? Colors.white24;
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(activeRect, radius),
      activePaint,
    );
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(inactiveRect, radius),
      inactivePaint,
    );
  }
}
