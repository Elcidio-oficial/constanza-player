// ignore_for_file: deprecated_member_use, unused_local_variable, curly_braces_in_flow_control_structures, unused_element_parameter
part of '../now_playing_page.dart';

class _UpNextPreview extends ConsumerWidget {
  const _UpNextPreview({required this.colors, required this.theme});
  final ColorScheme colors;
  final ThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ps = ref.watch(playerProvider);
    if (!ps.hasNext ||
        ps.currentIndex < 0 ||
        ps.currentIndex + 1 >= ps.queue.length) {
      return const SizedBox(height: AppSpacing.xl);
    }
    final nextSong = ps.queue[ps.currentIndex + 1];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: GestureDetector(
        onTap: () => ref.read(playerProvider.notifier).next(),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: colors.onSurface.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.onSurface.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                ),
                child: Text(
                  'A SEGUIR',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.fadedText(0.35),
                    letterSpacing: 1.2,
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              ArtworkImage.song(
                songId: nextSong.numericId,
                size: 34,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      nextSong.title,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.65),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      nextSong.artist,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.fadedText(0.3),
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.skip_next_rounded,
                size: 18,
                color: colors.fadedText(0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// TAP SCALE ANIMATION WIDGET
// ============================================================

class _TapScaleWidget extends StatefulWidget {
  const _TapScaleWidget({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_TapScaleWidget> createState() => _TapScaleWidgetState();
}

class _TapScaleWidgetState extends State<_TapScaleWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.85,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _c.reverse(),
      onTapUp: (_) {
        _c.forward();
        widget.onTap?.call();
      },
      onTapCancel: () => _c.forward(),
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) => Transform.scale(scale: _c.value, child: child),
        child: widget.child,
      ),
    );
  }
}

// ============================================================
// LYRICS PAGE — Spotify-premium style com scroll inteligente
// ============================================================

// ============================================================
// QUEUE PAGE — fila funcional com reorder e remoção
// ============================================================

class _QueuePage extends ConsumerWidget {
  const _QueuePage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final ps = ref.watch(playerProvider);
    final n = ref.read(playerProvider.notifier);

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context).npQueueTitle(ps.queue.length),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w300,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (ps.queue.length > 1)
            IconButton(
              icon: const Icon(Icons.clear_all_rounded),
              tooltip: AppLocalizations.of(context).npQueueClear,
              onPressed: () => _confirmClear(context, n),
            ),
        ],
      ),
      body: ps.queue.isEmpty
          ? Center(
              child: Text(
                AppLocalizations.of(context).npQueueEmpty,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.fadedText(0.4),
                ),
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: 80),
              itemCount: ps.queue.length,
              proxyDecorator: (child, _, __) => Material(
                color: colors.surfaceContainer,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                elevation: 4,
                child: child,
              ),
              onReorder: (oldIdx, newIdx) => n.reorderQueue(oldIdx, newIdx),
              itemBuilder: (context, index) {
                final song = ps.queue[index];
                final isCurrent = song.id == ps.currentSong?.id;

                return Dismissible(
                  key: ValueKey('q_${song.id}_$index'),
                  direction: isCurrent
                      ? DismissDirection.none
                      : DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: AppSpacing.lg),
                    color: colors.error.withValues(alpha: 0.08),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      color: colors.error,
                    ),
                  ),
                  onDismissed: (_) => n.removeFromQueue(index),
                  child: _QueueItem(
                    song: song,
                    isCurrent: isCurrent,
                    colors: colors,
                    theme: theme,
                    onTap: () {
                      n.playSong(song, queue: ps.queue);
                      context.pop();
                    },
                  ),
                );
              },
            ),
    );
  }

  void _confirmClear(BuildContext context, PlayerNotifier n) {
    showDialog(
      context: context,
      builder: (ctx) {
        final colors = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: Text(AppLocalizations.of(ctx).npQueueClearTitle),
          content: Text(AppLocalizations.of(ctx).npQueueClearBody),
          actions: [
            TextButton(
              onPressed: () => ctx.pop(),
              child: Text(AppLocalizations.of(ctx).commonCancel),
            ),
            TextButton(
              onPressed: () {
                n.clearQueue();
                ctx.pop();
              },
              child: Text(
                AppLocalizations.of(ctx).npQueueClearAction,
                style: TextStyle(color: colors.error),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _QueueItem extends StatelessWidget {
  const _QueueItem({
    required this.song,
    required this.isCurrent,
    required this.colors,
    required this.theme,
    required this.onTap,
  });

  final Song song;
  final bool isCurrent;
  final ColorScheme colors;
  final ThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isCurrent ? null : onTap,
      child: Container(
        color: isCurrent ? colors.primary.withValues(alpha: 0.06) : null,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Icon(
                Icons.drag_handle_rounded,
                size: 20,
                color: isCurrent
                    ? colors.primary.withValues(alpha: 0.4)
                    : colors.onSurface.withValues(alpha: 0.2),
              ),
            ),
            // Artwork + equalizer overlay
            Stack(
              children: [
                ArtworkImage.song(
                  songId: song.numericId,
                  size: 44,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                if (isCurrent)
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.equalizer_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: AppSpacing.sm),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: isCurrent ? colors.primary : colors.onSurface,
                      fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    song.artist,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.fadedText(0.45),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Text(
              song.durationFormatted,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.fadedText(0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// MINIMALIST ALBUM ART — clean, no shadows, thin border
// ============================================================
