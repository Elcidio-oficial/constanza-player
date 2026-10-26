import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:constanza_player/l10n/gen/app_localizations.dart';
import 'package:constanza_player/core/constants/app_constants.dart';
import 'package:constanza_player/core/theme/app_spacing.dart';
import 'package:constanza_player/core/theme/app_backgrounds.dart';
import 'package:constanza_player/services/crash_reporter.dart';
import 'package:constanza_player/services/backup_service.dart';
import 'package:constanza_player/services/permission_service.dart';
import 'package:constanza_player/services/default_player_service.dart';
import 'package:constanza_player/core/utils/background_helper.dart';
import 'package:constanza_player/presentation/providers/theme_provider.dart';
import 'package:constanza_player/presentation/providers/audio_settings_provider.dart';
import 'package:constanza_player/presentation/providers/player_provider.dart';
import 'package:constanza_player/presentation/providers/library_provider.dart';
import 'package:constanza_player/presentation/providers/playlist_provider.dart';
import 'package:constanza_player/presentation/providers/artwork_provider.dart';
import 'package:constanza_player/presentation/pages/settings/background_settings_page.dart';
import 'package:constanza_player/presentation/pages/settings/equalizer_page.dart';
import 'package:constanza_player/presentation/pages/library/duplicates_page.dart';
import 'package:constanza_player/core/utils/app_page_route.dart';
import 'package:go_router/go_router.dart';

// Seções da tela
part 'parts/widgets.dart';
part 'parts/default_player_tile.dart';
part 'parts/color_style_option.dart';
part 'parts/custom_np_colors_sheet.dart';
part 'parts/diagnostics_sheet.dart';
part 'parts/backup_sheet.dart';

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
                    ? l10n.settingsCustomColorsActive
                    : l10n.settingsCustomColorsExtract,
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
                    : l10n.settingsEqualizerOff,
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
                subtitle: l10n.settingsVolumeNormalizationDesc,
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
                subtitle: l10n.settingsGaplessDesc,
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
                subtitle: l10n.settingsBackgroundPlaybackDesc,
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
                    ? l10n.settingsRescanScanning
                    : l10n.settingsRescanCount(libState.songs.length),
                colors: colors,
                theme: theme,
                onTap: libState.isLoading
                    ? null
                    : () {
                        ref.read(libraryProvider.notifier).rescan();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.settingsRescanRunning),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
              ),
              _divider(colors),
              _SettingsTile(
                icon: Icons.copy_all_rounded,
                title: l10n.settingsDuplicates,
                subtitle: l10n.settingsDuplicatesDesc,
                colors: colors,
                theme: theme,
                onTap: () => Navigator.push(
                  context,
                  AppPageRoute(page: const DuplicatesPage()),
                ),
              ),
              if (Platform.isAndroid) ...[
                _divider(colors),
                _DefaultPlayerTile(colors: colors, theme: theme),
              ],
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
                title: l10n.settingsAboutApp(AppConstants.appName),
                subtitle: 'v${AppConstants.appVersion}',
                colors: colors,
                theme: theme,
                onTap: () => _showAboutDialog(context),
              ),
              _divider(colors),
              _SettingsTile(
                icon: Icons.star_outline_rounded,
                title: l10n.settingsRate,
                subtitle: l10n.settingsRateDesc,
                colors: colors,
                theme: theme,
                onTap: () {},
              ),
              _divider(colors),
              _SettingsTile(
                icon: Icons.cloud_sync_outlined,
                title: l10n.settingsBackup,
                subtitle: l10n.settingsBackupDesc,
                colors: colors,
                theme: theme,
                onTap: () => _showBackupSheet(context),
              ),
              _divider(colors),
              _SettingsTile(
                icon: Icons.bug_report_outlined,
                title: l10n.settingsDiagnostics,
                subtitle: l10n.settingsDiagnosticsDesc,
                colors: colors,
                theme: theme,
                onTap: () => _showDiagnosticsSheet(context),
              ),
              _divider(colors),
              _SettingsTile(
                icon: Icons.privacy_tip_outlined,
                title: l10n.settingsPrivacyPolicy,
                subtitle: l10n.settingsPrivacyPolicyDesc,
                colors: colors,
                theme: theme,
                onTap: () => _openPrivacyPolicy(context),
              ),
              _divider(colors),
              _SettingsTile(
                icon: Icons.description_outlined,
                title: l10n.settingsLicenses,
                subtitle: l10n.settingsLicensesDesc,
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
                  l10n.settingsMadeBy(AppConstants.appAuthor),
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
        SnackBar(
          content: Text(
            AppLocalizations.of(context).settingsBackgroundExemptionAlready,
          ),
          duration: const Duration(seconds: 2),
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
              ? AppLocalizations.of(context).settingsBackgroundExemptionGranted
              : AppLocalizations.of(context).settingsBackgroundExemptionDenied,
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showCrossfadeDialog(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final current = ref.read(audioSettingsProvider).crossfadeDuration;
    final options = [0, 2, 3, 5, 7, 10, 12];
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: colors.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        title: Text(l10n.settingsCrossfadeTitle),
        children: options.map((sec) {
          final label = sec == 0
              ? l10n.settingsCrossfadeOff
              : l10n.settingsCrossfadeSeconds(sec);
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
    final l10n = AppLocalizations.of(context);
    final current = ref.read(audioSettingsProvider).playbackSpeed;
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: colors.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        title: Text(l10n.settingsSpeedTitle),
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
    final l10n = AppLocalizations.of(context);
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
                Text(
                  l10n.settingsSleepTitle,
                  style: theme.textTheme.titleMedium,
                ),
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
                      ? l10n.settingsSleepTimerDisable
                      : min < 60
                      ? l10n.settingsSleepTimerMinutes(min)
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

  Future<void> _openPrivacyPolicy(BuildContext context) async {
    final uri = Uri.parse(AppConstants.privacyPolicyUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppConstants.privacyPolicyUrl)));
    }
  }

  void _showAboutDialog(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
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
              '"${l10n.aboutDialogTagline}"',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.5),
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.aboutDialogMadeBy,
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
            child: Text(
              l10n.aboutDialogClose,
              style: TextStyle(color: colors.onSurface),
            ),
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
    final l10n = AppLocalizations.of(context);
    final current = ref.read(themeProvider).nowPlayingColorStyle;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
          ),
          child: SingleChildScrollView(
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
                Text(
                  l10n.settingsNowPlayingColor,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  l10n.npColorSheetSubtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                // Degradê option
                _ColorStyleOption(
                  title: l10n.npColorStyleDegrade,
                  description: l10n.npColorOptionDegradeDesc,
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
                  title: l10n.npColorStyleGradient,
                  description: l10n.npColorOptionGradientDesc,
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
                const SizedBox(height: AppSpacing.sm),
                // Artwork fullscreen option — like Car Mode
                _ColorStyleOption(
                  title: l10n.npColorStyleArtwork,
                  description: l10n.npColorOptionArtworkDesc,
                  icon: Icons.wallpaper_rounded,
                  isSelected: current == NowPlayingColorStyle.artwork,
                  colors: colors,
                  theme: theme,
                  previewColors: const [
                    Color(0xFF2A2A2A),
                    Color(0xFF4A4A4A),
                    Color(0xFF1A1A1A),
                  ],
                  isLinear: false,
                  onTap: () {
                    ref
                        .read(themeProvider.notifier)
                        .setNowPlayingColorStyle(NowPlayingColorStyle.artwork);
                    ctx.pop();
                  },
                ),
              ],
            ),
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
      (MediaBarStyle.waveform, l10n.mediaBarWaveform, Icons.graphic_eq_rounded),
      (
        MediaBarStyle.frequencyBars,
        l10n.mediaBarFrequencyBars,
        Icons.bar_chart_rounded,
      ),
      (MediaBarStyle.bars, l10n.mediaBarBars, Icons.equalizer_rounded),
      (MediaBarStyle.steps, l10n.mediaBarSteps, Icons.stairs_rounded),
      (
        MediaBarStyle.equalizer,
        l10n.mediaBarEqualizer,
        Icons.view_week_rounded,
      ),
      (
        MediaBarStyle.segments,
        l10n.mediaBarSegments,
        Icons.view_column_rounded,
      ),
      (MediaBarStyle.dots, l10n.mediaBarDots, Icons.grain_rounded),
      (MediaBarStyle.pulse, l10n.mediaBarPulse, Icons.monitor_heart_rounded),
      (MediaBarStyle.sineWave, l10n.mediaBarSineWave, Icons.waves_rounded),
      (MediaBarStyle.wave, l10n.mediaBarWave, Icons.water_rounded),
      (MediaBarStyle.mirror, l10n.mediaBarMirror, Icons.flip_rounded),
      (MediaBarStyle.dense, l10n.mediaBarDense, Icons.density_medium_rounded),
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
