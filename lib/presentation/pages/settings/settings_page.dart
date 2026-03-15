// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:constanza_player/core/constants/app_constants.dart';
import 'package:constanza_player/core/theme/app_spacing.dart';
import 'package:constanza_player/core/theme/app_backgrounds.dart';
import 'package:constanza_player/core/utils/background_helper.dart';
import 'package:constanza_player/presentation/providers/theme_provider.dart';
import 'package:constanza_player/presentation/providers/audio_settings_provider.dart';
import 'package:constanza_player/presentation/providers/player_provider.dart';
import 'package:constanza_player/presentation/providers/library_provider.dart';
import 'package:constanza_player/presentation/providers/artwork_provider.dart';
import 'package:constanza_player/presentation/pages/settings/background_settings_page.dart';
import 'package:constanza_player/presentation/pages/settings/equalizer_page.dart';
import 'package:constanza_player/core/utils/app_page_route.dart';

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

    return Scaffold(
      backgroundColor: BackgroundHelper.scaffoldColor(colors, themeState),
      appBar: AppBar(
        backgroundColor: BackgroundHelper.appBarColor(colors, themeState),
        title: Text(
          'Configurações',
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
          _SectionHeader(title: 'APARÊNCIA', theme: theme, colors: colors),
          _SettingsGroup(
            colors: colors,
            children: [
              _SettingsTile(
                icon: Icons.wallpaper_outlined,
                title: 'Fundo do App',
                subtitle: switch (themeState.backgroundType) {
                  BackgroundType.none => 'Desativado',
                  BackgroundType.gradient =>
                    themeState.currentGradient?.name ?? 'Gradiente',
                  BackgroundType.image => 'Imagem personalizada',
                },
                colors: colors,
                theme: theme,
                onTap: () => Navigator.push(
                  context,
                  AppPageRoute(
                    page: const BackgroundSettingsPage(),
                  ),
                ),
              ),
            ],
          ),

          // ========================================
          // PERSONALIZAÇÃO
          // ========================================
          _SectionHeader(title: 'PERSONALIZAÇÃO', theme: theme, colors: colors),
          _SettingsGroup(
            colors: colors,
            children: [
              _SettingsTile(
                icon: Icons.view_list_outlined,
                title: 'Densidade da Lista',
                subtitle: themeState.listDensityLabel,
                colors: colors,
                theme: theme,
                onTap: () => _showListDensityDialog(context, ref),
              ),
              _divider(colors),
              _SettingsTile(
                icon: Icons.image_outlined,
                title: 'Capa do álbum na lista',
                subtitle: 'Mostrar thumbnail nas músicas',
                colors: colors,
                theme: theme,
                trailing: Switch.adaptive(
                  value: themeState.showAlbumArtInList,
                  onChanged: (_) =>
                      ref.read(themeProvider.notifier).toggleAlbumArtInList(),
                  activeColor: accentColor ?? colors.primary,
                  activeTrackColor: accentColor?.withValues(alpha: 0.3),
                  trackOutlineColor: WidgetStatePropertyAll(colors.onSurface.withValues(alpha: 0.15)),
                ),
              ),
            ],
          ),

          // ========================================
          // INTERFACE
          // ========================================
          _SectionHeader(title: 'INTERFACE', theme: theme, colors: colors),
          _SettingsGroup(
            colors: colors,
            children: [
              _SettingsTile(
                icon: Icons.play_circle_outline_rounded,
                title: 'Estilo Now Playing',
                subtitle: themeState.nowPlayingStyleLabel,
                colors: colors,
                theme: theme,
                onTap: () => _showNowPlayingStyleDialog(context, ref),
              ),
              _divider(colors),
              _SettingsTile(
                icon: Icons.gradient_rounded,
                title: 'Cor do Now Playing',
                subtitle: themeState.nowPlayingColorStyleLabel,
                colors: colors,
                theme: theme,
                onTap: () => _showNowPlayingColorStyleDialog(context, ref),
              ),
              _divider(colors),
              _SettingsTile(
                icon: Icons.dock_rounded,
                title: 'Barra de Navegação',
                subtitle: themeState.navBarStyleLabel,
                colors: colors,
                theme: theme,
                onTap: () => _showNavBarStyleDialog(context, ref),
              ),
              _divider(colors),
              _SettingsTile(
                icon: Icons.queue_music_rounded,
                title: 'Mini Player',
                subtitle: themeState.miniPlayerStyleLabel,
                colors: colors,
                theme: theme,
                onTap: () => _showMiniPlayerStyleDialog(context, ref),
              ),
              _divider(colors),
              _SettingsTile(
                icon: Icons.linear_scale_rounded,
                title: 'Barra de Progresso',
                subtitle: themeState.mediaBarStyleLabel,
                colors: colors,
                theme: theme,
                onTap: () => _showMediaBarStyleDialog(context, ref),
              ),
              _divider(colors),
              _SettingsTile(
                icon: Icons.palette_outlined,
                title: 'Cores Personalizadas',
                subtitle: themeState.useCustomNpColors
                    ? 'Cores manuais ativas'
                    : 'Extrair da capa do álbum',
                colors: colors,
                theme: theme,
                onTap: () => _showCustomNpColorsSheet(context, ref),
              ),
            ],
          ),

          // ========================================
          // REPRODUÇÃO
          // ========================================
          _SectionHeader(title: 'REPRODUÇÃO', theme: theme, colors: colors),
          _SettingsGroup(
            colors: colors,
            children: [
              _SettingsTile(
                icon: Icons.equalizer_rounded,
                title: 'Equalizador',
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
                title: 'Crossfade',
                subtitle: audioState.crossfadeLabel,
                colors: colors,
                theme: theme,
                onTap: () => _showCrossfadeDialog(context, ref),
              ),
              _divider(colors),
              _SettingsTile(
                icon: Icons.volume_up_outlined,
                title: 'Normalização de Volume',
                subtitle: 'Nivelar volume entre músicas',
                colors: colors,
                theme: theme,
                trailing: Switch.adaptive(
                  value: audioState.volumeNormalization,
                  onChanged: (_) => ref
                      .read(audioSettingsProvider.notifier)
                      .toggleVolumeNormalization(),
                  activeColor: accentColor ?? colors.primary,
                  activeTrackColor: accentColor?.withValues(alpha: 0.3),
                  trackOutlineColor: WidgetStatePropertyAll(colors.onSurface.withValues(alpha: 0.15)),
                ),
              ),
              _divider(colors),
              _SettingsTile(
                icon: Icons.speed_rounded,
                title: 'Velocidade de Reprodução',
                subtitle: audioState.speedLabel,
                colors: colors,
                theme: theme,
                onTap: () => _showSpeedDialog(context, ref),
              ),
              _divider(colors),
              _SettingsTile(
                icon: Icons.timer_outlined,
                title: 'Sleep Timer',
                subtitle: audioState.sleepTimerLabel,
                colors: colors,
                theme: theme,
                onTap: () => _showSleepTimerDialog(context, ref),
              ),
              _divider(colors),
              _SettingsTile(
                icon: Icons.graphic_eq_rounded,
                title: 'Gapless Playback',
                subtitle: 'Sem silêncio entre faixas',
                colors: colors,
                theme: theme,
                trailing: Switch.adaptive(
                  value: audioState.gaplessPlayback,
                  onChanged: (_) =>
                      ref.read(audioSettingsProvider.notifier).toggleGapless(),
                  activeColor: accentColor ?? colors.primary,
                  activeTrackColor: accentColor?.withValues(alpha: 0.3),
                  trackOutlineColor: WidgetStatePropertyAll(colors.onSurface.withValues(alpha: 0.15)),
                ),
              ),
            ],
          ),

          // ========================================
          // BIBLIOTECA
          // ========================================
          _SectionHeader(title: 'BIBLIOTECA', theme: theme, colors: colors),
          _SettingsGroup(
            colors: colors,
            children: [
              _SettingsTile(
                icon: Icons.folder_outlined,
                title: 'Pastas de Música',
                subtitle: libState.foldersLabel,
                colors: colors,
                theme: theme,
                onTap: () => showFolderPicker(context, ref),
              ),
              _divider(colors),
              _SettingsTile(
                icon: Icons.refresh_rounded,
                title: 'Re-escanear Biblioteca',
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
                            content: Text(
                              'Re-escaneando biblioteca...',
                              style: TextStyle(color: colors.surface),
                            ),
                            backgroundColor: colors.onSurface,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
              ),
              _divider(colors),
              _SettingsTile(
                icon: Icons.sort_rounded,
                title: 'Ordenação Padrão',
                subtitle: libState.sortOrderLabel,
                colors: colors,
                theme: theme,
                onTap: () => _showSortOrderDialog(context, ref),
              ),
              _divider(colors),
              _SettingsTile(
                icon: Icons.filter_list_rounded,
                title: 'Filtrar músicas curtas',
                subtitle: 'Ocultar faixas menores que 30s',
                colors: colors,
                theme: theme,
                trailing: Switch.adaptive(
                  value: libState.filterShortTracks,
                  onChanged: (_) =>
                      ref.read(libraryProvider.notifier).toggleFilterShortTracks(),
                  activeColor: accentColor ?? colors.primary,
                  activeTrackColor: accentColor?.withValues(alpha: 0.3),
                  trackOutlineColor: WidgetStatePropertyAll(colors.onSurface.withValues(alpha: 0.15)),
                ),
              ),
            ],
          ),

          // ========================================
          // SOBRE
          // ========================================
          _SectionHeader(title: 'SOBRE', theme: theme, colors: colors),
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
                title: 'Avaliar na Play Store',
                subtitle: 'Ajude-nos com sua avaliação',
                colors: colors,
                theme: theme,
                onTap: () {},
              ),
              _divider(colors),
              _SettingsTile(
                icon: Icons.description_outlined,
                title: 'Licenças',
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

  void _showListDensityDialog(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final current = ref.read(themeProvider).listDensity;
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: colors.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        title: const Text('Densidade da Lista'),
        children: [
          _dialogOption(
            ctx,
            'Compacto',
            Icons.density_small_rounded,
            current == ListDensity.compact,
            () {
              ref
                  .read(themeProvider.notifier)
                  .setListDensity(ListDensity.compact);
              Navigator.pop(ctx);
            },
          ),
          _dialogOption(
            ctx,
            'Normal',
            Icons.density_medium_rounded,
            current == ListDensity.normal,
            () {
              ref
                  .read(themeProvider.notifier)
                  .setListDensity(ListDensity.normal);
              Navigator.pop(ctx);
            },
          ),
          _dialogOption(
            ctx,
            'Confortável',
            Icons.density_large_rounded,
            current == ListDensity.comfortable,
            () {
              ref
                  .read(themeProvider.notifier)
                  .setListDensity(ListDensity.comfortable);
              Navigator.pop(ctx);
            },
          ),
        ],
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
              Navigator.pop(ctx);
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
              Navigator.pop(ctx);
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
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
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
                  Navigator.pop(ctx);
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
            onPressed: () => Navigator.pop(ctx),
            child: Text('Fechar', style: TextStyle(color: colors.onSurface)),
          ),
        ],
      ),
    );
  }

  void _showSortOrderDialog(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final current = ref.read(libraryProvider).sortOrder;
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: colors.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        title: const Text('Ordenação Padrão'),
        children: SortOrder.values.map((order) {
          final label = switch (order) {
            SortOrder.title => 'Título',
            SortOrder.artist => 'Artista',
            SortOrder.album => 'Álbum',
            SortOrder.dateAdded => 'Data adicionada',
            SortOrder.duration => 'Duração',
          };
          final icon = switch (order) {
            SortOrder.title => Icons.sort_by_alpha_rounded,
            SortOrder.artist => Icons.person_rounded,
            SortOrder.album => Icons.album_rounded,
            SortOrder.dateAdded => Icons.calendar_today_rounded,
            SortOrder.duration => Icons.timer_rounded,
          };
          return _dialogOption(
            ctx,
            label,
            icon,
            current == order,
            () {
              ref.read(libraryProvider.notifier).setSortOrder(order);
              Navigator.pop(ctx);
            },
          );
        }).toList(),
      ),
    );
  }

  /// Abre o seletor de pastas. Pode ser chamado de qualquer página.
  static Future<void> showFolderPicker(BuildContext context, WidgetRef ref) async {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    // Mostrar loading enquanto descobre pastas
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: colors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: colors.onSurface.withValues(alpha: 0.5),
                  strokeWidth: 2,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Descobrindo pastas...',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Descobrir pastas no dispositivo
    final songCountMap = await ref.read(libraryProvider.notifier).discoverFolders();

    // Fechar loading
    if (!context.mounted) return;
    Navigator.pop(context);

    if (songCountMap.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Nenhuma pasta com músicas encontrada.',
            style: TextStyle(color: colors.surface),
          ),
          backgroundColor: colors.onSurface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
        ),
      );
      return;
    }

    // Ler pastas descobertas e seleção atual
    final allFolders = ref.read(libraryProvider).allFolders;
    final currentSelected = ref.read(libraryProvider).selectedFolders;
    final selected = Set<String>.from(currentSelected);

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surfaceContainer,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
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
                    'Pastas de Música',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selected.isEmpty
                        ? 'Selecione pelo menos uma pasta.'
                        : '${selected.length} de ${allFolders.length} pastas selecionadas.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Botão "Selecionar todas / Limpar"
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            if (selected.length == allFolders.length) {
                              selected.clear();
                            } else {
                              selected
                                ..clear()
                                ..addAll(allFolders);
                            }
                          });
                        },
                        icon: Icon(
                          selected.length == allFolders.length
                              ? Icons.deselect_rounded
                              : Icons.select_all_rounded,
                          size: 18,
                          color: colors.primary,
                        ),
                        label: Text(
                          selected.length == allFolders.length
                              ? 'Limpar seleção'
                              : 'Selecionar todas',
                          style: TextStyle(color: colors.primary, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  // Lista de pastas
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(ctx).size.height * 0.5,
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: allFolders.length,
                      itemBuilder: (_, i) {
                        final folder = allFolders[i];
                        final isSelected = selected.contains(folder);
                        final count = songCountMap[folder] ?? 0;
                        final displayName = folder.split('/').last;
                        final shortPath = folder.replaceFirst(
                          '/storage/emulated/0/',
                          '',
                        );

                        return InkWell(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                selected.remove(folder);
                              } else {
                                selected.add(folder);
                              }
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.xs + 2,
                              horizontal: AppSpacing.xs,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected
                                      ? Icons.folder_rounded
                                      : Icons.folder_outlined,
                                  color: isSelected
                                      ? colors.primary
                                      : colors.onSurface.withValues(alpha: 0.4),
                                  size: 24,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        displayName,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          fontWeight: isSelected
                                              ? FontWeight.w500
                                              : FontWeight.w400,
                                          color: colors.onSurface,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '$shortPath  •  $count música${count == 1 ? '' : 's'}',
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: colors.onSurface.withValues(alpha: 0.4),
                                          fontSize: 10,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Checkbox(
                                  value: isSelected,
                                  onChanged: (_) {
                                    setState(() {
                                      if (isSelected) {
                                        selected.remove(folder);
                                      } else {
                                        selected.add(folder);
                                      }
                                    });
                                  },
                                  activeColor: colors.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Botão Confirmar
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: selected.isEmpty
                          ? null
                          : () {
                              Navigator.pop(ctx);
                              ref
                                  .read(libraryProvider.notifier)
                                  .setSelectedFolders(selected.toList());
                            },
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        ),
                      ),
                      child: const Text('Confirmar'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── INTERFACE DIALOGS ──

  void _showNowPlayingStyleDialog(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final current = ref.read(themeProvider).nowPlayingStyle;
    final options = [
      (NowPlayingStyle.classic, 'Clássico', Icons.crop_square_rounded),
      (NowPlayingStyle.circular, 'Circular', Icons.circle_outlined),
      (NowPlayingStyle.large, 'Cinema', Icons.crop_landscape_rounded),
      (NowPlayingStyle.fullBlur, 'Imersivo', Icons.blur_circular_rounded),
      (NowPlayingStyle.vinyl, 'Vinil', Icons.album_rounded),
      (NowPlayingStyle.minimalist, 'Minimalista', Icons.space_bar_rounded),
      (NowPlayingStyle.aurora, 'Aurora', Icons.auto_awesome_rounded),
      (NowPlayingStyle.elegant, 'Elegante', Icons.diamond_outlined),
      (NowPlayingStyle.wave, 'Ondas', Icons.waves_rounded),
      (NowPlayingStyle.mosaic, 'Mosaico', Icons.grid_view_rounded),
    ];
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: colors.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        title: const Text('Estilo Now Playing'),
        children: options.map((o) {
          return _dialogOption(
            ctx, o.$2, o.$3, current == o.$1,
            () {
              ref.read(themeProvider.notifier).setNowPlayingStyle(o.$1);
              Navigator.pop(ctx);
            },
          );
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
            AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: AppSpacing.xs),
              Container(
                width: 32, height: 4,
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
                  Color(0xFF6A3DE8), Color(0xFF3A1F8C), Color(0xFF1A1028),
                ],
                isLinear: true,
                onTap: () {
                  ref.read(themeProvider.notifier)
                      .setNowPlayingColorStyle(NowPlayingColorStyle.degrade);
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              // Gradient option
              _ColorStyleOption(
                title: 'Gradiente',
                description: 'Múltiplas cores da capa em gradiente radial fluido',
                icon: Icons.blur_on_rounded,
                isSelected: current == NowPlayingColorStyle.gradient,
                colors: colors,
                theme: theme,
                previewColors: const [
                  Color(0xFF00BCD4), Color(0xFFFF9800), Color(0xFFE91E63),
                ],
                isLinear: false,
                onTap: () {
                  ref.read(themeProvider.notifier)
                      .setNowPlayingColorStyle(NowPlayingColorStyle.gradient);
                  Navigator.pop(ctx);
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
    final current = ref.read(themeProvider).navBarStyle;
    final options = [
      (NavBarStyle.glass, 'Vidro', Icons.blur_on_rounded),
      (NavBarStyle.artwork, 'Capa', Icons.image_rounded),
      (NavBarStyle.solid, 'Sólido', Icons.square_rounded),
      (NavBarStyle.minimal, 'Minimal', Icons.minimize_rounded),
    ];
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: colors.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        title: const Text('Barra de Navegação'),
        children: options.map((o) {
          return _dialogOption(
            ctx, o.$2, o.$3, current == o.$1,
            () {
              ref.read(themeProvider.notifier).setNavBarStyle(o.$1);
              Navigator.pop(ctx);
            },
          );
        }).toList(),
      ),
    );
  }

  void _showMiniPlayerStyleDialog(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final current = ref.read(themeProvider).miniPlayerStyle;
    final options = [
      (MiniPlayerStyle.glass, 'Vidro', Icons.blur_on_rounded),
      (MiniPlayerStyle.artwork, 'Capa', Icons.image_rounded),
      (MiniPlayerStyle.minimal, 'Minimal', Icons.minimize_rounded),
      (MiniPlayerStyle.card, 'Card', Icons.credit_card_rounded),
      (MiniPlayerStyle.dynamic, 'Dinâmico', Icons.auto_awesome_rounded),
    ];
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: colors.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        title: const Text('Estilo Mini Player'),
        children: options.map((o) {
          return _dialogOption(
            ctx, o.$2, o.$3, current == o.$1,
            () {
              ref.read(themeProvider.notifier).setMiniPlayerStyle(o.$1);
              Navigator.pop(ctx);
            },
          );
        }).toList(),
      ),
    );
  }

  void _showMediaBarStyleDialog(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final current = ref.read(themeProvider).mediaBarStyle;
    final options = [
      (MediaBarStyle.minimal, 'Minimal', Icons.remove_rounded),
      (MediaBarStyle.glow, 'Brilho', Icons.flare_rounded),
      (MediaBarStyle.gradient, 'Gradiente', Icons.gradient_rounded),
      (MediaBarStyle.thick, 'Espessa', Icons.linear_scale_rounded),
      (MediaBarStyle.classic, 'Clássico', Icons.tune_rounded),
    ];
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: colors.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        title: const Text('Barra de Progresso'),
        children: options.map((o) {
          return _dialogOption(
            ctx, o.$2, o.$3, current == o.$1,
            () {
              ref.read(themeProvider.notifier).setMediaBarStyle(o.$1);
              Navigator.pop(ctx);
            },
          );
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
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
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
  ConsumerState<_CustomNpColorsSheet> createState() => _CustomNpColorsSheetState();
}

class _CustomNpColorsSheetState extends ConsumerState<_CustomNpColorsSheet> {
  static const _presetColors = [
    Color(0xFFE53935), Color(0xFFD81B60), Color(0xFF8E24AA),
    Color(0xFF5E35B1), Color(0xFF3949AB), Color(0xFF1E88E5),
    Color(0xFF00ACC1), Color(0xFF00897B), Color(0xFF43A047),
    Color(0xFF7CB342), Color(0xFFFDD835), Color(0xFFFB8C00),
    Color(0xFFFF7043), Color(0xFF6D4C41), Color(0xFF546E7A),
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
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.xs),
            Container(
              width: 32, height: 4,
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
              title: Text('Usar cores personalizadas', style: theme.textTheme.bodyMedium),
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
              activeColor: accentColor ?? colors.primary,
              activeTrackColor: accentColor?.withValues(alpha: 0.3),
              trackOutlineColor: WidgetStatePropertyAll(colors.onSurface.withValues(alpha: 0.15)),
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
              width: 28, height: 28,
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
              final isSelected = color != null && color!.value == c.value;
              return GestureDetector(
                onTap: () => onColorSelected(c),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: Colors.white, width: 2.5)
                        : null,
                    boxShadow: isSelected
                        ? [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 8)]
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
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
