part of '../settings_page.dart';

// ============================================================
// BACKUP SHEET — export via share, import via clipboard
// ============================================================

class _BackupSheet extends ConsumerStatefulWidget {
  const _BackupSheet();

  @override
  ConsumerState<_BackupSheet> createState() => _BackupSheetState();
}

class _BackupSheetState extends ConsumerState<_BackupSheet> {
  bool _busy = false;

  Future<void> _export() async {
    setState(() => _busy = true);
    final ok = await BackupService.exportAndShare();
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).backupExportFailed),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _importFromFile() async {
    setState(() => _busy = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        withData: true,
      );
      if (!mounted) return;
      if (result == null || result.files.isEmpty) {
        return;
      }
      final picked = result.files.first;

      String? content;
      final bytes = picked.bytes;
      if (bytes != null && bytes.isNotEmpty) {
        content = utf8.decode(bytes, allowMalformed: true);
      } else if (picked.path != null) {
        content = await File(picked.path!).readAsString();
      }
      if (content == null || content.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).backupFileEmptyOrUnreadable,
            ),
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }

      final restored = await BackupService.importFromString(content);
      if (!mounted) return;
      if (restored == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).backupInvalidFormat),
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }

      // ── Aplicar imediatamente — sem necessidade de reiniciar o app ──────
      // 1. Tema e configurações de áudio: recarga direta no estado Riverpod.
      await ref.read(themeProvider.notifier).reloadFromStorage();
      ref.read(audioSettingsProvider.notifier).reloadFromStorage();
      // 2. Playlists: recarrega do SharedPreferences e aguarda a biblioteca
      //    resolver os IDs das músicas via restoreSongsFromLibrary (app_shell).
      ref.read(playlistProvider.notifier).loadFromStorage();
      // 3. Biblioteca: recarrega favoritos/pastas/exclusões e refaz o scan.
      //    Fire-and-forget — a UI reage via LibraryStatus (loading → loaded).
      unawaited(ref.read(libraryProvider.notifier).reloadFromBackup());

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).backupRestoredOk(restored),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).backupFileOpenError(e.toString()),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
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
              AppLocalizations.of(context).backupTitle,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              AppLocalizations.of(context).backupDescription,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.fadedText(0.5),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: _busy ? null : _export,
              icon: const Icon(Icons.upload_rounded, size: 18),
              label: Text(AppLocalizations.of(context).backupExport),
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton.tonalIcon(
              onPressed: _busy ? null : _importFromFile,
              icon: const Icon(Icons.folder_open_rounded, size: 18),
              label: Text(AppLocalizations.of(context).backupImportFile),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              AppLocalizations.of(context).backupNote,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.fadedText(0.35),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
