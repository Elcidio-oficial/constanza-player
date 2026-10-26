import 'package:flutter/material.dart';
import 'package:constanza_player/l10n/gen/app_localizations.dart';
import 'package:constanza_player/services/default_player_service.dart';

/// Fluxo único de "tornar o Constanza o leitor padrão" (banner e Configurações).
///
/// Se outro app já for o padrão para áudio, o Android não mostra o resolver
/// "Apenas uma vez / Sempre": abriria a amostra direto nesse app (no MIUI, a
/// pré-visualização do Música, que parecia ser o nosso leitor). Nenhum app pode
/// limpar o padrão de outro, por isso explicamos o caminho e abrimos as
/// definições desse app. Sem padrão, abre o resolver como antes.
Future<void> startSetDefaultFlow(
  BuildContext context, {
  required String? sampleAudioUri,
}) async {
  final other = await DefaultPlayerService.otherDefault(sampleAudioUri);
  if (other == null) {
    await DefaultPlayerService.requestSetDefault(
      sampleAudioUri: sampleAudioUri,
    );
    return;
  }
  if (!context.mounted) return;
  final l10n = AppLocalizations.of(context);
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.defaultPlayerBlockedTitle),
      content: Text(l10n.defaultPlayerBlockedBody(other.label)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l10n.defaultPlayerDialogClose),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(ctx);
            DefaultPlayerService.openAppDetails(other.package);
          },
          child: Text(l10n.defaultPlayerBlockedAction(other.label)),
        ),
      ],
    ),
  );
}
