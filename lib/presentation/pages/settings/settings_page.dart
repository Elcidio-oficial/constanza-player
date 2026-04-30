import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:constanza_player/l10n/gen/app_localizations.dart';
import 'package:constanza_player/core/constants/app_constants.dart';
import 'package:constanza_player/core/theme/app_spacing.dart';
import 'package:constanza_player/core/theme/app_backgrounds.dart';
import 'package:constanza_player/services/crash_reporter.dart';
import 'package:constanza_player/services/backup_service.dart';
import 'package:constanza_player/services/permission_service.dart';
import 'package:constanza_player/core/utils/background_helper.dart';
import 'package:constanza_player/presentation/providers/theme_provider.dart';
import 'package:constanza_player/presentation/providers/audio_settings_provider.dart';
import 'package:constanza_player/presentation/providers/player_provider.dart';
import 'package:constanza_player/presentation/providers/library_provider.dart';
import 'package:constanza_player/presentation/providers/artwork_provider.dart';
import 'package:constanza_player/presentation/pages/settings/background_settings_page.dart';
import 'package:constanza_player/presentation/pages/settings/equalizer_page.dart';
import 'package:constanza_player/presentation/pages/library/duplicates_page.dart';
import 'package:constanza_player/core/utils/app_page_route.dart';
import 'package:go_router/go_router.dart';

/// Página de Configurações — personalização completa do Constanza.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final themeState = ref.watch(themeProvider);
    final audioState = ref.watch(audioSettingsProvider);
    final libState = ref.watch(libraryProvider);
    final accentColor = ref.watch(artworkPaletteProvider)?.dominant;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: BackgroundHelper.scaffoldColor(colors, themeState),
      appBar: AppBar(
        backgroundColor: BackgroundHelper.appBarColor(colors, themeState),
        title: Text(
          l10n.navSettings,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w300,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(
          top: AppSpacing.xs,
          bottom: AppSpacing.xxl,
        ),
        children: [
          // ========================================
          // APARÊNCIA
          // ========================================
          _SectionHeader(
            title: l10n.settingsAppearance,
            theme: theme,
            colors: colors,
          ),
          _SettingsGroup(
            colors: colors,
            children: [
              _SettingsTile(
                icon: Icons.wallpaper_outlined,
                title: l10n.settingsAppBackground,
                subtitle: switch (themeState.backgroundType) {
                  BackgroundType.none => l10n.settingsBackgroundOff,
                  BackgroundType.gradient =>
                    themeState.currentGradient?.name ??
                        l10n.settingsBackgroundGradient,
                  BackgroundType.image => l10n.settingsBackgroundCustomImage,
                },
                colors: colors,
                theme: theme,
                onTap: () => Navigator.push(
                  context,
                  AppPageRoute(page: const BackgroundSettingsPage()),
                ),
              ),
            ],
          ),

          // ========================================
          // TEMAS PRÉ-DEFINIDOS
          // ========================================
          _SectionHeader(
            title: l10n.settingsThemes,
            theme: theme,
            colors: colors,
          ),
          SizedBox(
            height: 120,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              scrollDirection: Axis.horizontal,
              itemCount: ThemePresets.all.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final preset = ThemePresets.all[index];
                return GestureDetector(
                  onTap: () {
                    ref.read(themeProvider.notifier).applyThemePreset(preset);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.snackbarThemeApplied(preset.name)),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Container(
                    width: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: preset.previewColors,
                      ),
                      border: Border.all(
                        color: colors.outline.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(preset.icon, color: Colors.white, size: 28),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(15),
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                preset.name,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // ========================================
          // INTERFACE
          // ========================================
          _SectionHeader(
            title: l10n.settingsInterface,
            theme: theme,
            colors: colors,
          ),
          _SettingsGroup(
            colors: colors,
            children: [
              _SettingsTile(
                icon: Icons.play_circle_outline_rounded,
                title: l10n.settingsNowPlayingStyle,
                subtitle: themeState.nowPlayingStyleLabel(l10n),
                colors: colors,
                theme: theme,
                onTap: () => _showNowPlayingStyleDialog(context, ref),
              ),
              _divider(colors),
              _SettingsTile(
                icon: Icons.gradient_rounded,
                title: l10n.settingsNowPlayingColor,
                subtitle: themeState.nowPlayingColorStyleLabel(l10n),
                colors: colors,
                theme: theme,
                onTap: () => _showNowPlayingColorStyleDialog(context, ref),
              ),
              _divider(colors),
              _SettingsTile(
                icon: Icons.dock_rounded,
                title: l10n.settingsNavBar,
                subtitle: themeState.navBarStyleLabel(l10n),
                colors: colors,
                theme: theme,
                onTap: () => _showNavBarStyleDialog(context, ref),
              ),
              _divider(colors),
              _SettingsTile(
                icon: Icons.queue_music_rounded,
                title: l10n.settingsMiniPlayer,
                subtitle: themeState.miniPlayerStyleLabel(l10n),
                colors: colors,
                theme: theme,
                onTap: () => _showMiniPlayerStyleDialog(context, ref),
              ),
              _divider(colors),
              _SettingsTile(
                icon: Icons.linear_scale_rounded,
                title: l10n.settingsProgressBar,
                subtitle: themeState.mediaBarStyleLabel(l10n),
                colors: colors,
                theme: theme,
                onTap: () => _showMediaBarStyleDialog(context, ref),
              ),
              _divider(colors),
              _SettingsTile(
                icon: Icons.palette_outlined,
                title: l10n.settingsCustomColors,
                subtitle: themeState.useCustomNpColors
                    ? 'Cores manuais ativas'
                    : 'Extrair da capa do álbum',
                colors: colors,
                theme: theme,
                onTap: () => _showCustomNpColorsSheet(context, ref),
              ),
              _divider(colors),
              _SettingsTile(
                icon: Icons.language_rounded,
                title: AppLocalizations.of(context).settingsLanguage,
                subtitle: switch (themeState.languageCode) {
                  'en' => AppLocalizations.of(context).settingsLanguageEnglish,
                  'pt' => AppLocalizations.of(
                    context,
                  ).settingsLanguagePortuguese,
                  _ => AppLocalizations.of(context).settingsLanguageSystem,
                },
                colors: colors,
                theme: theme,
                onTap: () => _showLanguageDialog(context, ref),
              ),
            ],
          ),

          // ========================================
          // REPRODUÇÃO
          // ========================================
          _SectionHeader(
            title: l10n.settingsPlayback,
            theme: theme,
            colors: colors,
          ),
          _SettingsGroup(
            colors: colors,
            children: [
              _SettingsTile(
                icon: Icons.equalizer_rounded,
                title: l10n.settingsEqualizer,
                subtitle: audioState.eqEnabled
                    ? audioState.currentPreset.name
                    : 'Desligado',
                colors: colors,
                theme: theme,
                onTap: () => Navigator.push(
                  context,
                  AppPageRoute(page: const EqualizerPage()),
                ),
              ),
              _divider(colors),
              _SettingsTile(
                icon: Icons.swap_horiz_rounded,
                title: l10n.settingsCrossfade,
                subtitle: audioState.crossfadeLabel,
                colors: colors,
                theme: theme,
                onTap: () => _showCrossfadeDialog(context, ref),
              ),
              _divider(colors),
              _SettingsTile(
                icon: Icons.volume_up_outlined,
                title: l10n.settingsVolumeNormalization,
                subtitle: 'Nivelar volume entre músicas',
                colors: colors,
                theme: theme,
                trailing: Switch.adaptive(
                  value: audioState.volumeNormalization,
                  onChanged: (_) => ref
                      .read(audioSettingsProvider.notifier)
                      .toggleVolumeNormalization(),
                  activeThumbColor: accentColor ?? colors.primary,
                  activeTrackColor: accentColor?.withValues(alpha: 0.3),
                  trackOutlineColor: WidgetStatePropertyAll(
                    colors.onSurface.withValues(alpha: 0.15),
                  ),
                ),
              ),
              _divider(colors),
              _SettingsTile(
                icon: Icons.speed_rounded,
                title: l10n.settingsPlaybackSpeed,
                subtitle: audioState.speedLabel,
                colors: colors,
                theme: theme,
                onTap: () => _showSpeedDialog(context, ref),
              ),
              _divider(colors),
              _SettingsTile(
                icon: Icons.timer_outlined,
                title: l10n.settingsSleepTimer,
                subtitle: audioState.sleepTimerLabel,
                colors: colors,
                theme: theme,
                onTap: () => _showSleepTimerDialog(context, ref),
              ),
              _divider(colors),
              _SettingsTile(
                icon: Icons.graphic_eq_rounded,
                title: l10n.settingsGapless,
                subtitle: 'Sem silêncio entre faixas',
                colors: colors,
                theme: theme,
                trailing: Switch.adaptive(
                  value: audioState.gaplessPlayback,
                  onChanged: (_) =>
                      ref.read(audioSettingsProvider.notifier).toggleGapless(),
                  activeThumbColor: accentColor ?? colors.primary,
                  activeTrackColor: accentColor?.withValues(alpha: 0.3),
                  trackOutlineColor: WidgetStatePropertyAll(
                    colors.onSurface.withValues(alpha: 0.15),
                  ),
                ),
              ),
              _divider(colors),
              _SettingsTile(
                icon: Icons.battery_charging_full_rounded,
                title: l10n.settingsBackgroundPlayback,
                subtitle: 'Isentar de otimização de bateria',
                colors: colors,
                theme: theme,
                onTap: () => _requestBatteryExemption(context),
              ),
            ],
          ),

          // ========================================
          // BIBLIOTECA
          // ========================================
          _SectionHeader(
            title: l10n.settingsLibrary,
            theme: theme,
            colors: colors,
          ),
          _SettingsGroup(
            colors: colors,
            children: [
              _SettingsTile(
                icon: Icons.folder_outlined,
                title: l10n.settingsMusicFolders,
                subtitle: libState.foldersLabel,
                colors: colors,
                theme: theme,
                onTap: () => context.push('/folders'),
              ),
              _divider(colors),
              _SettingsTile(
                icon: Icons.refresh_rounded,
                title: l10n.settingsRescan,
                subtitle: libState.isLoading
                    ? 'Escaneando...'
                    : '${libState.songs.length} músicas encontradas',
                colors: colors,
                theme: theme,
                onTap: libState.isLoading
                    ? null
                    : () {
                        ref.read(libraryProvider.notifier).rescan();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Re-escaneando biblioteca...'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
              ),
              _divider(colors),
              _SettingsTile(
                icon: Icons.copy_all_rounded,
                title: l10n.settingsDuplicates,
                subtitle: 'Detectar e remover cópias da biblioteca',
                colors: colors,
                theme: theme,
                onTap: () => Navigator.push(
                  context,
                  AppPageRoute(page: const DuplicatesPage()),
                ),
              ),
            ],
          ),

          // ========================================
          // SOBRE
          // ========================================
          _SectionHeader(
            title: l10n.settingsAbout,
            theme: theme,
            colors: colors,
          ),
          _SettingsGroup(
            colors: colors,
            children: [
              _SettingsTile(
                icon: Icons.info_outline_rounded,
                title: 'Sobre o ${AppConstants.appName}',
                subtitle: 'v${AppConstants.appVersion}',
                colors: colors,
                theme: theme,
                onTap: () => _showAboutDialog(context),
              ),
              _divider(colors),
              _SettingsTile(
                icon: Icons.star_outline_rounded,
                title: l10n.settingsRate,
                subtitle: 'Ajude-nos com sua avaliação',
                colors: colors,
                theme: theme,
                onTap: () {},
              ),
              _divider(colors),
              _SettingsTile(
                icon: Icons.cloud_sync_outlined,
                title: l10n.settingsBackup,
                subtitle: 'Exportar/importar playlists, favoritos e ajustes',
                colors: colors,
                theme: theme,
                onTap: () => _showBackupSheet(context),
              ),
              _divider(colors),
              _SettingsTile(
                icon: Icons.bug_report_outlined,
                title: l10n.settingsDiagnostics,
                subtitle: 'Ver e enviar logs de erros',
                colors: colors,
                theme: theme,
                onTap: () => _showDiagnosticsSheet(context),
              ),
              _divider(colors),
              _SettingsTile(
                icon: Icons.description_outlined,
                title: l10n.settingsLicenses,
                subtitle: 'Licenças de código aberto',
                colors: colors,
                theme: theme,
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: AppConstants.appName,
                  applicationVersion: AppConstants.appVersion,
                ),
              ),
            ],
          ),

          // Footer
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: Column(
              children: [
                Text(
                  AppConstants.appName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.25),
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'v${AppConstants.appVersion}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.15),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Feito com ♡ por ${AppConstants.appAuthor}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.2),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DIALOGS
  // ============================================================

  void _showDiagnosticsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      builder: (_) => const _DiagnosticsSheet(),
    );
  }

  void _showLanguageDialog(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final current = ref.read(themeProvider).languageCode;
    final notifier = ref.read(themeProvider.notifier);

    showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: colors.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        title: Text(l10n.settingsLanguage),
        children: [
          _langOption(
            ctx,
            l10n.settingsLanguageSystem,
            Icons.smartphone_rounded,
            current == null,
            () {
              notifier.setLanguage(null);
              ctx.pop();
            },
          ),
          _langOption(
            ctx,
            l10n.settingsLanguagePortuguese,
            Icons.translate_rounded,
            current == 'pt',
            () {
              notifier.setLanguage('pt');
              ctx.pop();
            },
          ),
          _langOption(
            ctx,
            l10n.settingsLanguageEnglish,
            Icons.translate_rounded,
            current == 'en',
            () {
              notifier.setLanguage('en');
              ctx.pop();
            },
          ),
        ],
      ),
    );
  }

  Widget _langOption(
    BuildContext ctx,
    String label,
    IconData icon,
    bool selected,
    VoidCallback onTap,
  ) {
    final colors = Theme.of(ctx).colorScheme;
    return SimpleDialogOption(
      onPressed: onTap,
      child: Row(
        children: [
          Icon(
            icon,
            size: 22,
            color: selected
                ? colors.onSurface
                : colors.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: colors.onSurface,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          if (selected)
            Icon(Icons.check_rounded, color: colors.onSurface, size: 20),
        ],
      ),
    );
  }

  void _showBackupSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      builder: (_) => const _BackupSheet(),
    );
  }

  Future<void> _requestBatteryExemption(BuildContext context) async {
    final already = await PermissionService.isIgnoringBatteryOptimizations();
    if (!context.mounted) return;
    if (already) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('App já está isento de otimização de bateria'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    final granted = await PermissionService.requestIgnoreBatteryOptimizations();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          granted
              ? 'Isenção concedida. Reprodução em background mais estável.'
              : 'Isenção não concedida. Reprodução pode ser interrompida.',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showCrossfadeDialog(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final current = ref.read(audioSettingsProvider).crossfadeDuration;
    final options = [0, 2, 3, 5, 7, 10, 12];
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: colors.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        title: const Text('Crossfade'),
        children: options.map((sec) {
          final label = sec == 0 ? 'Desligado' : '$sec segundos';
          return _dialogOption(
            ctx,
            label,
            sec == 0 ? Icons.close_rounded : Icons.swap_horiz_rounded,
            current == sec,
            () {
              ref.read(audioSettingsProvider.notifier).setCrossfade(sec);
              ctx.pop();
            },
          );
        }).toList(),
      ),
    );
  }

  void _showSpeedDialog(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final current = ref.read(audioSettingsProvider).playbackSpeed;
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: colors.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        title: const Text('Velocidade'),
        children: speeds.map((speed) {
          return _dialogOption(
            ctx,
            '${speed.toStringAsFixed(speed == speed.roundToDouble() ? 0 : 2)}x',
            Icons.speed_rounded,
            (current - speed).abs() < 0.01,
            () {
              ref.read(audioSettingsProvider.notifier).setPlaybackSpeed(speed);
              ref.read(playerProvider.notifier).setSpeed(speed);
              ctx.pop();
            },
          );
        }).toList(),
      ),
    );
  }

  void _showSleepTimerDialog(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final audioState = ref.read(audioSettingsProvider);
    final notifier = ref.read(audioSettingsProvider.notifier);
    final options = [0, 5, 10, 15, 30, 45, 60, 90, 120];

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.6,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: AppSpacing.xs),
                Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Sleep Timer', style: theme.textTheme.titleMedium),
                if (audioState.hasSleepTimer) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    audioState.sleepTimerLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.tertiary,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Divider(color: colors.outline.withValues(alpha: 0.15)),
                ...options.map((min) {
                  final label = min == 0
                      ? 'Desligar timer'
                      : min < 60
                      ? '$min minutos'
                      : '${min ~/ 60}h${min % 60 > 0 ? ' ${min % 60}min' : ''}';
                  final isSelected = audioState.sleepTimerMinutes == min;
                  return ListTile(
                    leading: Icon(
                      min == 0 ? Icons.timer_off_rounded : Icons.timer_rounded,
                      color: isSelected
                          ? colors.onSurface
                          : colors.onSurface.withValues(alpha: 0.4),
                    ),
                    title: Text(
                      label,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_rounded,
                            color: colors.onSurface,
                            size: 20,
                          )
                        : null,
                    onTap: () {
                      notifier.setSleepTimer(min);
                      ctx.pop();
                    },
                  );
                }),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.md),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: colors.onSurface, width: 1.5),
              ),
              child: Center(
                child: Text(
                  'C',
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontSize: 28,
                    fontWeight: FontWeight.w200,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              AppConstants.appName,
              style: theme.textTheme.titleMedium?.copyWith(
                letterSpacing: 2,
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'v${AppConstants.appVersion}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              '"${AppConstants.appTagline}"',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.5),
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Desenvolvido com ♡ por',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              AppConstants.appAuthor,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(),
            child: Text('Fechar', style: TextStyle(color: colors.onSurface)),
          ),
        ],
      ),
    );
  }

  // ── INTERFACE DIALOGS ──

  void _showNowPlayingStyleDialog(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final current = ref.read(themeProvider).nowPlayingStyle;
    final options = [
      (NowPlayingStyle.classic, l10n.npStyleClassic, Icons.crop_square_rounded),
      (NowPlayingStyle.circular, l10n.npStyleCircular, Icons.circle_outlined),
      (NowPlayingStyle.large, l10n.npStyleLarge, Icons.crop_landscape_rounded),
      (
        NowPlayingStyle.fullBlur,
        l10n.npStyleFullBlur,
        Icons.blur_circular_rounded,
      ),
      (NowPlayingStyle.vinyl, l10n.npStyleVinyl, Icons.album_rounded),
      (
        NowPlayingStyle.minimalist,
        l10n.npStyleMinimalist,
        Icons.space_bar_rounded,
      ),
      (NowPlayingStyle.aurora, l10n.npStyleAurora, Icons.auto_awesome_rounded),
      (NowPlayingStyle.elegant, l10n.npStyleElegant, Icons.diamond_outlined),
      (NowPlayingStyle.wave, l10n.npStyleWave, Icons.waves_rounded),
      (NowPlayingStyle.mosaic, l10n.npStyleMosaic, Icons.grid_view_rounded),
    ];
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: colors.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        title: Text(l10n.settingsNowPlayingStyle),
        children: options.map((o) {
          return _dialogOption(ctx, o.$2, o.$3, current == o.$1, () {
            ref.read(themeProvider.notifier).setNowPlayingStyle(o.$1);
            ctx.pop();
          });
        }).toList(),
      ),
    );
  }

  void _showNowPlayingColorStyleDialog(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final current = ref.read(themeProvider).nowPlayingColorStyle;

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: AppSpacing.xs),
              Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Cor do Now Playing', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'Escolha o estilo de cor de fundo',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              // Degradê option
              _ColorStyleOption(
                title: 'Degradê',
                description: 'Transição suave de uma cor dominante para preto',
                icon: Icons.gradient_rounded,
                isSelected: current == NowPlayingColorStyle.degrade,
                colors: colors,
                theme: theme,
                previewColors: const [
                  Color(0xFF6A3DE8),
                  Color(0xFF3A1F8C),
                  Color(0xFF1A1028),
                ],
                isLinear: true,
                onTap: () {
                  ref
                      .read(themeProvider.notifier)
                      .setNowPlayingColorStyle(NowPlayingColorStyle.degrade);
                  ctx.pop();
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              // Gradient option
              _ColorStyleOption(
                title: 'Gradiente',
                description:
                    'Múltiplas cores da capa em gradiente radial fluido',
                icon: Icons.blur_on_rounded,
                isSelected: current == NowPlayingColorStyle.gradient,
                colors: colors,
                theme: theme,
                previewColors: const [
                  Color(0xFF00BCD4),
                  Color(0xFFFF9800),
                  Color(0xFFE91E63),
                ],
                isLinear: false,
                onTap: () {
                  ref
                      .read(themeProvider.notifier)
                      .setNowPlayingColorStyle(NowPlayingColorStyle.gradient);
                  ctx.pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNavBarStyleDialog(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final current = ref.read(themeProvider).navBarStyle;
    final options = [
      (NavBarStyle.glass, l10n.navBarGlass, Icons.blur_on_rounded),
      (NavBarStyle.artwork, l10n.navBarArtwork, Icons.image_rounded),
      (NavBarStyle.solid, l10n.navBarSolid, Icons.square_rounded),
      (NavBarStyle.minimal, l10n.navBarMinimal, Icons.minimize_rounded),
    ];
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: colors.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        title: Text(l10n.settingsNavBar),
        children: options.map((o) {
          return _dialogOption(ctx, o.$2, o.$3, current == o.$1, () {
            ref.read(themeProvider.notifier).setNavBarStyle(o.$1);
            ctx.pop();
          });
        }).toList(),
      ),
    );
  }

  void _showMiniPlayerStyleDialog(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final current = ref.read(themeProvider).miniPlayerStyle;
    final options = [
      (MiniPlayerStyle.glass, l10n.miniPlayerGlass, Icons.blur_on_rounded),
      (MiniPlayerStyle.artwork, l10n.miniPlayerArtwork, Icons.image_rounded),
      (MiniPlayerStyle.minimal, l10n.miniPlayerMinimal, Icons.minimize_rounded),
      (MiniPlayerStyle.card, l10n.miniPlayerCard, Icons.credit_card_rounded),
      (
        MiniPlayerStyle.dynamic,
        l10n.miniPlayerDynamic,
        Icons.auto_awesome_rounded,
      ),
    ];
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: colors.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        title: Text(l10n.settingsMiniPlayer),
        children: options.map((o) {
          return _dialogOption(ctx, o.$2, o.$3, current == o.$1, () {
            ref.read(themeProvider.notifier).setMiniPlayerStyle(o.$1);
            ctx.pop();
          });
        }).toList(),
      ),
    );
  }

  void _showMediaBarStyleDialog(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final current = ref.read(themeProvider).mediaBarStyle;
    final options = [
      (MediaBarStyle.minimal, l10n.mediaBarMinimal, Icons.remove_rounded),
      (MediaBarStyle.glow, l10n.mediaBarGlow, Icons.flare_rounded),
      (MediaBarStyle.gradient, l10n.mediaBarGradient, Icons.gradient_rounded),
      (MediaBarStyle.thick, l10n.mediaBarThick, Icons.linear_scale_rounded),
      (MediaBarStyle.classic, l10n.mediaBarClassic, Icons.tune_rounded),
    ];
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: colors.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        title: Text(l10n.settingsProgressBar),
        children: options.map((o) {
          return _dialogOption(ctx, o.$2, o.$3, current == o.$1, () {
            ref.read(themeProvider.notifier).setMediaBarStyle(o.$1);
            ctx.pop();
          });
        }).toList(),
      ),
    );
  }

  void _showCustomNpColorsSheet(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surfaceContainer,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      builder: (ctx) => _CustomNpColorsSheet(colors: colors, theme: theme),
    );
  }

  Widget _dialogOption(
    BuildContext context,
    String title,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
  ) {
    final colors = Theme.of(context).colorScheme;
    return SimpleDialogOption(
      onPressed: onTap,
      child: Row(
        children: [
          Icon(
            icon,
            size: 22,
            color: isSelected
                ? colors.onSurface
                : colors.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: colors.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          if (isSelected)
            Icon(Icons.check_rounded, color: colors.onSurface, size: 20),
        ],
      ),
    );
  }

  Widget _divider(ColorScheme colors) {
    return Divider(
      height: 0.5,
      thickness: 0.5,
      indent: 56,
      color: colors.outline.withValues(alpha: 0.15),
    );
  }
}

// ============================================================
// WIDGETS AUXILIARES
// ============================================================

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.theme,
    required this.colors,
  });
  final String title;
  final ThemeData theme;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Text(
        title,
        style: theme.textTheme.labelSmall?.copyWith(
          color: colors.onSurface.withValues(alpha: 0.35),
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children, required this.colors});
  final List<Widget> children;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.onSurface.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: colors.outline.withValues(alpha: 0.08)),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.theme,
    this.trailing,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final ColorScheme colors;
  final ThemeData theme;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: colors.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
            if (trailing == null && onTap != null)
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: colors.onSurface.withValues(alpha: 0.2),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// COLOR STYLE OPTION — visual card for degradê/gradient picker
// ============================================================

class _ColorStyleOption extends StatelessWidget {
  const _ColorStyleOption({
    required this.title,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.colors,
    required this.theme,
    required this.previewColors,
    required this.isLinear,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final bool isSelected;
  final ColorScheme colors;
  final ThemeData theme;
  final List<Color> previewColors;
  final bool isLinear;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: isSelected
                ? colors.onSurface.withValues(alpha: 0.6)
                : colors.outline.withValues(alpha: 0.12),
            width: isSelected ? 1.5 : 1.0,
          ),
          color: isSelected
              ? colors.onSurface.withValues(alpha: 0.06)
              : colors.onSurface.withValues(alpha: 0.02),
        ),
        child: Row(
          children: [
            // Mini preview
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                gradient: isLinear
                    ? LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: previewColors,
                      )
                    : null,
              ),
              child: isLinear
                  ? null
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(color: const Color(0xFF121212)),
                          // 3 radial blobs
                          Container(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: const Alignment(-0.7, -0.6),
                                radius: 1.2,
                                colors: [
                                  previewColors[0].withValues(alpha: 0.8),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: const Alignment(0.7, -0.3),
                                radius: 1.0,
                                colors: [
                                  previewColors[1].withValues(alpha: 0.7),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: const Alignment(0.4, 0.8),
                                radius: 1.0,
                                colors: [
                                  previewColors[2].withValues(alpha: 0.6),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(width: AppSpacing.md),
            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        icon,
                        size: 18,
                        color: isSelected
                            ? colors.onSurface
                            : colors.onSurface.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: colors.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.4),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            // Check indicator
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.onSurface,
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: colors.surface,
                ),
              )
            else
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.outline.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// CUSTOM NP COLORS BOTTOM SHEET
// ============================================================

class _CustomNpColorsSheet extends ConsumerStatefulWidget {
  const _CustomNpColorsSheet({required this.colors, required this.theme});
  final ColorScheme colors;
  final ThemeData theme;

  @override
  ConsumerState<_CustomNpColorsSheet> createState() =>
      _CustomNpColorsSheetState();
}

class _CustomNpColorsSheetState extends ConsumerState<_CustomNpColorsSheet> {
  static const _presetColors = [
    Color(0xFFE53935),
    Color(0xFFD81B60),
    Color(0xFF8E24AA),
    Color(0xFF5E35B1),
    Color(0xFF3949AB),
    Color(0xFF1E88E5),
    Color(0xFF00ACC1),
    Color(0xFF00897B),
    Color(0xFF43A047),
    Color(0xFF7CB342),
    Color(0xFFFDD835),
    Color(0xFFFB8C00),
    Color(0xFFFF7043),
    Color(0xFF6D4C41),
    Color(0xFF546E7A),
    Color(0xFFEC407A),
  ];

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final notifier = ref.read(themeProvider.notifier);
    final colors = widget.colors;
    final theme = widget.theme;
    final accentColor = ref.watch(artworkPaletteProvider)?.dominant;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.xs),
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: colors.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Cores do Now Playing', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Personalize as cores de fundo do player',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Toggle
            SwitchListTile.adaptive(
              title: Text(
                'Usar cores personalizadas',
                style: theme.textTheme.bodyMedium,
              ),
              subtitle: Text(
                themeState.useCustomNpColors
                    ? 'Cores manuais ativas'
                    : 'Cores extraídas da capa',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.4),
                ),
              ),
              value: themeState.useCustomNpColors,
              onChanged: (_) => notifier.toggleCustomNpColors(),
              activeThumbColor: accentColor ?? colors.primary,
              activeTrackColor: accentColor?.withValues(alpha: 0.3),
              trackOutlineColor: WidgetStatePropertyAll(
                colors.onSurface.withValues(alpha: 0.15),
              ),
              contentPadding: EdgeInsets.zero,
            ),

            if (themeState.useCustomNpColors) ...[
              const SizedBox(height: AppSpacing.md),

              // Preview gradient
              Container(
                height: 48,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  gradient: LinearGradient(
                    colors: [
                      themeState.npCustomColor1 ?? const Color(0xFF6C63FF),
                      themeState.npCustomColor2 ?? const Color(0xFF3A3A5C),
                      themeState.npCustomColor3 ?? const Color(0xFF1A1A2E),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Color 1
              _NpColorRow(
                label: 'Cor Dominante',
                color: themeState.npCustomColor1,
                presetColors: _presetColors,
                colors: colors,
                theme: theme,
                onColorSelected: (c) => notifier.setNpCustomColor(1, c),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Color 2
              _NpColorRow(
                label: 'Cor Secundária',
                color: themeState.npCustomColor2,
                presetColors: _presetColors,
                colors: colors,
                theme: theme,
                onColorSelected: (c) => notifier.setNpCustomColor(2, c),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Color 3
              _NpColorRow(
                label: 'Cor de Fundo',
                color: themeState.npCustomColor3,
                presetColors: _presetColors,
                colors: colors,
                theme: theme,
                onColorSelected: (c) => notifier.setNpCustomColor(3, c),
              ),
            ],

            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

class _NpColorRow extends StatelessWidget {
  const _NpColorRow({
    required this.label,
    required this.color,
    required this.presetColors,
    required this.colors,
    required this.theme,
    required this.onColorSelected,
  });

  final String label;
  final Color? color;
  final List<Color> presetColors;
  final ColorScheme colors;
  final ThemeData theme;
  final ValueChanged<Color> onColorSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color ?? colors.onSurface.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: colors.outline.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(label, style: theme.textTheme.bodyMedium),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: presetColors.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final c = presetColors[i];
              final isSelected =
                  color != null && color!.toARGB32() == c.toARGB32();
              return GestureDetector(
                onTap: () => onColorSelected(c),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: Colors.white, width: 2.5)
                        : null,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: c.withValues(alpha: 0.5),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: Colors.white,
                        )
                      : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ============================================================
// DIAGNOSTICS SHEET — view + share + clear crash logs
// ============================================================

class _DiagnosticsSheet extends StatefulWidget {
  const _DiagnosticsSheet();

  @override
  State<_DiagnosticsSheet> createState() => _DiagnosticsSheetState();
}

class _DiagnosticsSheetState extends State<_DiagnosticsSheet> {
  int _count = -1;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final n = await CrashReporter.countLogs();
    if (mounted) setState(() => _count = n);
  }

  Future<void> _share() async {
    final path = CrashReporter.logFilePath;
    if (path == null) return;
    setState(() => _busy = true);
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path, mimeType: 'application/json')],
          text:
              'Logs de diagnóstico — ${AppConstants.appName} v${AppConstants.appVersion}',
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clear() async {
    setState(() => _busy = true);
    await CrashReporter.clear();
    await _refresh();
    if (mounted) setState(() => _busy = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logs limpos'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hasLogs = _count > 0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Diagnóstico',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _count < 0
                  ? 'Carregando...'
                  : hasLogs
                  ? '$_count entrada${_count == 1 ? '' : 's'} de log'
                  : 'Nenhum erro registrado',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'O app grava localmente erros não-fatais e crashes em release. '
              'Compartilhe o arquivo se algo estranho acontecer — ajuda a diagnosticar.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: !hasLogs || _busy ? null : _share,
              icon: const Icon(Icons.ios_share_rounded, size: 18),
              label: const Text('Compartilhar logs'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: !hasLogs || _busy ? null : _clear,
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Limpar logs'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// BACKUP SHEET — export via share, import via clipboard
// ============================================================

class _BackupSheet extends StatefulWidget {
  const _BackupSheet();

  @override
  State<_BackupSheet> createState() => _BackupSheetState();
}

class _BackupSheetState extends State<_BackupSheet> {
  bool _busy = false;

  Future<void> _export() async {
    setState(() => _busy = true);
    final ok = await BackupService.exportAndShare();
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Falha ao gerar backup'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _importFromClipboard() async {
    setState(() => _busy = true);
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim();
      if (text == null || text.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Área de transferência vazia'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
      final restored = await BackupService.importFromString(text);
      if (!mounted) return;
      if (restored == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Formato de backup inválido'),
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$restored chave${restored == 1 ? '' : 's'} restaurada${restored == 1 ? '' : 's'}. Reinicie o app para aplicar.',
            ),
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Backup & Restauração',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Exporte playlists, favoritos, exclusões e ajustes para um arquivo '
              'JSON. Para restaurar, copie o conteúdo do arquivo e use "Importar".',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: _busy ? null : _export,
              icon: const Icon(Icons.upload_rounded, size: 18),
              label: const Text('Exportar backup'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: _busy ? null : _importFromClipboard,
              icon: const Icon(Icons.content_paste_go_rounded, size: 18),
              label: const Text('Importar (da área de transferência)'),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'O Android também faz backup automático na conta Google. Esta '
              'opção é portátil e independente da conta.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.35),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
