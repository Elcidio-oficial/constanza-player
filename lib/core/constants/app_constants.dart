/// Constantes globais do Constanza Músicas.
abstract final class AppConstants {
  // ============================================================
  // APP INFO
  // ============================================================
  static const String appName = 'Constanza Músicas';
  static const String appTagline = 'Sua música. Seu silêncio. Seu momento.';
  static const String appVersion = '1.3.3';
  static const String appAuthor = 'Elcídio Crisanto';

  // ============================================================
  // ANIMAÇÃO — Durações
  // ============================================================
  static const Duration instant = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration dramatic = Duration(milliseconds: 800);

  // ============================================================
  // SPLASH
  // ============================================================
  static const Duration splashDuration = Duration(milliseconds: 2500);

  // ============================================================
  // MINI PLAYER
  // ============================================================
  static const double miniPlayerHeight = 64.0;

  // ============================================================
  // ALBUM ART
  // ============================================================
  static const double albumArtMini = 48.0;
  static const double albumArtList = 48.0;
  static const double albumArtNowPlaying = 280.0;
  static const double albumArtCarousel = 120.0;
}
