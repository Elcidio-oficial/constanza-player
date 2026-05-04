import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:constanza_player/l10n/gen/app_localizations.dart';
import 'package:constanza_player/core/theme/app_backgrounds.dart';
import 'package:constanza_player/core/theme/app_spacing.dart';
import 'package:constanza_player/presentation/providers/theme_provider.dart';
import 'package:constanza_player/presentation/widgets/background_wrapper.dart';
import 'package:constanza_player/core/utils/background_helper.dart';
import 'package:go_router/go_router.dart';

/// Página de configuração de fundo do app — com image picker.
class BackgroundSettingsPage extends ConsumerWidget {
  const BackgroundSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final themeState = ref.watch(themeProvider);
    final notifier = ref.read(themeProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    final availableGradients = isDark
        ? AppBackgrounds.darkGradients
        : AppBackgrounds.lightGradients;

    return BackgroundWrapper(
      child: Scaffold(
        backgroundColor: BackgroundHelper.scaffoldColor(colors, themeState),
        appBar: AppBar(
          backgroundColor: BackgroundHelper.appBarColor(colors, themeState),
          title: Text(
            l10n.bgSettingsTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w300,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            // Sem fundo
            _OptionTile(
              title: l10n.bgSettingsNoneTitle,
              subtitle: l10n.bgSettingsNoneSubtitle,
              icon: Icons.format_color_reset_rounded,
              isSelected: themeState.backgroundType == BackgroundType.none,
              onTap: () => notifier.setBackgroundNone(),
              colors: colors,
              theme: theme,
            ),

            const SizedBox(height: AppSpacing.lg),

            // Gradientes
            Text(
              l10n.bgSettingsGradientsHeader,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.35),
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1,
                crossAxisSpacing: AppSpacing.sm,
                mainAxisSpacing: AppSpacing.sm,
              ),
              itemCount: availableGradients.length,
              itemBuilder: (context, index) {
                final gradient = availableGradients[index];
                final isSelected =
                    themeState.backgroundType == BackgroundType.gradient &&
                    themeState.gradientPresetId == gradient.id;
                return GestureDetector(
                  onTap: () => notifier.setBackgroundGradient(gradient.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      gradient: gradient.toGradient(),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(
                        color: isSelected
                            ? colors.onSurface
                            : colors.outline.withValues(alpha: 0.2),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          bottom: AppSpacing.xs,
                          left: AppSpacing.xs,
                          right: AppSpacing.xs,
                          child: Text(
                            gradient.name,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: isDark ? Colors.white70 : Colors.black54,
                              fontSize: 9,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        if (isSelected)
                          Positioned(
                            top: AppSpacing.xs,
                            right: AppSpacing.xs,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: colors.onSurface,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check_rounded,
                                size: 14,
                                color: colors.surface,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: AppSpacing.lg),

            // Imagem personalizada
            Text(
              l10n.bgSettingsCustomImageHeader,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.35),
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Preview da imagem atual
            if (themeState.hasImageBackground) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                child: Stack(
                  children: [
                    Image.file(
                      File(themeState.backgroundImagePath!),
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(height: 150),
                    ),
                    Positioned(
                      top: AppSpacing.xs,
                      right: AppSpacing.xs,
                      child: GestureDetector(
                        onTap: () => notifier.setBackgroundNone(),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: AppSpacing.xs,
                      left: AppSpacing.xs,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusSm,
                          ),
                        ),
                        child: Text(
                          l10n.bgSettingsCurrent,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],

            // Botão escolher imagem
            GestureDetector(
              onTap: () => _pickImage(context, ref),
              child: Container(
                height: themeState.hasImageBackground ? 56 : 100,
                decoration: BoxDecoration(
                  color: colors.onSurface.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(
                    color: colors.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 24,
                        color: colors.onSurface.withValues(alpha: 0.4),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        themeState.hasImageBackground
                            ? l10n.bgSettingsChangeImage
                            : l10n.bgSettingsPickFromGallery,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Ajustes
            if (themeState.hasBackground) ...[
              const SizedBox(height: AppSpacing.xl),
              Text(
                l10n.bgSettingsAdjustments,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.35),
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _SliderSetting(
                label: l10n.bgSettingsIntensity,
                value: themeState.backgroundOpacity,
                min: 0.05,
                max: 0.5,
                displayValue:
                    '${(themeState.backgroundOpacity * 100).round()}%',
                onChanged: notifier.setBackgroundOpacity,
                colors: colors,
                theme: theme,
              ),
              const SizedBox(height: AppSpacing.md),
              _SliderSetting(
                label: l10n.bgSettingsBlur,
                value: themeState.backgroundBlur,
                min: 0,
                max: 25,
                displayValue: themeState.backgroundBlur == 0
                    ? l10n.bgSettingsBlurOff
                    : '${themeState.backgroundBlur.round()}',
                onChanged: notifier.setBackgroundBlur,
                colors: colors,
                theme: theme,
              ),
            ],

            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(BuildContext context, WidgetRef ref) async {
    final colors = Theme.of(context).colorScheme;

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );
      if (picked == null) return;

      // Copiar para armazenamento permanente do app.
      final appDir = await getApplicationDocumentsDirectory();
      final bgDir = Directory('${appDir.path}/backgrounds');
      if (!bgDir.existsSync()) bgDir.createSync(recursive: true);

      final ext = picked.path.split('.').last;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final dest = File('${bgDir.path}/wallpaper_$timestamp.$ext');

      // Remover wallpaper anterior.
      final oldFiles = bgDir.listSync().where(
        (f) => f is File && f.path.contains('wallpaper') && f.path != dest.path,
      );
      for (final old in oldFiles) {
        try {
          await old.delete();
        } catch (_) {}
      }

      await File(picked.path).copy(dest.path);

      // Limpar cache de imagens do Flutter para forçar recarregamento.
      imageCache.clear();
      imageCache.clearLiveImages();

      // Aplicar como fundo.
      ref.read(themeProvider.notifier).setBackgroundImage(dest.path);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).bgSettingsImageUpdated),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).bgSettingsImageError),
            backgroundColor: colors.error,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.colors,
    required this.theme,
  });
  final String title, subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme colors;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.onSurface.withValues(alpha: 0.06)
              : colors.onSurface.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: isSelected
                ? colors.onSurface.withValues(alpha: 0.3)
                : colors.outline.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: colors.onSurface.withValues(alpha: 0.5)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: colors.onSurface,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

class _SliderSetting extends StatelessWidget {
  const _SliderSetting({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.displayValue,
    required this.onChanged,
    required this.colors,
    required this.theme,
  });
  final String label, displayValue;
  final double value, min, max;
  final ValueChanged<double> onChanged;
  final ColorScheme colors;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.7),
              ),
            ),
            Text(
              displayValue,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: colors.onSurface,
            inactiveTrackColor: colors.onSurface.withValues(alpha: 0.1),
            thumbColor: colors.onSurface,
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          ),
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
      ],
    );
  }
}
