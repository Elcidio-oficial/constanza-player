// ignore_for_file: curly_braces_in_flow_control_structures, unused_element_parameter
part of '../now_playing_page.dart';

class _EditView extends ConsumerStatefulWidget {
  const _EditView({required this.song});
  final Song song;

  @override
  ConsumerState<_EditView> createState() => _EditViewState();
}

class _EditViewState extends ConsumerState<_EditView> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final lines = ref.watch(lyricsProvider.select((s) => s.lines));
    final n = ref.read(lyricsProvider.notifier);

    if (lines.isEmpty) {
      return Center(
        child: Text(
          'Toque + para adicionar a primeira linha',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurface.withValues(alpha: 0.4),
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          color: colors.primary.withValues(alpha: 0.04),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: colors.onSurface.withValues(alpha: 0.3),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Toque no timestamp para sincronizar · Segure para limpar',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.35),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: lines.length,
            onReorder: n.reorderLines,
            itemBuilder: (_, i) {
              final line = lines[i];
              return _EditLineItem(
                key: ValueKey('line_${i}_${line.text}'),
                line: line,
                index: i,
                colors: colors,
                theme: theme,
                onEditText: (text) => n.updateLine(i, text: text),
                onSetTimestamp: () {
                  final pos = ref.read(playerProvider).position;
                  n.updateLine(i, timestamp: pos);
                },
                onClearTimestamp: () => n.updateLine(i, clearTimestamp: true),
                onDelete: () => n.removeLine(i),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EditLineItem extends StatefulWidget {
  const _EditLineItem({
    super.key,
    required this.line,
    required this.index,
    required this.colors,
    required this.theme,
    required this.onEditText,
    required this.onSetTimestamp,
    required this.onClearTimestamp,
    required this.onDelete,
  });
  final LyricLine line;
  final int index;
  final ColorScheme colors;
  final ThemeData theme;
  final ValueChanged<String> onEditText;
  final VoidCallback onSetTimestamp;
  final VoidCallback onClearTimestamp;
  final VoidCallback onDelete;

  @override
  State<_EditLineItem> createState() => _EditLineItemState();
}

class _EditLineItemState extends State<_EditLineItem> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.line.text);
  }

  @override
  void didUpdateWidget(_EditLineItem old) {
    super.didUpdateWidget(old);
    if (old.line.text != widget.line.text && _ctrl.text != widget.line.text)
      _ctrl.text = widget.line.text;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final t = widget.theme;
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onSetTimestamp,
            onLongPress: widget.onClearTimestamp,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
              child: Text(
                widget.line.formattedTimestamp,
                style: t.textTheme.labelSmall?.copyWith(
                  color: widget.line.isSynced
                      ? c.primary
                      : c.onSurface.withValues(alpha: 0.3),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _ctrl,
              onChanged: widget.onEditText,
              style: t.textTheme.bodyMedium,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.remove_circle_outline,
              size: 18,
              color: c.onSurface.withValues(alpha: 0.3),
            ),
            onPressed: widget.onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(
              Icons.drag_handle_rounded,
              size: 18,
              color: c.onSurface.withValues(alpha: 0.2),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// EMPTY STATE
// ============================================================

