import 'package:flutter/material.dart';
import 'package:constanza_player/core/theme/app_spacing.dart';
import 'package:constanza_player/core/theme/color_scheme_x.dart';
import 'package:constanza_player/l10n/gen/app_localizations.dart';

/// Escolha feita no seletor. `columns == null` significa "Auto".
typedef ColumnsChoice = ({int? columns});

/// Bottom sheet para escolher o número de colunas da grade (1–5) ou "Auto".
///
/// Devolve `null` se o utilizador fechar sem aplicar — distinto de escolher
/// Auto (`(columns: null)`). Antes os dois eram `null` e fechar a folha
/// repunha a grade em Auto sem querer.
Future<ColumnsChoice?> showColumnsPicker({
  required BuildContext context,
  required int? current,
  bool circular = false,
}) {
  return showModalBottomSheet<ColumnsChoice>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _ColumnsPickerSheet(current: current, circular: circular),
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

/// Colunas do modo Auto para uma largura de ecrã (dp). Fonte única: usada
/// pelas grades de Artistas e Álbuns e pela pré-visualização do seletor.
int autoGridColumns(double width) => width < 380
    ? 2
    : width < 600
    ? 3
    : width < 900
    ? 4
    : 5;

class _ColumnsPickerSheet extends StatefulWidget {
  const _ColumnsPickerSheet({required this.current, required this.circular});
  final int? current;
  final bool circular;

  @override
  State<_ColumnsPickerSheet> createState() => _ColumnsPickerSheetState();
}

class _ColumnsPickerSheetState extends State<_ColumnsPickerSheet> {
  late int? _selected = widget.current;

  static const _options = <int?>[null, 1, 2, 3, 4, 5];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final previewColumns = _selected ?? autoGridColumns(screenWidth);

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
      ),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.onSurface.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.gridLayoutTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.gridLayoutSubtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.fadedText(0.55),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // ── Pré-visualização ao vivo ──
              Container(
                height: 168,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOut,
                  child: _GridPreview(
                    key: ValueKey(previewColumns),
                    columns: previewColumns,
                    circular: widget.circular,
                    color: colors.primary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // ── Seletor: Auto, 1…5 em segmentos iguais ──
              Row(
                children: [
                  for (final (i, option) in _options.indexed) ...[
                    if (i > 0) const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: _OptionSegment(
                        label: option == null ? l10n.gridAuto : '$option',
                        columns: option ?? 3,
                        isAuto: option == null,
                        selected: _selected == option,
                        onTap: () => setState(() => _selected = option),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Text(
                  _selected == null
                      ? l10n.gridAutoHint
                      : l10n.gridColumnsHint(_selected!),
                  key: ValueKey(_selected),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.fadedText(0.55),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: () =>
                      Navigator.of(context).pop((columns: _selected)),
                  child: Text(
                    l10n.gridApply,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Segmento do seletor: mini-ícone de colunas + rótulo.
class _OptionSegment extends StatelessWidget {
  const _OptionSegment({
    required this.label,
    required this.columns,
    required this.isAuto,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int columns;
  final bool isAuto;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final fg = selected ? colors.onPrimary : colors.onSurface;
    final radius = BorderRadius.circular(AppSpacing.radiusMd);

    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: Material(
        color: selected
            ? colors.primary
            : colors.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: SizedBox(
            height: 64,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 26,
                  height: 18,
                  child: isAuto
                      ? Icon(Icons.auto_awesome_rounded, size: 18, color: fg)
                      : _ColumnBars(
                          columns: columns,
                          color: fg.withValues(alpha: selected ? 1 : 0.55),
                        ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Barras verticais que desenham N colunas num espaço fixo.
class _ColumnBars extends StatelessWidget {
  const _ColumnBars({required this.columns, required this.color});
  final int columns;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < columns; i++) ...[
          if (i > 0) const SizedBox(width: 2),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Grade de exemplo (capa + legenda), dimensionada a partir do espaço
/// disponível: nunca transborda, seja 1 ou 6 colunas.
class _GridPreview extends StatelessWidget {
  const _GridPreview({
    super.key,
    required this.columns,
    required this.circular,
    required this.color,
  });

  final int columns;
  final bool circular;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        const gap = 8.0;
        final cellWidth = (c.maxWidth - gap * (columns - 1)) / columns;
        // Capa quadrada + 2 linhas de legenda; com poucas colunas a capa
        // limita-se à altura disponível.
        final captionH = (cellWidth * 0.22).clamp(6.0, 16.0);
        final art = (c.maxHeight - captionH - 4).clamp(0.0, cellWidth);
        // Quantas linhas inteiras cabem: com 4–5 colunas uma só linha
        // deixava metade do painel vazio.
        final cellH = art + 4 + captionH;
        final rows = ((c.maxHeight + gap) / (cellH + gap)).floor().clamp(1, 3);

        return ClipRect(
          child: Column(
            children: [
              for (int r = 0; r < rows; r++) ...[
                if (r > 0) const SizedBox(height: gap),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int i = 0; i < columns; i++) ...[
                      if (i > 0) const SizedBox(width: gap),
                      SizedBox(
                        width: cellWidth,
                        child: Column(
                          crossAxisAlignment: circular
                              ? CrossAxisAlignment.center
                              : CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: art,
                              height: art,
                              decoration: BoxDecoration(
                                color: color.withValues(
                                  alpha: 0.28 + 0.06 * ((i + r) % 3),
                                ),
                                shape: circular
                                    ? BoxShape.circle
                                    : BoxShape.rectangle,
                                borderRadius: circular
                                    ? null
                                    : BorderRadius.circular(
                                        (art * 0.08).clamp(3.0, 12.0),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            FractionallySizedBox(
                              widthFactor: 0.8,
                              child: Container(
                                height: captionH * 0.45,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            SizedBox(height: captionH * 0.15),
                            FractionallySizedBox(
                              widthFactor: 0.5,
                              child: Container(
                                height: captionH * 0.35,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
