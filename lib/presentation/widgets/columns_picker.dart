import 'package:flutter/material.dart';
import 'package:constanza_player/core/theme/app_spacing.dart';

/// Mostra um bottom sheet premium para escolher o número de colunas
/// da grade (1–5) ou "Auto" (responsivo). Retorna `null` para Auto.
Future<int?> showColumnsPicker({
  required BuildContext context,
  required int? current,
}) {
  return showModalBottomSheet<int?>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _ColumnsPickerSheet(current: current),
  );
}

/// Ícone que representa o estado atual da grade na AppBar.
IconData columnsIconFor(int? columns) {
  switch (columns) {
    case 1:
      return Icons.view_agenda_rounded;
    case 2:
      return Icons.grid_view_rounded;
    case 3:
      return Icons.grid_on_rounded;
    case 4:
      return Icons.apps_rounded;
    case 5:
      return Icons.dashboard_rounded;
    default:
      return Icons.auto_awesome_mosaic_rounded;
  }
}

class _ColumnsPickerSheet extends StatefulWidget {
  const _ColumnsPickerSheet({required this.current});
  final int? current;

  @override
  State<_ColumnsPickerSheet> createState() => _ColumnsPickerSheetState();
}

class _ColumnsPickerSheetState extends State<_ColumnsPickerSheet> {
  late int? _selected = widget.current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.sm,
        bottom: AppSpacing.lg + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.onSurface.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Layout da grade',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Escolha quantas colunas exibir',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _OptionTile(
            icon: Icons.auto_awesome_mosaic_rounded,
            label: 'Automático',
            hint: 'Adapta à largura da tela',
            selected: _selected == null,
            preview: const _GridPreview(columns: 3, dense: true),
            onTap: () => _pick(null),
          ),
          const SizedBox(height: AppSpacing.sm),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1.15,
            children: [
              for (int c = 1; c <= 5; c++)
                _ColumnTile(
                  columns: c,
                  selected: _selected == c,
                  onTap: () => _pick(c),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _pick(int? value) {
    setState(() => _selected = value);
    Navigator.of(context).pop(value);
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.label,
    required this.hint,
    required this.selected,
    required this.preview,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String hint;
  final bool selected;
  final Widget preview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: selected
          ? colors.primary.withValues(alpha: 0.12)
          : colors.surfaceContainerHigh.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(
              color: selected
                  ? colors.primary.withValues(alpha: 0.6)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Icon(icon, color: colors.primary, size: 22),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      hint,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 56, height: 40, child: preview),
              const SizedBox(width: AppSpacing.xs),
              if (selected)
                Icon(Icons.check_circle_rounded, color: colors.primary)
              else
                Icon(
                  Icons.radio_button_unchecked_rounded,
                  color: colors.onSurface.withValues(alpha: 0.25),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColumnTile extends StatelessWidget {
  const _ColumnTile({
    required this.columns,
    required this.selected,
    required this.onTap,
  });
  final int columns;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: selected
          ? colors.primary.withValues(alpha: 0.12)
          : colors.surfaceContainerHigh.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(
              color: selected
                  ? colors.primary.withValues(alpha: 0.6)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Expanded(child: _GridPreview(columns: columns)),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                '$columns col${columns == 1 ? '' : 's'}',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: selected ? colors.primary : colors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GridPreview extends StatelessWidget {
  const _GridPreview({required this.columns, this.dense = false});
  final int columns;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final cellColor = colors.primary.withValues(alpha: 0.55);
    return LayoutBuilder(
      builder: (_, c) {
        final gap = dense ? 2.0 : 3.0;
        final totalGap = gap * (columns - 1);
        final cell = (c.maxWidth - totalGap) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (int i = 0; i < columns * 2; i++)
              Container(
                width: cell,
                height: cell * 0.62,
                decoration: BoxDecoration(
                  color: cellColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        );
      },
    );
  }
}
