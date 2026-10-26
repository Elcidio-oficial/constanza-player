// ignore_for_file: deprecated_member_use, unused_local_variable, curly_braces_in_flow_control_structures, unused_element_parameter
part of '../now_playing_page.dart';

/// Fecha o Now Playing. Quando aberto normalmente (push sobre o /home) faz um
/// pop simples. Quando aberto via deeplink/intent externo (`router.go`), a
/// pilha contém SÓ o Now Playing — um `pop()` aqui esvazia o Navigator e deixa
/// a tela preta; nesse caso caímos no /home.
void dismissNowPlaying(BuildContext context) {
  final nav = Navigator.of(context);
  if (nav.canPop()) {
    nav.pop();
  } else {
    context.go('/home');
  }
}

/// Public entry-point para abrir a Fila de fora do NowPlayingPage
/// (deeplink do widget de ecrã inicial).
void openQueuePage(BuildContext context) {
  Navigator.of(context).push(AppPageRoute(page: const _QueuePage()));
}

/// Public entry-point para abrir o sheet de fora do NowPlayingPage
/// (deeplinks de widget, atalhos, etc).
void showSleepTimerSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => const _SleepTimerBottomSheet(),
  );
}

class _SleepTimerBottomSheet extends ConsumerStatefulWidget {
  const _SleepTimerBottomSheet();

  @override
  ConsumerState<_SleepTimerBottomSheet> createState() =>
      _SleepTimerBottomSheetState();
}

class _SleepTimerBottomSheetState
    extends ConsumerState<_SleepTimerBottomSheet> {
  static const _presets = [5, 10, 15, 30, 45, 60, 90];

  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    // Tick a cada segundo p/ atualizar o display do tempo restante.
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }

  String _remainingDisplay(AudioSettingsState s, AppLocalizations l10n) {
    if (s.sleepTimerEndOfTrack) return l10n.sleepTimerEndOfTrackShort;
    final endTime = s.sleepTimerEndTime;
    if (endTime == null) return l10n.sleepTimerOff;
    final remaining = endTime.difference(DateTime.now());
    if (remaining.isNegative) return l10n.sleepTimerOff;
    final m = remaining.inMinutes;
    final sec = remaining.inSeconds.remainder(60);
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(audioSettingsProvider);
    final notifier = ref.read(audioSettingsProvider.notifier);
    final baseColors = Theme.of(context).colorScheme;
    final colors = baseColors.brightness == Brightness.dark
        ? baseColors
        : ColorScheme.dark(primary: baseColors.primary);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final active = s.hasSleepTimer;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
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
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Big display
            Text(
              _remainingDisplay(s, l10n),
              style: theme.textTheme.displaySmall?.copyWith(
                color: active ? colors.primary : Colors.white,
                fontWeight: FontWeight.w300,
                letterSpacing: -1,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              l10n.sleepTimerSubtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Preset chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                alignment: WrapAlignment.center,
                children: [
                  for (final m in _presets)
                    _chip(
                      context,
                      label: l10n.sleepTimerMinutesShort(m),
                      selected:
                          !s.sleepTimerEndOfTrack && s.sleepTimerMinutes == m,
                      onTap: () => notifier.setSleepTimer(m),
                    ),
                  _chip(
                    context,
                    label: l10n.sleepTimerEndOfTrack,
                    selected: s.sleepTimerEndOfTrack,
                    onTap: notifier.setSleepTimerEndOfTrack,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Fade out toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.sleepTimerFadeOut,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.sleepTimerFadeOutDesc,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: s.sleepTimerFadeOut,
                    activeTrackColor: colors.primary,
                    onChanged: notifier.setFadeOut,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Cancel button (only when active)
            if (active) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () {
                      notifier.cancelSleepTimer();
                      Navigator.of(context).pop();
                    },
                    icon: Icon(
                      Icons.timer_off_outlined,
                      color: Colors.white.withValues(alpha: 0.7),
                      size: 18,
                    ),
                    label: Text(
                      l10n.sleepTimerCancel,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusFull,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  Widget _chip(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? colors.primary
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(
            color: selected
                ? colors.primary
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: selected
                ? colors.onPrimary
                : Colors.white.withValues(alpha: 0.7),
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// UP NEXT PREVIEW — polished with transition
// ============================================================

class _SleepTimerCircle extends StatelessWidget {
  const _SleepTimerCircle({
    required this.endTime,
    required this.totalMinutes,
    required this.color,
  });

  final DateTime? endTime;
  final int totalMinutes;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (endTime == null || totalMinutes <= 0) {
      return Icon(
        Icons.bedtime_rounded,
        size: 10,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
      );
    }

    final now = DateTime.now();
    final total = Duration(minutes: totalMinutes);
    final remaining = endTime!.difference(now);
    final progress = remaining.inSeconds <= 0
        ? 0.0
        : (remaining.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);

    return SizedBox(
      width: 14,
      height: 14,
      child: CustomPaint(
        painter: _TimerCirclePainter(
          progress: progress,
          color: color,
          trackAlpha: 0.15,
        ),
        child: Center(
          child: Icon(
            Icons.bedtime_rounded,
            size: 7,
            color: color.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }
}

class _TimerCirclePainter extends CustomPainter {
  _TimerCirclePainter({
    required this.progress,
    required this.color,
    this.trackAlpha = 0.15,
  });

  final double progress;
  final Color color;
  final double trackAlpha;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1;
    const strokeWidth = 1.5;
    const startAngle = -1.5708; // -π/2 (top)

    // Track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withValues(alpha: trackAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    // Progress arc
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        progress * 2 * 3.14159265,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_TimerCirclePainter old) =>
      old.progress != progress || old.color != color;
}

// ============================================================
// ANALYSIS BADGE — BPM + Key/Scale + Camelot + Energy under song info
// ============================================================
