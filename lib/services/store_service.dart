import 'dart:io';

import 'package:constanza_player/core/constants/app_constants.dart';
import 'package:url_launcher/url_launcher.dart';

/// Abre a página do app na loja para avaliar.
abstract final class StoreService {
  /// Android: app da Play Store (`market://`), com o site como reserva quando
  /// a loja não existe (aparelhos sem Google). Restantes plataformas: o site.
  /// Devolve `false` se nada abriu.
  static Future<bool> openListing() async {
    if (Platform.isAndroid) {
      final market = Uri.parse(
        'market://details?id=${AppConstants.playStoreId}',
      );
      try {
        if (await launchUrl(market, mode: LaunchMode.externalApplication)) {
          return true;
        }
      } catch (_) {
        // Sem app da loja: cai no site abaixo.
      }
    }
    try {
      return await launchUrl(
        Uri.parse(AppConstants.playStoreWebUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }
}
