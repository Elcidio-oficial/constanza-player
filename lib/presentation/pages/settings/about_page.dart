import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:constanza_player/core/constants/app_constants.dart';
import 'package:constanza_player/core/constants/release_notes.dart';
import 'package:constanza_player/core/theme/app_spacing.dart';
import 'package:constanza_player/core/theme/color_scheme_x.dart';
import 'package:constanza_player/l10n/gen/app_localizations.dart';
import 'package:constanza_player/presentation/pages/whats_new/whats_new_page.dart';
import 'package:constanza_player/services/store_service.dart';

/// Configurações → Sobre: identidade do app, versão, novidades e links.
/// Quem fez o app tem página própria (Configurações → Desenvolvedor).
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final cardRadius = BorderRadius.circular(AppSpacing.radiusLg);

    Future<void> openUrl(String url) async {
      final ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(url)));
      }
    }

    Future<void> rate() async {
      final ok = await StoreService.openListing();
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.aboutRateFailed)));
      }
    }

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        title: Text(l10n.settingsAboutApp(AppConstants.appName)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.xxl,
            ),
            children: [
              // ── Identidade ──
              Column(
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.16),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/icon/icon.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    AppConstants.appName,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusFull,
                      ),
                    ),
                    child: Text(
                      l10n.aboutVersionLabel(AppConstants.appVersion),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    l10n.aboutDialogTagline,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.fadedText(0.6),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 300.ms),
              const SizedBox(height: AppSpacing.xl),

              // ── Privacidade em uma linha ──
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colors.tertiary.withValues(alpha: 0.10),
                  borderRadius: cardRadius,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      color: colors.tertiary,
                      size: 22,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        l10n.aboutLocalFirst,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.fadedText(0.8),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // ── Ações ──
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: colors.isLight
                    ? colors.lightCard(borderRadius: cardRadius)
                    : BoxDecoration(
                        color: colors.onSurface.withValues(alpha: 0.04),
                        borderRadius: cardRadius,
                        border: Border.all(
                          color: colors.onSurface.withValues(alpha: 0.08),
                        ),
                      ),
                child: Column(
                  children: [
                    _AboutTile(
                      icon: Icons.auto_awesome_rounded,
                      title: l10n.aboutWhatsNew,
                      subtitle: l10n.aboutWhatsNewDesc(
                        currentReleaseNotes.version,
                      ),
                      onTap: () =>
                          WhatsNewPage.open(context, currentReleaseNotes),
                    ),
                    const _TileDivider(),
                    _AboutTile(
                      icon: Icons.star_outline_rounded,
                      title: l10n.settingsRate,
                      subtitle: l10n.aboutRateDesc,
                      external: true,
                      onTap: rate,
                    ),
                    const _TileDivider(),
                    _AboutTile(
                      icon: Icons.privacy_tip_outlined,
                      title: l10n.settingsPrivacyPolicy,
                      subtitle: l10n.settingsPrivacyPolicyDesc,
                      external: true,
                      onTap: () => openUrl(AppConstants.privacyPolicyUrl),
                    ),
                    const _TileDivider(),
                    _AboutTile(
                      icon: Icons.description_outlined,
                      title: l10n.settingsLicenses,
                      subtitle: l10n.settingsLicensesDesc,
                      onTap: () => showLicensePage(
                        context: context,
                        applicationName: AppConstants.appName,
                        applicationVersion: AppConstants.appVersion,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                '© ${currentReleaseNotes.date.year} ${AppConstants.appName}',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.fadedText(0.35),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutTile extends StatelessWidget {
  const _AboutTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.external = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// Abre fora do app (loja, navegador): seta de link em vez de chevron.
  final bool external;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Icon(icon, size: 20, color: colors.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.fadedText(0.5),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              external
                  ? Icons.open_in_new_rounded
                  : Icons.chevron_right_rounded,
              size: external ? 18 : 22,
              color: colors.fadedText(0.35),
            ),
          ],
        ),
      ),
    );
  }
}

class _TileDivider extends StatelessWidget {
  const _TileDivider();

  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    indent: AppSpacing.md + 38 + AppSpacing.md,
    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
  );
}
