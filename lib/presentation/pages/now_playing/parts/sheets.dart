// ignore_for_file: deprecated_member_use, unused_local_variable, curly_braces_in_flow_control_structures, unused_element_parameter
part of '../now_playing_page.dart';

class _EqBottomSheet extends ConsumerWidget {
  const _EqBottomSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baseColors = Theme.of(context).colorScheme;
    final colors = baseColors;
    final theme = Theme.of(context);
    final audioState = ref.watch(audioSettingsProvider);
    final notifier = ref.read(audioSettingsProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
        border: Border(
          top: BorderSide(color: colors.outline.withValues(alpha: 0.1)),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.xs),
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: colors.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Header: título + toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  Icon(
                    Icons.equalizer_rounded,
                    size: 22,
                    color: audioState.eqEnabled
                        ? colors.primary
                        : colors.fadedText(0.4),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context).npEqualizer,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Switch.adaptive(
                    value: audioState.eqEnabled,
                    onChanged: (_) => notifier.toggleEq(),
                    activeTrackColor: colors.primary,
                    inactiveTrackColor: colors.onSurface.withValues(alpha: 0.1),
                    thumbColor: WidgetStatePropertyAll(colors.onSurface),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            // Presets
            AnimatedOpacity(
              opacity: audioState.eqEnabled ? 1.0 : 0.3,
              duration: const Duration(milliseconds: 200),
              child: AbsorbPointer(
                absorbing: !audioState.eqEnabled,
                child: Column(
                  children: [
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                        ),
                        itemCount: kEqPresets.length - 1,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: AppSpacing.xs),
                        itemBuilder: (_, i) {
                          final preset = kEqPresets[i];
                          final selected = audioState.eqPresetId == preset.id;
                          return GestureDetector(
                            onTap: () => notifier.setPreset(preset.id),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? colors.primary
                                    : colors.onSurface.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusFull,
                                ),
                                border: Border.all(
                                  color: selected
                                      ? colors.primary
                                      : colors.onSurface.withValues(
                                          alpha: 0.12,
                                        ),
                                ),
                              ),
                              child: Text(
                                preset.name,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: selected
                                      ? colors.onPrimary
                                      : colors.fadedText(0.6),
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // 5 Band mini-sliders
                    Container(
                      height: 180,
                      margin: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: colors.onSurface.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMd,
                        ),
                        border: Border.all(
                          color: colors.onSurface.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Row(
                        children: [
                          // dB scale
                          Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '+12',
                                style: TextStyle(
                                  color: colors.onSurface.withValues(
                                    alpha: 0.2,
                                  ),
                                  fontSize: 8,
                                ),
                              ),
                              Text(
                                '0',
                                style: TextStyle(
                                  color: colors.fadedText(0.3),
                                  fontSize: 8,
                                ),
                              ),
                              Text(
                                '-12',
                                style: TextStyle(
                                  color: colors.onSurface.withValues(
                                    alpha: 0.2,
                                  ),
                                  fontSize: 8,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 4),
                          ...List.generate(
                            5,
                            (i) => Expanded(
                              child: Column(
                                children: [
                                  Expanded(
                                    child: RotatedBox(
                                      quarterTurns: 3,
                                      child: SliderTheme(
                                        data: SliderTheme.of(context).copyWith(
                                          trackHeight: 2.5,
                                          thumbShape:
                                              const RoundSliderThumbShape(
                                                enabledThumbRadius: 6,
                                              ),
                                          activeTrackColor: colors.primary,
                                          inactiveTrackColor: colors.onSurface
                                              .withValues(alpha: 0.08),
                                          thumbColor: colors.onSurface,
                                          overlayShape:
                                              const RoundSliderOverlayShape(
                                                overlayRadius: 12,
                                              ),
                                        ),
                                        child: Slider(
                                          value: audioState.eqBands[i],
                                          min: -12,
                                          max: 12,
                                          onChanged: (v) =>
                                              notifier.setBand(i, v),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    kBandLabels[i],
                                    style: TextStyle(
                                      color: colors.onSurface.withValues(
                                        alpha: 0.35,
                                      ),
                                      fontSize: 8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // Bass Boost + Virtualizer compact
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _MiniEffectSlider(
                              label: 'Bass',
                              value: audioState.bassBoost,
                              max: 10,
                              color: colors.primary,
                              onChanged: notifier.setBassBoost,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: _MiniEffectSlider(
                              label: 'Virtual',
                              value: audioState.virtualizer,
                              max: 10,
                              color: colors.primary,
                              onChanged: notifier.setVirtualizer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

// Mini effect slider for EQ sheet
class _MiniEffectSlider extends StatelessWidget {
  const _MiniEffectSlider({
    required this.label,
    required this.value,
    required this.max,
    required this.color,
    required this.onChanged,
  });
  final String label;
  final double value;
  final double max;
  final Color color;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: colors.fadedText(0.5),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value == 0 ? 'Off' : value.round().toString(),
              style: TextStyle(color: colors.fadedText(0.3), fontSize: 10),
            ),
          ],
        ),
        const SizedBox(height: 2),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
            activeTrackColor: color,
            inactiveTrackColor: colors.onSurface.withValues(alpha: 0.08),
            thumbColor: colors.onSurface,
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
          ),
          child: Slider(value: value, min: 0, max: max, onChanged: onChanged),
        ),
      ],
    );
  }
}

// ============================================================
// SPEED BOTTOM SHEET — premium speed selector
// ============================================================

class _SpeedBottomSheet extends ConsumerStatefulWidget {
  const _SpeedBottomSheet();

  @override
  ConsumerState<_SpeedBottomSheet> createState() => _SpeedBottomSheetState();
}

class _SpeedBottomSheetState extends ConsumerState<_SpeedBottomSheet> {
  late double _currentSpeed;

  static const _presets = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
  static const _presetLabels = [
    '0.5x',
    '0.75x',
    '1x',
    '1.25x',
    '1.5x',
    '1.75x',
    '2x',
  ];

  @override
  void initState() {
    super.initState();
    _currentSpeed = ref.read(audioSettingsProvider).playbackSpeed;
  }

  void _setSpeed(double speed) {
    setState(() => _currentSpeed = speed);
    ref.read(audioSettingsProvider.notifier).setPlaybackSpeed(speed);
    ref.read(playerProvider.notifier).setSpeed(speed);
  }

  @override
  Widget build(BuildContext context) {
    final baseColors = Theme.of(context).colorScheme;
    final colors = baseColors;
    final theme = Theme.of(context);
    final isCustom = (_currentSpeed - 1.0).abs() > 0.01;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
        border: Border(
          top: BorderSide(color: colors.outline.withValues(alpha: 0.1)),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.xs),
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: colors.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Current speed display
            Text(
              '${_currentSpeed.toStringAsFixed(_currentSpeed == _currentSpeed.roundToDouble() ? 1 : 2)}x',
              style: theme.textTheme.displaySmall?.copyWith(
                color: isCustom ? colors.primary : colors.onSurface,
                fontWeight: FontWeight.w300,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              AppLocalizations.of(context).npSpeedTitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.fadedText(0.35),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Slider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 8,
                      ),
                      activeTrackColor: colors.primary,
                      inactiveTrackColor: colors.onSurface.withValues(
                        alpha: 0.08,
                      ),
                      thumbColor: colors.onSurface,
                      overlayColor: colors.primary.withValues(alpha: 0.2),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 18,
                      ),
                    ),
                    child: Slider(
                      value: _currentSpeed,
                      min: 0.5,
                      max: 2.0,
                      divisions: 30, // 0.05 steps
                      onChanged: _setSpeed,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xxs,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '0.5x',
                          style: TextStyle(
                            color: colors.fadedText(0.25),
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          '2.0x',
                          style: TextStyle(
                            color: colors.fadedText(0.25),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Preset chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                alignment: WrapAlignment.center,
                children: List.generate(_presets.length, (i) {
                  final speed = _presets[i];
                  final selected = (_currentSpeed - speed).abs() < 0.01;
                  final isNormal = speed == 1.0;
                  return GestureDetector(
                    onTap: () => _setSpeed(speed),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? colors.primary
                            : colors.onSurface.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusFull,
                        ),
                        border: Border.all(
                          color: selected
                              ? colors.primary
                              : isNormal
                              ? colors.onSurface.withValues(alpha: 0.2)
                              : colors.onSurface.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Text(
                        _presetLabels[i],
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: selected
                              ? colors.onPrimary
                              : colors.fadedText(0.6),
                          fontWeight: selected || isNormal
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            // Reset button
            if (isCustom) ...[
              const SizedBox(height: AppSpacing.md),
              GestureDetector(
                onTap: () => _setSpeed(1.0),
                child: Text(
                  AppLocalizations.of(context).npSpeedReset,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.primary.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// SLEEP TIMER BOTTOM SHEET — premium picker with fade-out toggle
// ============================================================
