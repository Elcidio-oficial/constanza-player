import 'package:flutter/material.dart';
import 'package:constanza_player/services/permission_service.dart';
import 'package:go_router/go_router.dart';

/// Onboarding premium de 3 páginas com PageView.
///
/// Página 1: Boas-vindas — branding + proposta de valor
/// Página 2: Funcionalidades — destaques visuais
/// Página 3: Permissão — solicita acesso ao áudio
///
/// Exibido uma única vez (controlado pelo flag em main.dart).
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with TickerProviderStateMixin {
  final _pageController = PageController();
  int _currentPage = 0;
  bool _requesting = false;
  bool _denied = false;

  late final AnimationController _bgAnim;

  @override
  void initState() {
    super.initState();
    _bgAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _bgAnim.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _requestPermission() async {
    if (_requesting) return;
    setState(() {
      _requesting = true;
      _denied = false;
    });

    final granted = await PermissionService.requestAudioPermission();
    if (!mounted) return;

    if (granted) {
      widget.onComplete();
    } else {
      final permanent = await PermissionService.isPermanentlyDenied();
      if (!mounted) return;
      setState(() {
        _requesting = false;
        _denied = true;
      });
      if (permanent) _showSettingsDialog();
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permissão necessária'),
        content: const Text(
          'A permissão foi negada permanentemente. '
          'Abra as configurações do app para conceder acesso.',
        ),
        actions: [
          TextButton(onPressed: () => ctx.pop(), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              ctx.pop();
              PermissionService.openSettings();
            },
            child: const Text('Configurações'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      body: Stack(
        children: [
          // Animated gradient background
          AnimatedBuilder(
            animation: _bgAnim,
            builder: (_, __) => Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors.surface,
                    Color.lerp(
                      colors.surface,
                      colors.primary.withValues(alpha: 0.08),
                      _bgAnim.value,
                    )!,
                  ],
                ),
              ),
            ),
          ),

          // Pages
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    physics: const ClampingScrollPhysics(),
                    children: [
                      _WelcomePage(theme: theme, colors: colors),
                      _FeaturesPage(theme: theme, colors: colors),
                      _PermissionRequestPage(
                        theme: theme,
                        colors: colors,
                        requesting: _requesting,
                        denied: _denied,
                        onRequest: _requestPermission,
                      ),
                    ],
                  ),
                ),

                // Bottom: dots + button
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
                  child: Row(
                    children: [
                      // Page dots
                      Row(
                        children: List.generate(3, (i) {
                          final active = i == _currentPage;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(right: 8),
                            width: active ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: active
                                  ? colors.primary
                                  : colors.onSurface.withValues(alpha: 0.15),
                            ),
                          );
                        }),
                      ),

                      const Spacer(),

                      // Action button
                      if (_currentPage < 2)
                        FilledButton(
                          onPressed: _nextPage,
                          style: FilledButton.styleFrom(
                            backgroundColor: colors.primary,
                            foregroundColor: colors.onPrimary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _currentPage == 0 ? 'Começar' : 'Próximo',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colors.onPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 18,
                                color: colors.onPrimary,
                              ),
                            ],
                          ),
                        )
                      else
                        FilledButton(
                          onPressed: _requesting ? null : _requestPermission,
                          style: FilledButton.styleFrom(
                            backgroundColor: colors.primary,
                            foregroundColor: colors.onPrimary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _requesting
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: colors.onPrimary,
                                  ),
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Permitir Acesso',
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: colors.onPrimary,
                                          ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.lock_open_rounded,
                                      size: 18,
                                      color: colors.onPrimary,
                                    ),
                                  ],
                                ),
                        ),
                    ],
                  ),
                ),

                if (_denied && _currentPage == 2)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TextButton(
                      onPressed: _requestPermission,
                      child: Text(
                        'Tentar novamente',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.primary,
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
// PAGE 1 — Welcome
// ============================================================

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.theme, required this.colors});
  final ThemeData theme;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const Spacer(flex: 2),

          // Logo
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: colors.onSurface.withValues(alpha: 0.12),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                'C',
                style: theme.textTheme.displayLarge?.copyWith(
                  color: colors.primary,
                  fontSize: 52,
                  fontWeight: FontWeight.w200,
                ),
              ),
            ),
          ),

          const SizedBox(height: 40),

          Text(
            'CONSTANZA',
            style: theme.textTheme.headlineSmall?.copyWith(
              letterSpacing: 6,
              fontWeight: FontWeight.w300,
              color: colors.onSurface,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Músicas',
            style: theme.textTheme.titleMedium?.copyWith(
              letterSpacing: 3,
              color: colors.onSurface.withValues(alpha: 0.4),
              fontWeight: FontWeight.w300,
            ),
          ),

          const SizedBox(height: 48),

          Text(
            'A experiência musical premium\nque as suas músicas merecem.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.55),
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),

          const Spacer(flex: 3),
        ],
      ),
    );
  }
}

// ============================================================
// PAGE 2 — Features
// ============================================================

class _FeaturesPage extends StatelessWidget {
  const _FeaturesPage({required this.theme, required this.colors});
  final ThemeData theme;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const Spacer(flex: 2),

          Text(
            'Tudo o que precisa',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          Text(
            'Um player completo e elegante',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.5),
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 48),

          _FeatureCard(
            icon: Icons.palette_rounded,
            title: 'Cores Dinâmicas',
            subtitle: 'A interface adapta-se à capa de cada álbum',
            colors: colors,
            theme: theme,
          ),
          const SizedBox(height: 16),
          _FeatureCard(
            icon: Icons.equalizer_rounded,
            title: 'Equalizador Nativo',
            subtitle: 'EQ de 5 bandas com bass boost e virtualizer',
            colors: colors,
            theme: theme,
          ),
          const SizedBox(height: 16),
          _FeatureCard(
            icon: Icons.auto_awesome_rounded,
            title: '10 Estilos de Player',
            subtitle: 'Classic, Vinyl, Aurora, Elegant e mais',
            colors: colors,
            theme: theme,
          ),
          const SizedBox(height: 16),
          _FeatureCard(
            icon: Icons.search_rounded,
            title: 'Pesquisa Inteligente',
            subtitle: 'Encontre por título, artista ou álbum',
            colors: colors,
            theme: theme,
          ),

          const Spacer(flex: 3),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.theme,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final ColorScheme colors;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border.all(color: colors.outline.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: colors.primary.withValues(alpha: 0.1),
            ),
            child: Icon(icon, size: 22, color: colors.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.5),
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
// PAGE 3 — Permission
// ============================================================

class _PermissionRequestPage extends StatelessWidget {
  const _PermissionRequestPage({
    required this.theme,
    required this.colors,
    required this.requesting,
    required this.denied,
    required this.onRequest,
  });

  final ThemeData theme;
  final ColorScheme colors;
  final bool requesting;
  final bool denied;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const Spacer(flex: 2),

          // Shield icon
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.primaryContainer.withValues(alpha: 0.12),
              border: Border.all(
                color: colors.primary.withValues(alpha: 0.15),
                width: 1.5,
              ),
            ),
            child: Icon(
              Icons.folder_open_rounded,
              size: 44,
              color: colors.primary,
            ),
          ),

          const SizedBox(height: 32),

          Text(
            'Acesso à sua música',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 12),

          Text(
            'O Constanza precisa de permissão para encontrar e '
            'reproduzir as músicas armazenadas no seu dispositivo.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.55),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 40),

          // Privacy assurance
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.shield_rounded,
                  size: 20,
                  color: colors.primary.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Os seus ficheiros nunca saem do dispositivo. '
                    'Sem cloud, sem rastreamento.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.55),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Spacer(flex: 3),
        ],
      ),
    );
  }
}
