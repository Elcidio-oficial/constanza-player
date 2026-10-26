// ignore_for_file: deprecated_member_use, unused_local_variable, curly_braces_in_flow_control_structures, unused_element_parameter
part of '../now_playing_page.dart';

class _AnalysisBadge extends ConsumerWidget {
  const _AnalysisBadge({required this.colors});
  final ColorScheme colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analysis = ref.watch(audioAnalysisProvider);
    final onlineResult = analysis.result;
    final isLoading = analysis.isLoading;
    final song = ref.watch(playerProvider.select((s) => s.currentSong));

    // Dispara análise para a música atual (nativa sempre; online se tiver credenciais)
    if (song != null && !isLoading && analysis.songId != song.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(audioAnalysisProvider.notifier)
            .analyzeSong(
              song.id,
              song.uri,
              title: song.title,
              artist: song.artist,
            );
      });
    }

    if (!analysis.hasAnyData && !isLoading && !analysis.failed)
      return const SizedBox.shrink();

    // Carregando — ainda sem nenhum dado
    if (!analysis.hasAnyData && isLoading) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: colors.onSurface.withValues(alpha: 0.25),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              AppLocalizations.of(context).npAnalyzeLoading,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.3),
                fontSize: 10,
              ),
            ),
          ],
        ),
      );
    }

    // Falha — mostra botão de retry
    if (!analysis.hasAnyData && analysis.failed) {
      final currentSong = ref.read(playerProvider).currentSong;
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: GestureDetector(
          onTap: currentSong != null
              ? () => ref
                    .read(audioAnalysisProvider.notifier)
                    .retry(
                      currentSong.id,
                      currentSong.uri,
                      title: currentSong.title,
                      artist: currentSong.artist,
                    )
              : null,
          child: Row(
            children: [
              Icon(
                Icons.refresh_rounded,
                size: 12,
                color: colors.onSurface.withValues(alpha: 0.3),
              ),
              const SizedBox(width: 4),
              Text(
                AppLocalizations.of(context).npAnalyzeRetry,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.3),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Derivados para exibição
    final displayBpm = analysis.bpm;
    final displayKey = analysis.key;
    final displayScale = analysis.scale;
    final displayCamelot = analysis.camelotCode;

    final hasBpm = displayBpm != null && displayBpm > 0;
    final hasKey =
        displayKey != null && displayKey.isNotEmpty && displayScale != null;

    final bpmLabel = hasBpm ? '$displayBpm BPM' : '';
    final keyLabel = hasKey
        ? () {
            final scaleLabel = displayScale == 'Major'
                ? AppLocalizations.of(context).npScaleMajor
                : AppLocalizations.of(context).npScaleMinor;
            final base = '$displayKey $scaleLabel';
            return displayCamelot != null ? '$base ($displayCamelot)' : base;
          }()
        : '';

    final energyCategory = () {
      final l10n = AppLocalizations.of(context);
      if (displayBpm == null) return '';
      if (displayBpm < 80) return l10n.npEnergyRelaxing;
      if (displayBpm < 110) return l10n.npEnergyModerate;
      if (displayBpm < 140) return l10n.npEnergyEnergetic;
      return l10n.npEnergyIntense;
    }();

    if (!hasBpm && !hasKey && !isLoading) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Linha 1: BPM + Key + Energia ───
          Row(
            children: [
              if (hasBpm)
                _buildChip(
                  context,
                  icon: Icons.speed_rounded,
                  label: bpmLabel,
                  color: colors.primary,
                ),
              if (hasBpm && hasKey) const SizedBox(width: 5),
              if (hasKey)
                _buildChip(
                  context,
                  icon: Icons.music_note_rounded,
                  label: keyLabel,
                  color: colors.tertiary,
                ),
              if (hasBpm) ...[
                const SizedBox(width: 5),
                _buildChip(
                  context,
                  label: energyCategory,
                  color: colors.onSurface,
                  subtle: true,
                ),
              ],
              if (isLoading) ...[
                const SizedBox(width: 6),
                SizedBox(
                  width: 8,
                  height: 8,
                  child: CircularProgressIndicator(
                    strokeWidth: 1,
                    color: colors.onSurface.withValues(alpha: 0.2),
                  ),
                ),
              ],
            ],
          ),
          // ─── Linha 2: Energy/Dance/Happiness (só se online disponível) ───
          if (onlineResult != null &&
              (onlineResult.hasEnergyData ||
                  onlineResult.danceability != null)) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                if (onlineResult.energy != null)
                  _buildMiniStat(
                    context,
                    icon: Icons.local_fire_department_rounded,
                    label: 'Energia ${onlineResult.energyPercent}',
                    color: Colors.deepOrange,
                  ),
                if (onlineResult.energy != null &&
                    onlineResult.danceability != null)
                  const SizedBox(width: 8),
                if (onlineResult.danceability != null)
                  _buildMiniStat(
                    context,
                    icon: Icons.nightlife_rounded,
                    label: 'Dança ${onlineResult.danceabilityPercent}',
                    color: Colors.purpleAccent,
                  ),
                if (onlineResult.danceability != null &&
                    onlineResult.happiness != null)
                  const SizedBox(width: 8),
                if (onlineResult.happiness != null)
                  _buildMiniStat(
                    context,
                    icon: Icons.sentiment_very_satisfied_rounded,
                    label: '${(onlineResult.happiness! * 100).round()}%',
                    color: Colors.amber,
                  ),
              ],
            ),
          ],
          // ─── Fonte dos dados ───
          if (analysis.sourceLabel.isNotEmpty) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(
                  analysis.hasNativeData && !analysis.hasOnlineData
                      ? Icons.memory_rounded
                      : Icons.cloud_done_rounded,
                  size: 8,
                  color: colors.onSurface.withValues(alpha: 0.2),
                ),
                const SizedBox(width: 3),
                Text(
                  analysis.sourceLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.2),
                    fontSize: 8,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChip(
    BuildContext context, {
    IconData? icon,
    required String label,
    required Color color,
    bool confirmed = false,
    bool subtle = false,
  }) {
    if (label.isEmpty) return const SizedBox.shrink();
    final bgAlpha = subtle ? 0.06 : 0.12;
    final fgAlpha = subtle ? 0.4 : 0.8;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: bgAlpha),
        borderRadius: BorderRadius.circular(20),
        border: confirmed
            ? Border.all(color: color.withValues(alpha: 0.3), width: 0.5)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color.withValues(alpha: 0.7)),
            const SizedBox(width: 4),
          ],
          if (confirmed) ...[
            Icon(
              Icons.verified_rounded,
              size: 9,
              color: color.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color.withValues(alpha: fgAlpha),
              fontWeight: subtle ? FontWeight.w500 : FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: color.withValues(alpha: 0.5)),
        const SizedBox(width: 3),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colors.onSurface.withValues(alpha: 0.35),
            fontSize: 9,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
