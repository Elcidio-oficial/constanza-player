part of '../settings_page.dart';

// ============================================================
// CUSTOM NP COLORS BOTTOM SHEET
// ============================================================

class _CustomNpColorsSheet extends ConsumerStatefulWidget {
  const _CustomNpColorsSheet({required this.colors, required this.theme});
  final ColorScheme colors;
  final ThemeData theme;

  @override
  ConsumerState<_CustomNpColorsSheet> createState() =>
      _CustomNpColorsSheetState();
}

class _CustomNpColorsSheetState extends ConsumerState<_CustomNpColorsSheet> {
  static const _presetColors = [
    Color(0xFFE53935),
    Color(0xFFD81B60),
    Color(0xFF8E24AA),
    Color(0xFF5E35B1),
    Color(0xFF3949AB),
    Color(0xFF1E88E5),
    Color(0xFF00ACC1),
    Color(0xFF00897B),
    Color(0xFF43A047),
    Color(0xFF7CB342),
    Color(0xFFFDD835),
    Color(0xFFFB8C00),
    Color(0xFFFF7043),
    Color(0xFF6D4C41),
    Color(0xFF546E7A),
    Color(0xFFEC407A),
  ];

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final notifier = ref.read(themeProvider.notifier);
    final colors = widget.colors;
    final theme = widget.theme;
    final accentColor = ref.watch(artworkPaletteProvider)?.dominant;
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.xs),
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: colors.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.customNpTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              l10n.customNpSubtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.fadedText(0.4),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Toggle
            SwitchListTile.adaptive(
              title: Text(
                l10n.customNpToggle,
                style: theme.textTheme.bodyMedium,
              ),
              subtitle: Text(
                themeState.useCustomNpColors
                    ? l10n.customNpToggleOnDesc
                    : l10n.customNpToggleOffDesc,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.fadedText(0.4),
                ),
              ),
              value: themeState.useCustomNpColors,
              onChanged: (_) => notifier.toggleCustomNpColors(),
              activeThumbColor: accentColor ?? colors.primary,
              activeTrackColor: accentColor?.withValues(alpha: 0.3),
              trackOutlineColor: WidgetStatePropertyAll(
                colors.onSurface.withValues(alpha: 0.15),
              ),
              contentPadding: EdgeInsets.zero,
            ),

            if (themeState.useCustomNpColors) ...[
              const SizedBox(height: AppSpacing.md),

              // Preview gradient
              Container(
                height: 48,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  gradient: LinearGradient(
                    colors: [
                      themeState.npCustomColor1 ?? const Color(0xFF6C63FF),
                      themeState.npCustomColor2 ?? const Color(0xFF3A3A5C),
                      themeState.npCustomColor3 ?? const Color(0xFF1A1A2E),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Color 1
              _NpColorRow(
                label: l10n.customNpDominant,
                color: themeState.npCustomColor1,
                presetColors: _presetColors,
                colors: colors,
                theme: theme,
                onColorSelected: (c) => notifier.setNpCustomColor(1, c),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Color 2
              _NpColorRow(
                label: l10n.customNpSecondary,
                color: themeState.npCustomColor2,
                presetColors: _presetColors,
                colors: colors,
                theme: theme,
                onColorSelected: (c) => notifier.setNpCustomColor(2, c),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Color 3
              _NpColorRow(
                label: l10n.customNpBackground,
                color: themeState.npCustomColor3,
                presetColors: _presetColors,
                colors: colors,
                theme: theme,
                onColorSelected: (c) => notifier.setNpCustomColor(3, c),
              ),
            ],

            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

class _NpColorRow extends StatelessWidget {
  const _NpColorRow({
    required this.label,
    required this.color,
    required this.presetColors,
    required this.colors,
    required this.theme,
    required this.onColorSelected,
  });

  final String label;
  final Color? color;
  final List<Color> presetColors;
  final ColorScheme colors;
  final ThemeData theme;
  final ValueChanged<Color> onColorSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color ?? colors.onSurface.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: colors.outline.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(label, style: theme.textTheme.bodyMedium),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: presetColors.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final c = presetColors[i];
              final isSelected =
                  color != null && color!.toARGB32() == c.toARGB32();
              return GestureDetector(
                onTap: () => onColorSelected(c),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: Colors.white, width: 2.5)
                        : null,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: c.withValues(alpha: 0.5),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: Colors.white,
                        )
                      : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
