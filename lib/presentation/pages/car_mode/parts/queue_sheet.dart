part of '../car_mode_page.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Queue Bottom Sheet
// ──────────────────────────────────────────────────────────────────────────────

class _QueueSheet extends ConsumerWidget {
  const _QueueSheet({
    required this.player,
    required this.accent,
    required this.l10n,
  });

  final PlayerState player;
  final Color accent;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = player.queue;
    final currentIdx = player.currentIndex;
    final upcoming = currentIdx >= 0
        ? queue.skip(currentIdx + 1).toList()
        : queue;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.65,
          ),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surface.withValues(alpha: 0.88),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.08),
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(Icons.queue_music_rounded, color: accent, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      l10n.carModeQueueTitle,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${upcoming.length}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.fadedText(0.35),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (upcoming.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    l10n.carModeQueueEmpty,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.fadedText(0.35),
                      fontSize: 14,
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 20),
                    itemCount: upcoming.length,
                    itemBuilder: (context, i) {
                      final s = upcoming[i];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 2,
                        ),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: ArtworkImage.song(
                            songId: s.numericId,
                            size: 44,
                            placeholderIcon: Icons.music_note_rounded,
                            placeholderIconSize: 20,
                          ),
                        ),
                        title: Text(
                          s.title,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          s.artist,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.fadedText(0.4),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          '${i + 1}',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.fadedText(0.25),
                            fontSize: 13,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          final globalIdx = currentIdx + 1 + i;
                          if (globalIdx < queue.length) {
                            ref
                                .read(playerProvider.notifier)
                                .playIndex(globalIdx);
                          }
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
