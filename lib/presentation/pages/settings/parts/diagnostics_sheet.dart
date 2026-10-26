part of '../settings_page.dart';

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
        SnackBar(
          content: Text(AppLocalizations.of(context).diagnosticsCleared),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
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
              l10n.diagnosticsTitle,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _count < 0
                  ? l10n.diagnosticsLoading
                  : hasLogs
                  ? l10n.diagnosticsCount(_count)
                  : l10n.diagnosticsNone,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.diagnosticsExplanation,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: !hasLogs || _busy ? null : _share,
              icon: const Icon(Icons.ios_share_rounded, size: 18),
              label: Text(l10n.diagnosticsShare),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: !hasLogs || _busy ? null : _clear,
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: Text(l10n.diagnosticsClear),
            ),
          ],
        ),
      ),
    );
  }
}
