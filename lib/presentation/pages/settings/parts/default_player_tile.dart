part of '../settings_page.dart';

// ============================================================
// DEFAULT PLAYER TILE — status do leitor padrão de áudio (Android)
// ============================================================

/// Tile que mostra se o Constanza é o leitor de áudio padrão e abre um diálogo
/// explicando como defini-lo. Re-checa o status ao voltar das configurações
/// do sistema (lifecycle resumed). Só faz sentido em Android.
class _DefaultPlayerTile extends ConsumerStatefulWidget {
  const _DefaultPlayerTile({required this.colors, required this.theme});

  final ColorScheme colors;
  final ThemeData theme;

  @override
  ConsumerState<_DefaultPlayerTile> createState() => _DefaultPlayerTileState();
}

class _DefaultPlayerTileState extends ConsumerState<_DefaultPlayerTile>
    with WidgetsBindingObserver {
  bool? _isDefault; // null = ainda checando

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Ao voltar das configurações do sistema, re-checa o status.
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final v = await DefaultPlayerService.isDefault();
    if (mounted) setState(() => _isDefault = v);
  }

  /// Primeira URI `content://` da biblioteca, para disparar o resolver
  /// "Abrir com" e o usuário escolher o Constanza como padrão.
  String? _sampleAudioUri() {
    for (final s in ref.read(libraryProvider).songs) {
      if (s.uri.startsWith('content://')) return s.uri;
    }
    return null;
  }

  Future<void> _openDialog() async {
    final l10n = AppLocalizations.of(context);
    final isDefault = _isDefault == true;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settingsDefaultPlayer),
        content: Text(
          isDefault
              ? l10n.defaultPlayerDialogBodyActive
              : l10n.defaultPlayerDialogBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.defaultPlayerDialogClose),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Já é padrão → abrir settings (para limpar). Caso contrário →
              // resolver "Abrir com" de um áudio real (deixa escolher "Sempre").
              if (isDefault) {
                DefaultPlayerService.requestSetDefault(sampleAudioUri: null);
              } else {
                startSetDefaultFlow(context, sampleAudioUri: _sampleAudioUri());
              }
            },
            child: Text(
              isDefault
                  ? l10n.defaultPlayerOpenSettings
                  : l10n.defaultPlayerSetAsDefault,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDefault = _isDefault;
    final subtitle = isDefault == null
        ? l10n.defaultPlayerStatusChecking
        : (isDefault
              ? l10n.defaultPlayerStatusYes
              : l10n.defaultPlayerStatusNo);
    return _SettingsTile(
      icon: isDefault == true
          ? Icons.verified_rounded
          : Icons.library_music_outlined,
      title: l10n.settingsDefaultPlayer,
      subtitle: subtitle,
      colors: widget.colors,
      theme: widget.theme,
      trailing: isDefault == true
          ? Icon(
              Icons.check_circle_rounded,
              size: 18,
              color: widget.colors.primary,
            )
          : null,
      onTap: _openDialog,
    );
  }
}
