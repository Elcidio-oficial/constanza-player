// ignore_for_file: curly_braces_in_flow_control_structures, unused_element_parameter
part of '../now_playing_page.dart';

class _LyricsMiniPlayer extends ConsumerWidget {
  const _LyricsMiniPlayer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = ref.watch(playerProvider.select((s) => s.currentSong));
    if (song == null) return const SizedBox.shrink();

    final isPlaying = ref.watch(playerProvider.select((s) => s.isPlaying));
    final position = ref.watch(playerProvider.select((s) => s.position));
    final duration = ref.watch(playerProvider.select((s) => s.duration));
    final shuffleOn = ref.watch(
      playerProvider.select((s) => s.shuffleEnabled),
    );
    final palette = ref.watch(artworkPaletteProvider);
    final isFavorite = ref.watch(
      libraryProvider.select(
        (s) => s.songs.any((x) => x.id == song.id && x.isFavorite),
      ),
    );

    final accent = palette?.vibrant ?? Theme.of(context).colorScheme.primary;
    final durMs = duration.inMilliseconds.clamp(1, 1 << 30);
    final progress = (position.inMilliseconds / durMs).clamp(0.0, 1.0);
    final remaining = duration - position;

    String fmt(Duration d) {
      final m = d.inMinutes;
      final s = d.inSeconds.remainder(60);
      return '$m:${s.toString().padLeft(2, '0')}';
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
          AppSpacing.xs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Linha 1: título/artista + favorito ──
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _MiniIconBtn(
                  icon: isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isFavorite
                      ? accent
                      : Colors.white.withValues(alpha: 0.75),
                  size: 22,
                  onTap: () =>
                      ref.read(playerProvider.notifier).toggleFavorite(),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // ── Linha 2: slider fino ──
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                activeTrackColor: accent,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
                thumbColor: accent,
                overlayColor: accent.withValues(alpha: 0.15),
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 5,
                ),
                overlayShape: const RoundSliderOverlayShape(
                  overlayRadius: 12,
                ),
              ),
              child: Slider(
                value: progress,
                onChanged: (v) {
                  if (duration.inMilliseconds > 0) {
                    ref
                        .read(playerProvider.notifier)
                        .seek(
                          Duration(
                            milliseconds:
                                (v * duration.inMilliseconds).round(),
                          ),
                        );
                  }
                },
              ),
            ),
            // ── Linha 3: tempos ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    fmt(position),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    '-${fmt(remaining.isNegative ? Duration.zero : remaining)}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // ── Linha 4: transport ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _MiniIconBtn(
                  icon: Icons.shuffle_rounded,
                  color: shuffleOn
                      ? accent
                      : Colors.white.withValues(alpha: 0.75),
                  size: 22,
                  onTap: () =>
                      ref.read(playerProvider.notifier).toggleShuffle(),
                ),
                _MiniIconBtn(
                  icon: Icons.skip_previous_rounded,
                  color: Colors.white,
                  size: 30,
                  onTap: () => ref.read(playerProvider.notifier).previous(),
                ),
                _MiniPlayButton(
                  isPlaying: isPlaying,
                  accent: accent,
                  onTap: () =>
                      ref.read(playerProvider.notifier).togglePlayPause(),
                ),
                _MiniIconBtn(
                  icon: Icons.skip_next_rounded,
                  color: Colors.white,
                  size: 30,
                  onTap: () => ref.read(playerProvider.notifier).next(),
                ),
                _MiniIconBtn(
                  icon: Icons.graphic_eq_rounded,
                  color: Colors.white.withValues(alpha: 0.75),
                  size: 22,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniIconBtn extends StatelessWidget {
  const _MiniIconBtn({
    required this.icon,
    required this.color,
    required this.onTap,
    this.size = 24,
  });
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 24,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, color: color, size: size),
      ),
    );
  }
}

class _MiniPlayButton extends StatelessWidget {
  const _MiniPlayButton({
    required this.isPlaying,
    required this.accent,
    required this.onTap,
  });
  final bool isPlaying;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: accent,
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.45),
              blurRadius: 22,
              spreadRadius: -2,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: Colors.white,
          size: 30,
        ),
      ),
    );
  }
}

// ============================================================
// VIEW MODE — Spotify-premium: linha atual centralizada, bold,
// linhas anteriores sobem com fade, tap-to-seek
// ============================================================

