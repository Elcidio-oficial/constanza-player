import 'package:flutter/material.dart';
import 'package:constanza_player/core/theme/app_spacing.dart';
import 'package:constanza_player/l10n/gen/app_localizations.dart';
import 'package:constanza_player/services/permission_service.dart';
import 'package:go_router/go_router.dart';

/// Tela premium de solicitação de permissão.
///
/// Apresentada uma única vez no primeiro acesso.
/// Design minimalista e elegante com animações suaves.
class PermissionPage extends StatefulWidget {
  const PermissionPage({super.key, required this.onGranted});

  final VoidCallback onGranted;

  @override
  State<PermissionPage> createState() => _PermissionPageState();
}

class _PermissionPageState extends State<PermissionPage>
    with TickerProviderStateMixin {
  late final AnimationController _entryController;
  late final Animation<double> _iconOpacity;
  late final Animation<double> _iconScale;
  late final Animation<double> _titleOpacity;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _descOpacity;
  late final Animation<Offset> _descSlide;
  late final Animation<double> _featuresOpacity;
  late final Animation<double> _btnOpacity;
  late final Animation<double> _btnScale;

  bool _requesting = false;
  bool _denied = false;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // Icon: 0-30%
    _iconOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );
    _iconScale = Tween(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOutBack),
      ),
    );

    // Title: 15-45%
    _titleOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.15, 0.45, curve: Curves.easeOut),
      ),
    );
    _titleSlide = Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.15, 0.45, curve: Curves.easeOutCubic),
      ),
    );

    // Description: 25-55%
    _descOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.25, 0.55, curve: Curves.easeOut),
      ),
    );
    _descSlide = Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.25, 0.55, curve: Curves.easeOutCubic),
      ),
    );

    // Features: 40-70%
    _featuresOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.40, 0.70, curve: Curves.easeOut),
      ),
    );

    // Button: 60-90%
    _btnOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.60, 0.90, curve: Curves.easeOut),
      ),
    );
    _btnScale = Tween(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.60, 0.95, curve: Curves.easeOutCubic),
      ),
    );

    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
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
      widget.onGranted();
    } else {
      final permanent = await PermissionService.isPermanentlyDenied();
      if (!mounted) return;
      setState(() {
        _requesting = false;
        _denied = true;
      });
      if (permanent) {
        _showSettingsDialog();
      }
    }
  }

  void _showSettingsDialog() {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.permissionPermanentlyDenied),
        content: Text(l10n.permissionPermanentlyDeniedDesc),
        actions: [
          TextButton(onPressed: () => ctx.pop(), child: Text(l10n.commonCancel)),
          FilledButton(
            onPressed: () {
              ctx.pop();
              PermissionService.openSettings();
            },
            child: Text(l10n.permissionOpenSettings),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colors.surface,
      body: AnimatedBuilder(
        animation: _entryController,
        builder: (context, _) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 24),

                // === ICON ===
                Opacity(
                  opacity: _iconOpacity.value,
                  child: Transform.scale(
                    scale: _iconScale.value,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.primaryContainer.withValues(alpha: 0.15),
                        border: Border.all(
                          color: colors.primary.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        Icons.library_music_rounded,
                        size: 44,
                        color: colors.primary,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // === TITLE ===
                SlideTransition(
                  position: _titleSlide,
                  child: Opacity(
                    opacity: _titleOpacity.value,
                    child: Text(
                      l10n.permissionTitle,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // === DESCRIPTION ===
                SlideTransition(
                  position: _descSlide,
                  child: Opacity(
                    opacity: _descOpacity.value,
                    child: Text(
                      l10n.permissionDescription,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.55),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // === FEATURES ===
                Opacity(
                  opacity: _featuresOpacity.value,
                  child: Column(
                    children: [
                      _FeatureRow(
                        icon: Icons.music_note_rounded,
                        text: l10n.permissionFeatureDiscover,
                        colors: colors,
                        theme: theme,
                      ),
                      const SizedBox(height: 16),
                      _FeatureRow(
                        icon: Icons.palette_rounded,
                        text: l10n.permissionFeatureColors,
                        colors: colors,
                        theme: theme,
                      ),
                      const SizedBox(height: 16),
                      _FeatureRow(
                        icon: Icons.queue_music_rounded,
                        text: l10n.permissionFeaturePlaylists,
                        colors: colors,
                        theme: theme,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // === BUTTON ===
                Opacity(
                  opacity: _btnOpacity.value,
                  child: Transform.scale(
                    scale: _btnScale.value,
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        onPressed: _requesting ? null : _requestPermission,
                        style: FilledButton.styleFrom(
                          backgroundColor: colors.primary,
                          foregroundColor: colors.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: _requesting
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: colors.onPrimary,
                                ),
                              )
                            : Text(l10n.permissionAllow),
                      ),
                    ),
                  ),
                ),

                if (_denied) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _requestPermission,
                    child: Text(
                      l10n.permissionRetry,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.primary,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.huge),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.text,
    required this.colors,
    required this.theme,
  });

  final IconData icon;
  final String text;
  final ColorScheme colors;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: colors.primaryContainer.withValues(alpha: 0.12),
          ),
          child: Icon(
            icon,
            size: 20,
            color: colors.primary.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
      ],
    );
  }
}
