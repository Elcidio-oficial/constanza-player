import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:constanza_player/core/constants/app_constants.dart';
import 'package:constanza_player/core/theme/app_spacing.dart';
import 'package:constanza_player/l10n/gen/app_localizations.dart';

/// Página "Desenvolvedor" — quem faz o app e como entrar em contato.
class DeveloperPage extends StatelessWidget {
  const DeveloperPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.devTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const SizedBox(height: AppSpacing.md),
          Center(
            child: _Avatar(colors: colors, theme: theme),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            AppConstants.appAuthor,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            l10n.devRole(AppConstants.appName),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _SectionLabel(l10n.devContact, theme: theme, colors: colors),
          _LinkCard(
            colors: colors,
            children: [
              _LinkTile(
                icon: Icons.mail_outline_rounded,
                title: l10n.devEmail,
                subtitle: AppConstants.developerEmail,
                uri: Uri(
                  scheme: 'mailto',
                  path: AppConstants.developerEmail,
                  query: 'subject=${Uri.encodeComponent(AppConstants.appName)}',
                ),
              ),
              _LinkTile(
                icon: Icons.code_rounded,
                title: 'GitHub',
                subtitle: 'Elcidio-oficial',
                uri: Uri.parse(AppConstants.developerGithubUrl),
              ),
              _LinkTile(
                icon: Icons.language_rounded,
                title: l10n.devWebsite,
                subtitle: Uri.parse(AppConstants.developerWebsiteUrl).host,
                uri: Uri.parse(AppConstants.developerWebsiteUrl),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionLabel(l10n.devApp, theme: theme, colors: colors),
          _LinkCard(
            colors: colors,
            children: [
              _LinkTile(
                icon: Icons.bug_report_outlined,
                title: l10n.devReportIssue,
                subtitle: l10n.devReportIssueDesc,
                uri: Uri.parse(AppConstants.issuesUrl),
              ),
              _LinkTile(
                icon: Icons.privacy_tip_outlined,
                title: l10n.settingsPrivacyPolicy,
                subtitle: l10n.settingsPrivacyPolicyDesc,
                uri: Uri.parse(AppConstants.privacyPolicyUrl),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            '${AppConstants.appName} · v${AppConstants.appVersion}',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.colors, required this.theme});
  final ColorScheme colors;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final initials = AppConstants.appAuthor
        .split(' ')
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0])
        .join();
    final fallback = Container(
      color: colors.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: theme.textTheme.headlineMedium?.copyWith(
          color: colors.onSurface.withValues(alpha: 0.7),
        ),
      ),
    );
    return ClipOval(
      child: SizedBox.square(
        dimension: 112,
        child: Image.asset(
          AppConstants.developerPhotoAsset,
          fit: BoxFit.cover,
          cacheWidth: 336,
          errorBuilder: (_, _, _) => fallback,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {required this.theme, required this.colors});
  final String text;
  final ThemeData theme;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xs,
        bottom: AppSpacing.xs,
      ),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: colors.onSurface.withValues(alpha: 0.45),
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _LinkCard extends StatelessWidget {
  const _LinkCard({required this.children, required this.colors});
  final List<Widget> children;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.uri,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Uri uri;

  // Só abre esquemas esperados, sempre fora do app (nada de WebView).
  static const _allowedSchemes = {'https', 'mailto'};

  Future<void> _open(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = AppLocalizations.of(context).devLinkError;
    var ok = false;
    if (_allowedSchemes.contains(uri.scheme)) {
      try {
        ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
    if (!ok) messenger.showSnackBar(SnackBar(content: Text(error)));
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.open_in_new_rounded, size: 18),
      onTap: () => _open(context),
    );
  }
}
