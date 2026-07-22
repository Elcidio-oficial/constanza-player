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
      // Levemente mais lento — sensação de 33 RPM em vez de 78 RPM nervoso.
      duration: const Duration(seconds: 6),
    );
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
    final accent = widget.artColor ?? const Color(0xFF7C6AF7);

    // LayoutBuilder garante que o disco usa o MENOR entre largura e altura
    // disponíveis — sem cortar nas bordas como no tamanho fixo screenW * 0.66.
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxSide = constraints.biggest.shortestSide;
        // Margem interna pequena para não tocar nas bordas do PageView item.
        final size = (maxSide - 8).clamp(120.0, double.infinity);
        // Label central — área onde a capa aparece. ~38% do diâmetro
        // (proporção real de um vinil 7" / 12").
        final labelSize = size * 0.38;

        return RepaintBoundary(
          child: Center(
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // ── Disco rotativo: sulcos + reflexo + label ──
                  AnimatedBuilder(
                    animation: _rotCtrl,
                    builder: (_, child) => Transform.rotate(
                      angle: _rotCtrl.value * 6.28318,
                      child: child,
                    ),
                    child: SizedBox(
                      width: size,
                      height: size,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Pintura do vinil (disco + sulcos + label vazio)
                          CustomPaint(
                            size: Size.square(size),
                            painter: _VinylPainter(accentColor: accent),
                          ),
                          // Capa real dentro do label, recortada em círculo.
                          // Fica DENTRO do Transform.rotate — gira junto.
                          ClipOval(
                            child: SizedBox(
                              width: labelSize,
                              height: labelSize,
                              child: ArtworkImage.song(
                                songId: widget.songId,
                                size: labelSize,
                                isCircle: true,
                                placeholderIconSize: labelSize * 0.35,
                              ),
                            ),
                          ),
                          // Borda fina ao redor do label — separa visualmente
                          // a capa do disco preto.
                          Container(
                            width: labelSize,
                            height: labelSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.black.withValues(alpha: 0.55),
                                width: 1.2,
                              ),
                            ),
                          ),
                          // Furo central do vinil
                          Container(
                            width: size * 0.022,
                            height: size * 0.022,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF050505),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Sheen estático (não gira) — efeito de luz refletindo
                  // de um ângulo fixo enquanto o disco roda. Dá realismo. ──
                  IgnorePointer(
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          center: const Alignment(-0.5, -0.6),
                          radius: 0.95,
                          colors: [
                            Colors.white.withValues(alpha: 0.10),
                            Colors.white.withValues(alpha: 0.03),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.4, 0.8],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _VinylPainter extends CustomPainter {
  const _VinylPainter({required this.accentColor});
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;

    // ── 1. Corpo do disco — radial sutil (preto profundo no centro,
    //       quase preto nas bordas) para dar volume sem virar cinza. ──
    final bodyPaint = Paint()
      ..shader = RadialGradient(
        colors: const [Color(0xFF1A1A1A), Color(0xFF0E0E0E), Color(0xFF050505)],
        stops: const [0.0, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: maxR));
    canvas.drawCircle(center, maxR, bodyPaint);

    // ── 2. Borda externa fina (rim light) — separa o disco do fundo ──
    canvas.drawCircle(
      center,
      maxR - 0.5,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // ── 3. Sulcos concêntricos finos — densos como um vinil real.
    //       Vão do label (R*0.40) até quase a borda (R*0.97). ──
    const grooveCount = 38;
    final grooveStart = maxR * 0.40;
    final grooveEnd = maxR * 0.97;
    final grooveStep = (grooveEnd - grooveStart) / grooveCount;
    for (int i = 0; i < grooveCount; i++) {
      final r = grooveStart + i * grooveStep;
      // A cada 6 sulcos, um mais marcado (dá ritmo visual ao disco).
      final isAccent = i % 6 == 0;
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..color = isAccent
              ? accentColor.withValues(alpha: 0.14)
              : Colors.white.withValues(alpha: 0.04)
          ..style = PaintingStyle.stroke
          ..strokeWidth = isAccent ? 0.9 : 0.5,
      );
    }

    // ── 4. Banda mais escura entre sulcos e label — destaca o label ──
    canvas.drawCircle(
      center,
      maxR * 0.41,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = maxR * 0.015,
    );

    // ── 5. Label central — gradiente do accent para versão mais escura.
    //       O Stack acima sobrepõe a capa real recortada em círculo. ──
    final labelR = maxR * 0.40;
    final labelPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Color.lerp(accentColor, const Color(0xFF1A1A1A), 0.10)!,
          Color.lerp(accentColor, const Color(0xFF050505), 0.50)!,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: labelR));
    canvas.drawCircle(center, labelR, labelPaint);
  }

  @override
  bool shouldRepaint(_VinylPainter old) => old.accentColor != accentColor;
}

// ── Gradient track shape for MediaBarStyle.gradient ───────────
