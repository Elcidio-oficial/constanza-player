import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:constanza_player/l10n/gen/app_localizations.dart';
import 'package:constanza_player/core/theme/app_spacing.dart';
import 'package:constanza_player/presentation/providers/audio_settings_provider.dart';
import 'package:constanza_player/presentation/providers/artwork_provider.dart';
import 'package:constanza_player/presentation/providers/theme_provider.dart';
import 'package:constanza_player/presentation/widgets/background_wrapper.dart';
import 'package:constanza_player/core/utils/background_helper.dart';
import 'package:go_router/go_router.dart';

/// Página do Equalizador — 5 bandas + presets + efeitos.
class EqualizerPage extends ConsumerWidget {
  const EqualizerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final audioState = ref.watch(audioSettingsProvider);
    final notifier = ref.read(audioSettingsProvider.notifier);
    final palette = ref.watch(artworkPaletteProvider);
    final accentColor = palette?.vibrant ?? palette?.dominant;
    final l10n = AppLocalizations.of(context);

    final themeState = ref.watch(themeProvider);

    return BackgroundWrapper(
      child: Scaffold(
        backgroundColor: BackgroundHelper.scaffoldColor(colors, themeState),
        appBar: AppBar(
          backgroundColor: BackgroundHelper.appBarColor(colors, themeState),
          title: Text(
            l10n.eqTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w300,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
          actions: [
            // Toggle master
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: Switch.adaptive(
                value: audioState.eqEnabled,
                onChanged: (_) => notifier.toggleEq(),
                activeThumbColor: accentColor ?? colors.onSurface,
              ),
            ),
          ],
        ),
        body: AnimatedOpacity(
          opacity: audioState.eqEnabled ? 1.0 : 0.35,
          duration: const Duration(milliseconds: 200),
          child: AbsorbPointer(
            absorbing: !audioState.eqEnabled,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                // === PRESETS ===
                Text(
                  l10n.eqPresets,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.35),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: kEqPresets.length - 1, // exclui "custom"
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: AppSpacing.xs),
                    itemBuilder: (context, index) {
                      final preset = kEqPresets[index];
                      final isSelected = audioState.eqPresetId == preset.id;
                      return GestureDetector(
                        onTap: () => notifier.setPreset(preset.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (accentColor ?? colors.onSurface)
                                : colors.onSurface.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusFull,
                            ),
                            border: Border.all(
                              color: isSelected
                                  ? (accentColor ?? colors.onSurface)
                                  : colors.outline.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              preset.name,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: isSelected
                                    ? Colors.white
                                    : colors.onSurface.withValues(alpha: 0.6),
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                // === BANDAS ===
                Container(
                  height: 260,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: colors.onSurface.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(
                      color: colors.outline.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Escala dB
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '+12',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.onSurface.withValues(alpha: 0.25),
                              fontSize: 9,
                            ),
                          ),
                          Text(
                            '0',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.onSurface.withValues(alpha: 0.35),
                              fontSize: 9,
                            ),
                          ),
                          Text(
                            '-12',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.onSurface.withValues(alpha: 0.25),
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      // Sliders verticais
                      ...List.generate(5, (i) {
                        return Expanded(
                          child: _VerticalBandSlider(
                            value: audioState.eqBands[i],
                            label: kBandLabels[i],
                            onChanged: (v) => notifier.setBand(i, v),
                            colors: colors,
                            theme: theme,
                            accentColor: accentColor,
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                // Preset label
                if (audioState.eqPresetId == 'custom')
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      l10n.eqCustom,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.3),
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                const SizedBox(height: AppSpacing.xl),

                // === EFEITOS ===
                Text(
                  l10n.eqEffects,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.35),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Bass Boost
                _EffectSlider(
                  label: l10n.eqBassBoost,
                  value: audioState.bassBoost,
                  max: 10,
                  displayValue: audioState.bassBoost == 0
                      ? l10n.eqOff
                      : audioState.bassBoost.round().toString(),
                  onChanged: notifier.setBassBoost,
                  colors: colors,
                  theme: theme,
                  accentColor: accentColor,
                ),

                const SizedBox(height: AppSpacing.lg),

                // Virtualizer
                _EffectSlider(
                  label: l10n.eqVirtualizer,
                  value: audioState.virtualizer,
                  max: 10,
                  displayValue: audioState.virtualizer == 0
                      ? l10n.eqOff
                      : audioState.virtualizer.round().toString(),
                  onChanged: notifier.setVirtualizer,
                  colors: colors,
                  theme: theme,
                  accentColor: accentColor,
                ),

                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Slider vertical para cada banda do EQ.
class _VerticalBandSlider extends StatelessWidget {
  const _VerticalBandSlider({
    required this.value,
    required this.label,
    required this.onChanged,
    required this.colors,
    required this.theme,
    this.accentColor,
  });

  final double value;
  final String label;
  final ValueChanged<double> onChanged;
  final ColorScheme colors;
  final ThemeData theme;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final trackColor = accentColor ?? colors.onSurface;
    return Column(
      children: [
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                activeTrackColor: trackColor,
                inactiveTrackColor: trackColor.withValues(alpha: 0.15),
                thumbColor: trackColor,
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                value: value,
                min: -12,
                max: 12,
                onChanged: onChanged,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.onSurface.withValues(alpha: 0.4),
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}

/// Slider horizontal para efeitos (Bass Boost, Virtualizer).
class _EffectSlider extends StatelessWidget {
  const _EffectSlider({
    required this.label,
    required this.value,
    required this.max,
    required this.displayValue,
    required this.onChanged,
    required this.colors,
    required this.theme,
    this.accentColor,
  });

  final String label;
  final double value;
  final double max;
  final String displayValue;
  final ValueChanged<double> onChanged;
  final ColorScheme colors;
  final ThemeData theme;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final trackColor = accentColor ?? colors.onSurface;
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
            activeTrackColor: trackColor,
            inactiveTrackColor: trackColor.withValues(alpha: 0.15),
            thumbColor: trackColor,
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          ),
          child: Slider(value: value, min: 0, max: max, onChanged: onChanged),
        ),
      ],
    );
  }
}
