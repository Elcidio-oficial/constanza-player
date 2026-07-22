import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Um pedido para abrir áudio externo (vindo de "Abrir com" / Compartilhar).
class OpenAudioRequest {
  const OpenAudioRequest({required this.uri, this.title});

  /// URI crua entregue pelo Android — `content://…` ou `file://…`.
  final String uri;

  /// Nome de exibição resolvido pelo nativo (DISPLAY_NAME / last path segment).
  final String? title;
}

/// Ponte com a camada nativa para a funcionalidade de **leitor padrão de áudio**.
///
/// Android não expõe um RoleManager para "música padrão" (ao contrário de
/// SMS/discador/navegador). O mecanismo oficial é a *associação de arquivos*:
/// o app declara intent-filters de áudio (ver AndroidManifest), passa a aparecer
/// no "Abrir com" e o usuário escolhe "Sempre". Este serviço:
///   • recebe os áudios abertos externamente (cold start e app já vivo);
///   • detecta se já somos o handler padrão;
///   • abre a tela de "Abrir por padrão" do sistema para o usuário definir.
///
/// Em plataformas não-Android todas as chamadas são no-ops seguros.
class DefaultPlayerService {
  DefaultPlayerService._();

  static const MethodChannel _channel = MethodChannel(
    'com.constanza.constanza_player/intent',
  );

  static void Function(List<OpenAudioRequest>)? _onOpen;

  /// URI da faixa de amostra usada para disparar o resolver "Abrir com" ao
  /// definir o app como padrão. Quando o usuário escolhe "Sempre", o sistema
  /// reenvia esse MESMO áudio como um ACTION_VIEW — sem este marcador, o app
  /// trataria o retorno como "tocar agora" e abriria o Now Playing. Marcamos
  /// para suprimir só esse eco; opens reais do explorador tocam normalmente.
  static String? _setDefaultSampleUri;
  static DateTime? _setDefaultAt;

  /// Registra o handler chamado quando o app recebe áudio externo enquanto
  /// já está vivo (Android empurra via `openUris`). Idempotente.
  static void registerOpenHandler(
    void Function(List<OpenAudioRequest>) handler,
  ) {
    _onOpen = handler;
    _channel.setMethodCallHandler(_handleCall);
  }

  static Future<dynamic> _handleCall(MethodCall call) async {
    if (call.method == 'openUris') {
      final reqs = _parse(call.arguments);
      if (reqs.isNotEmpty) _onOpen?.call(reqs);
    }
    return null;
  }

  /// Drena os áudios pendentes capturados no cold start (antes de o handler
  /// nativo conseguir empurrar pelo canal). Chamar uma vez na inicialização.
  static Future<List<OpenAudioRequest>> consumePending() async {
    if (!Platform.isAndroid) return const [];
    try {
      final res = await _channel.invokeMethod<dynamic>(
        'consumePendingOpenUris',
      );
      return _parse(res);
    } catch (e) {
      debugPrint('[DefaultPlayerService] consumePending error: $e');
      return const [];
    }
  }

  /// `true` se o Constanza já é o app padrão para abrir arquivos de áudio.
  static Future<bool> isDefault() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('isDefaultAudioApp') ?? false;
    } catch (e) {
      debugPrint('[DefaultPlayerService] isDefault error: $e');
      return false;
    }
  }

  /// Inicia o fluxo para o usuário definir o Constanza como padrão de áudio.
  ///
  /// Caminho real no Android moderno: disparar o resolver "Abrir com" de um
  /// arquivo de áudio ([sampleAudioUri], um `content://` da biblioteca) — o
  /// sistema mostra "Apenas uma vez / Sempre", e escolher "Sempre" define o
  /// padrão. A tela de settings ("Abrir por padrão") só gerencia links da Web,
  /// então é apenas fallback quando não há áudio disponível.
  static Future<void> requestSetDefault({String? sampleAudioUri}) async {
    if (!Platform.isAndroid) return;
    try {
      if (sampleAudioUri != null && sampleAudioUri.isNotEmpty) {
        // Marca a amostra para suprimir seu eco (ver [consumeSetDefaultEcho]).
        _setDefaultSampleUri = sampleAudioUri;
        _setDefaultAt = DateTime.now();
        await _channel.invokeMethod('openAudioChooser', {
          'uri': sampleAudioUri,
        });
      } else {
        await _channel.invokeMethod('openDefaultAppSettings');
      }
    } catch (e) {
      debugPrint('[DefaultPlayerService] requestSetDefault error: $e');
    }
  }

  /// `true` (consumindo o marcador) se [reqs] for o retorno do nosso próprio
  /// fluxo de "tornar padrão" — i.e., contém a faixa de amostra que abrimos há
  /// pouco. O chamador deve então NÃO tocar nem navegar. Opens legítimos do
  /// explorador (URI diferente, ou marcador expirado/ausente) retornam `false`.
  static bool consumeSetDefaultEcho(List<OpenAudioRequest> reqs) {
    final sample = _setDefaultSampleUri;
    final at = _setDefaultAt;
    if (sample == null || at == null) return false;
    // Expira em 30s: um resolver cancelado (back) não deve suprimir um open
    // real da mesma faixa feito depois.
    if (DateTime.now().difference(at) > const Duration(seconds: 30)) {
      _setDefaultSampleUri = null;
      _setDefaultAt = null;
      return false;
    }
    final isEcho = reqs.any((r) => r.uri == sample);
    if (isEcho) {
      _setDefaultSampleUri = null;
      _setDefaultAt = null;
    }
    return isEcho;
  }

  static List<OpenAudioRequest> _parse(dynamic args) {
    if (args is! List) return const [];
    final out = <OpenAudioRequest>[];
    for (final item in args) {
      if (item is Map) {
        final uri = item['uri']?.toString() ?? '';
        if (uri.isEmpty) continue;
        final title = item['title']?.toString();
        out.add(
          OpenAudioRequest(
            uri: uri,
            title: (title == null || title.isEmpty) ? null : title,
          ),
        );
      }
    }
    return out;
  }
}
