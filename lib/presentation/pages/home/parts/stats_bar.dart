// ignore_for_file: curly_braces_in_flow_control_structures, unused_element_parameter
part of '../home_page.dart';

class _LibraryStatsBar extends StatelessWidget {
  const _LibraryStatsBar({
    required this.songCount,
    required this.albumCount,
    required this.artistCount,
    required this.durationLabel,
    required this.colors,
    required this.theme,
  });
  final int songCount;
  final int albumCount;
  final int artistCount;
  final String durationLabel;
  final ColorScheme colors;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: colors.onSurface.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: colors.outline.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatItem(
              value: '$songCount',
              label: l10n.homeStatsSongs,
              colors: colors,
              theme: theme,
            ),
            Container(
              width: 1,
              height: 24,
              color: colors.outline.withValues(alpha: 0.1),
            ),
            _StatItem(
              value: '$albumCount',
              label: l10n.homeStatsAlbums,
              colors: colors,
              theme: theme,
            ),
            Container(
              width: 1,
              height: 24,
              color: colors.outline.withValues(alpha: 0.1),
            ),
            _StatItem(
              value: '$artistCount',
              label: l10n.homeStatsArtists,
              colors: colors,
              theme: theme,
            ),
            Container(
              width: 1,
              height: 24,
              color: colors.outline.withValues(alpha: 0.1),
            ),
            _StatItem(
              value: durationLabel,
              label: l10n.homeStatsDuration,
              colors: colors,
              theme: theme,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.value,
    required this.label,
    required this.colors,
    required this.theme,
  });
  final String value;
  final String label;
  final ColorScheme colors;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.fadedText(0.35),
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// PULSING DOT — animated indicator
// ============================================================

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});
  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    // Pulsa 3 vezes ao aparecer e para aceso. Um pulso infinito obriga o
    // Impeller (sem cache de raster) a redesenhar a tela inteira a 60 fps
    // enquanto a música toca — ~1/3 de um núcleo só para este ponto.
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _ctrl.repeat(reverse: true, count: 6).whenComplete(() {
      if (mounted) _ctrl.value = 1;
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // Opacidade animada pelo compositor (FadeTransition) numa camada própria:
  // o ponto pulsa sem redesenhar o cartão — antes cada quadro repintava o
  // cartão inteiro (sombras, gradiente) a 60 fps enquanto a música tocava.
  late final Animation<double> _opacity = Tween(
    begin: 0.5,
    end: 1.0,
  ).animate(_ctrl);

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: FadeTransition(
        opacity: _opacity,
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// STANDARD SONG CARD (unchanged from original)
// ============================================================
