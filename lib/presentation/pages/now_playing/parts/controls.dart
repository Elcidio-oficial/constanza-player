// ignore_for_file: deprecated_member_use, unused_local_variable, curly_braces_in_flow_control_structures, unused_element_parameter
part of '../now_playing_page.dart';

class _ProgressBar extends ConsumerWidget {
  const _ProgressBar({
    required this.theme,
    required this.colors,
    required this.accentColor,
  });
  final ThemeData theme;
  final ColorScheme colors;
  final Color accentColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(playerProvider.select((s) => s.progress));
    final position = ref.watch(playerProvider.select((s) => s.position));
    final duration = ref.watch(playerProvider.select((s) => s.duration));
    final positionFormatted = ref.watch(
      playerProvider.select((s) => s.positionFormatted),
    );
    final mediaBarStyle = ref.watch(
      themeProvider.select((s) => s.mediaBarStyle),
    );
    final songId = ref.watch(playerProvider.select((s) => s.currentSong?.id));
    final songUri = ref.watch(
      playerProvider.select((s) => s.currentSong?.uri ?? ''),
    );
    final isPlaying = ref.watch(playerProvider.select((s) => s.isPlaying));
    final waveform = ref.watch(waveformProvider(songUri)).value;
    // Remaining time as negative
    final remaining = duration - position;
    final remMin = remaining.inMinutes;
    final remSec = remaining.inSeconds.remainder(60).abs();
    final remStr = '-$remMin:${remSec.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        children: [
          MediaSeekBar(
            progress: progress.clamp(0.0, 1.0),
            style: mediaBarStyle,
            seed: songId.hashCode,
            waveform: waveform,
            position: position,
            animate: isPlaying,
            activeColor: accentColor,
            inactiveColor: colors.onSurface.withValues(alpha: 0.18),
            neutralColor: colors.onSurface,
            secondaryColor: colors.secondary,
            tertiaryColor: colors.tertiary,
            onSeek: (value) {
              ref
                  .read(playerProvider.notifier)
                  .seek(
                    Duration(
                      milliseconds: (value * duration.inMilliseconds).round(),
                    ),
                  );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  positionFormatted,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.4),
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                  ),
                ),
                Text(
                  remStr,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.4),
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// MAIN CONTROLS — with colored prev/next
// ============================================================

class _MainControls extends ConsumerWidget {
  const _MainControls({required this.colors, required this.accentColor});
  final ColorScheme colors;
  final Color accentColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlaying = ref.watch(playerProvider.select((s) => s.isPlaying));
    final shuffleEnabled = ref.watch(
      playerProvider.select((s) => s.shuffleEnabled),
    );
    final repeatMode = ref.watch(playerProvider.select((s) => s.repeatMode));
    final n = ref.read(playerProvider.notifier);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _accentIcon(
            Icons.shuffle_rounded,
            22,
            active: shuffleEnabled,
            onTap: n.toggleShuffle,
            activeColor: accentColor,
          ),
          _TapScaleWidget(
            onTap: n.previous,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: Icon(
                Icons.skip_previous_rounded,
                size: AppSpacing.iconXl,
                color: accentColor.withValues(alpha: 0.85),
              ),
            ),
          ),
          _PlayPauseBtn(
            isPlaying: isPlaying,
            onTap: n.togglePlayPause,
            colors: colors,
            accentColor: accentColor,
          ),
          _TapScaleWidget(
            onTap: n.next,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: Icon(
                Icons.skip_next_rounded,
                size: AppSpacing.iconXl,
                color: accentColor.withValues(alpha: 0.85),
              ),
            ),
          ),
          _accentIcon(
            repeatMode == RepeatMode.one
                ? Icons.repeat_one_rounded
                : Icons.repeat_rounded,
            22,
            active: repeatMode != RepeatMode.off,
            onTap: n.cycleRepeatMode,
            activeColor: accentColor,
          ),
        ],
      ),
    );
  }

  Widget _accentIcon(
    IconData icon,
    double size, {
    required bool active,
    VoidCallback? onTap,
    Color? activeColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Icon(
          icon,
          size: size,
          color: active
              ? (activeColor ?? accentColor)
              : colors.onSurface.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

// ── Play/Pause button with tap scale ──
class _PlayPauseBtn extends StatefulWidget {
  const _PlayPauseBtn({
    required this.isPlaying,
    required this.onTap,
    required this.colors,
    required this.accentColor,
  });
  final bool isPlaying;
  final VoidCallback onTap;
  final ColorScheme colors;
  final Color accentColor;

  @override
  State<_PlayPauseBtn> createState() => _PlayPauseBtnState();
}

class _PlayPauseBtnState extends State<_PlayPauseBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.88,
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
        widget.onTap();
      },
      onTapCancel: () => _c.forward(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) => Transform.scale(scale: _c.value, child: child),
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: widget.accentColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.accentColor.withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: AppConstants.fast,
            child: Icon(
              widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              key: ValueKey(widget.isPlaying),
              // 0.179 = ponto em que preto e branco têm o mesmo contraste
              // WCAG; 0.5 deixava ícone branco sobre fundos claros.
              color: widget.accentColor.computeLuminance() > 0.179
                  ? Colors.black
                  : Colors.white,
              size: 36,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// FAVORITE BUTTON
// ============================================================

class _FavoriteBtn extends ConsumerWidget {
  const _FavoriteBtn({required this.colors});
  final ColorScheme colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav = ref.watch(
      playerProvider.select((s) => s.currentSong?.isFavorite ?? false),
    );
    return GestureDetector(
      onTap: () => ref.read(playerProvider.notifier).toggleFavorite(),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, anim) =>
              ScaleTransition(scale: anim, child: child),
          child: Icon(
            isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            key: ValueKey(isFav),
            size: 26,
            color: isFav
                ? Colors.redAccent
                : colors.onSurface.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// SECONDARY ACTIONS — fila, letras, EQ, velocidade
// ============================================================

class _SecondaryActions extends ConsumerWidget {
  const _SecondaryActions({
    required this.colors,
    required this.theme,
    required this.accentColor,
  });
  final ColorScheme colors;
  final ThemeData theme;
  final Color accentColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _action(
            icon: Icons.queue_music_rounded,
            label: AppLocalizations.of(context).npTabQueue,
            onTap: () => Navigator.of(
              context,
            ).push(AppPageRoute(page: const _QueuePage())),
          ),
          _action(
            icon: Icons.lyrics_outlined,
            label: AppLocalizations.of(context).npTabLyrics,
            onTap: () {
              final song = ref.read(playerProvider).currentSong;
              if (song != null) {
                Navigator.of(
                  context,
                ).push(AppPageRoute(page: _LyricsPage(song: song)));
              }
            },
          ),
          Consumer(
            builder: (_, ref, __) {
              final s = ref.watch(audioSettingsProvider);
              final active = s.hasSleepTimer;
              return _action(
                icon: active ? Icons.bedtime_rounded : Icons.bedtime_outlined,
                label: active
                    ? _formatSleepTimerShort(context, s)
                    : AppLocalizations.of(context).sleepTimer,
                active: active,
                onTap: () => _showSleepSheet(context, ref),
                onLongPress: active
                    ? () => ref
                          .read(audioSettingsProvider.notifier)
                          .cancelSleepTimer()
                    : null,
              );
            },
          ),
          _action(
            icon: Icons.directions_car_rounded,
            label: AppLocalizations.of(context).carModeTitle,
            onTap: () => context.push('/car-mode'),
          ),
          Consumer(
            builder: (_, ref, __) {
              final eqOn = ref.watch(
                audioSettingsProvider.select((s) => s.eqEnabled),
              );
              final speed = ref.watch(
                audioSettingsProvider.select((s) => s.playbackSpeed),
              );
              final speedActive = (speed - 1.0).abs() > 0.01;
              return _action(
                icon: Icons.more_horiz_rounded,
                label: AppLocalizations.of(context).commonMore,
                active: eqOn || speedActive,
                onTap: () => _showMoreSheet(context, ref),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Formata o label do botão quando o timer está ativo (curto, p/ caber).
  String _formatSleepTimerShort(BuildContext context, AudioSettingsState s) {
    final l10n = AppLocalizations.of(context);
    if (s.sleepTimerEndOfTrack) return l10n.sleepTimerEndOfTrackShort;
    final endTime = s.sleepTimerEndTime;
    if (endTime == null) return l10n.sleepTimerOff;
    final remaining = endTime.difference(DateTime.now());
    if (remaining.isNegative) return l10n.sleepTimerOff;
    final m = remaining.inMinutes;
    final sec = remaining.inSeconds.remainder(60);
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  Widget _action({
    required IconData icon,
    required String label,
    bool active = false,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
  }) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xxs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 21,
              color: active
                  ? accentColor
                  : colors.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 10,
                color: active
                    ? accentColor
                    : colors.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Equalizer Bottom Sheet ──
  void _showEqSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => const _EqBottomSheet(),
    );
  }

  // ── Speed Bottom Sheet ──
  void _showSpeedSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _SpeedBottomSheet(),
    );
  }

  // ── Sleep Timer Bottom Sheet ──
  void _showSleepSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => const _SleepTimerBottomSheet(),
    );
  }

  // ── More Sheet (EQ + Velocidade) ──
  void _showMoreSheet(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final themeData = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.npMoreSheetTitle,
                style: themeData.textTheme.titleSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Consumer(
                builder: (_, cRef, __) {
                  final eqOn = cRef.watch(
                    audioSettingsProvider.select((s) => s.eqEnabled),
                  );
                  return ListTile(
                    leading: Icon(
                      Icons.equalizer_rounded,
                      color: eqOn
                          ? accentColor
                          : Colors.white.withValues(alpha: 0.7),
                    ),
                    title: Text(
                      l10n.npEqualizer,
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: eqOn
                        ? Icon(
                            Icons.check_rounded,
                            color: accentColor,
                            size: 18,
                          )
                        : null,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _showEqSheet(context, ref);
                    },
                  );
                },
              ),
              Consumer(
                builder: (_, cRef, __) {
                  final speed = cRef.watch(
                    audioSettingsProvider.select((s) => s.playbackSpeed),
                  );
                  final isCustom = (speed - 1.0).abs() > 0.01;
                  return ListTile(
                    leading: Icon(
                      Icons.speed_rounded,
                      color: isCustom
                          ? accentColor
                          : Colors.white.withValues(alpha: 0.7),
                    ),
                    title: Text(
                      l10n.npTabSpeed,
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: isCustom
                        ? Text(
                            '${speed.toStringAsFixed(speed == speed.roundToDouble() ? 1 : 2)}x',
                            style: TextStyle(
                              color: accentColor,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        : null,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _showSpeedSheet(context, ref);
                    },
                  );
                },
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// EQ BOTTOM SHEET — inline mini-EQ premium
// ============================================================
