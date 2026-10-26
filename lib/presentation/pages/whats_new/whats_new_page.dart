import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:constanza_player/core/constants/release_notes.dart';
import 'package:constanza_player/core/theme/app_spacing.dart';
import 'package:constanza_player/core/theme/color_scheme_x.dart';
import 'package:constanza_player/l10n/gen/app_localizations.dart';

/// Ecrã "O que há de novo": aparece uma vez depois de uma atualização (ver
/// [shouldShowWhatsNew]) e fica acessível em Configurações → Sobre.
class WhatsNewPage extends StatelessWidget {
  const WhatsNewPage({super.key, required this.notes});

  final ReleaseNotes notes;

  /// Abre como página inteira por cima de tudo (navegador raiz).
  static Future<void> open(BuildContext context, ReleaseNotes notes) {
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => WhatsNewPage(notes: notes),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final fixes = notes.fixes(locale);

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Center(
          // Na janela larga do Windows a coluna não estica até às bordas.
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.xl,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    children: [
                      _Header(notes: notes),
                      const SizedBox(height: AppSpacing.xl),
                      for (final (i, item) in notes.highlights.indexed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _HighlightCard(item: item, locale: locale)
                              .animate(delay: (120 + 70 * i).ms)
                              .fadeIn(duration: 320.ms)
                              .slideY(
                                begin: 0.08,
                                end: 0,
                                curve: Curves.easeOut,
                              ),
                        ),
                      if (fixes.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          l10n.whatsNewFixesTitle,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        for (final fix in fixes)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Icon(
                                    Icons.check_circle_rounded,
                                    size: 18,
                                    color: colors.primary,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    fix,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colors.fadedText(0.75),
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        l10n.whatsNewContinue,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.notes});
  final ReleaseNotes notes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final date = MaterialLocalizations.of(context).formatMediumDate(notes.date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset('assets/icon/icon.png', fit: BoxFit.cover),
        ).animate().scale(
          begin: const Offset(0.85, 0.85),
          duration: 380.ms,
          curve: Curves.easeOutBack,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          l10n.whatsNewEyebrow,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          l10n.whatsNewTitle(notes.version),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          date,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.fadedText(0.5),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({required this.item, required this.locale});
  final ReleaseNoteItem item;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final radius = BorderRadius.circular(AppSpacing.radiusLg);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: colors.isLight
          ? colors.lightCard(borderRadius: radius)
          : BoxDecoration(
              color: colors.onSurface.withValues(alpha: 0.05),
              borderRadius: radius,
              border: Border.all(
                color: colors.onSurface.withValues(alpha: 0.08),
              ),
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(item.icon, color: colors.primary, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title(locale),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.body(locale),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.fadedText(0.7),
                    height: 1.4,
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
