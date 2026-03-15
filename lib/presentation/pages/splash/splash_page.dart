import 'package:flutter/material.dart';
import 'package:constanza_player/core/constants/app_constants.dart';
import 'package:constanza_player/core/theme/app_spacing.dart';

/// Splash Screen do Constanza Músicas.
///
/// Sequência de animação:
/// 1. Logo "C" fade in + scale (0-600ms)
/// 2. "CONSTANZA" fade in (400-800ms)
/// 3. "Músicas" fade in (600-1000ms)
/// 4. Loading line pulse (800-2500ms)
/// 5. Fade out tudo → navega para Home
class SplashPage extends StatefulWidget {
  const SplashPage({super.key, required this.onComplete});

  /// Callback quando a splash termina.
  final VoidCallback onComplete;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  // Controller principal da sequência
  late final AnimationController _sequenceController;

  // Animações individuais
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;
  late final Animation<double> _titleOpacity;
  late final Animation<double> _subtitleOpacity;
  late final Animation<double> _loadingOpacity;

  // Controller do loading (loop)
  late final AnimationController _loadingController;
  late final Animation<double> _loadingWidth;

  // Controller do fade out final
  late final AnimationController _fadeOutController;
  late final Animation<double> _fadeOut;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startSequence();
  }

  void _setupAnimations() {
    // Sequência principal: 0ms → 1200ms
    _sequenceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Logo: 0% → 50% da sequência (0-600ms)
    _logoOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _sequenceController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _logoScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _sequenceController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
      ),
    );

    // Título: 33% → 67% (400-800ms)
    _titleOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _sequenceController,
        curve: const Interval(0.33, 0.67, curve: Curves.easeOut),
      ),
    );

    // Subtítulo: 50% → 83% (600-1000ms)
    _subtitleOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _sequenceController,
        curve: const Interval(0.5, 0.83, curve: Curves.easeOut),
      ),
    );

    // Loading: 67% → 100% (800-1200ms)
    _loadingOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _sequenceController,
        curve: const Interval(0.67, 1.0, curve: Curves.easeOut),
      ),
    );

    // Loading pulse loop
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _loadingWidth = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _loadingController, curve: Curves.easeInOut),
    );

    // Fade out final
    _fadeOutController = AnimationController(
      vsync: this,
      duration: AppConstants.slow,
    );

    _fadeOut = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _fadeOutController, curve: Curves.easeInCubic),
    );
  }

  void _startSequence() async {
    // Pequeno delay inicial para o app "respirar"
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    // Inicia sequência de entrada
    _sequenceController.forward();

    // Inicia pulse do loading depois de 1s
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    _loadingController.repeat(reverse: true);

    // Espera o tempo total da splash (desconta os 1200ms já passados)
    const totalSplash = AppConstants.splashDuration;
    const alreadyElapsed = Duration(milliseconds: 1200);
    final remaining = totalSplash > alreadyElapsed
        ? totalSplash - alreadyElapsed
        : Duration.zero;
    await Future.delayed(remaining);
    if (!mounted) return;

    // Fade out
    await _fadeOutController.forward();

    // Navega — sempre chama, mesmo se widget for reconstruído
    if (mounted) {
      widget.onComplete();
    }
  }

  @override
  void dispose() {
    _sequenceController.dispose();
    _loadingController.dispose();
    _fadeOutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _sequenceController,
          _loadingController,
          _fadeOutController,
        ]),
        builder: (context, _) {
          return Opacity(
            opacity: _fadeOut.value,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 3),

                  // === LOGO ===
                  Opacity(
                    opacity: _logoOpacity.value,
                    child: Transform.scale(
                      scale: _logoScale.value,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colors.onSurface,
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'C',
                            style: theme.textTheme.displayLarge?.copyWith(
                              color: colors.onSurface,
                              fontSize: 36,
                              fontWeight: FontWeight.w200,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // === TÍTULO ===
                  Opacity(
                    opacity: _titleOpacity.value,
                    child: Text(
                      'CONSTANZA',
                      style: theme.textTheme.titleMedium?.copyWith(
                        letterSpacing: 8,
                        fontWeight: FontWeight.w300,
                        color: colors.onSurface,
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xs),

                  // === SUBTÍTULO ===
                  Opacity(
                    opacity: _subtitleOpacity.value,
                    child: Text(
                      'Músicas',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        letterSpacing: 4,
                        color: colors.onSurface.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),

                  const Spacer(flex: 2),

                  // === LOADING LINE ===
                  Opacity(
                    opacity: _loadingOpacity.value,
                    child: SizedBox(
                      width: 48,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: _loadingWidth.value,
                          child: Container(
                            height: 1.5,
                            decoration: BoxDecoration(
                              color: colors.onSurface.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.huge),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
