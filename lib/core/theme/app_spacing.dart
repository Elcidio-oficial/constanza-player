/// Espaçamento do Constanza Músicas — Grid de 8pt.
///
/// Cada valor é múltiplo de 4, criando ritmo visual consistente.
abstract final class AppSpacing {
  /// 4dp — Espaço interno de ícones
  static const double xxs = 4;

  /// 8dp — Entre elementos inline
  static const double xs = 8;

  /// 12dp — Padding interno de cards
  static const double sm = 12;

  /// 16dp — Padding padrão
  static const double md = 16;

  /// 24dp — Entre seções
  static const double lg = 24;

  /// 32dp — Margens externas
  static const double xl = 32;

  /// 48dp — Espaço de respiração
  static const double xxl = 48;

  /// 64dp — Hero sections
  static const double huge = 64;

  // ============================================================
  // BORDER RADIUS
  // ============================================================

  /// 0dp — Elementos utilitários
  static const double radiusNone = 0;

  /// 4dp — Badges, chips pequenos
  static const double radiusXs = 4;

  /// 8dp — Botões secundários
  static const double radiusSm = 8;

  /// 12dp — Cards padrão
  static const double radiusMd = 12;

  /// 16dp — Cards destacados, capas de álbum
  static const double radiusLg = 16;

  /// 24dp — Bottom sheets
  static const double radiusXl = 24;

  /// 9999dp — Círculos (botões, avatares)
  static const double radiusFull = 9999;

  // ============================================================
  // TAMANHOS DE ÍCONE
  // ============================================================

  /// 16dp — Ícones inline
  static const double iconSm = 16;

  /// 24dp — Ícones padrão
  static const double iconMd = 24;

  /// 32dp — Bottom nav, ações principais
  static const double iconLg = 32;

  /// 48dp — Now Playing controls
  static const double iconXl = 48;

  /// 64dp — Play/Pause central
  static const double iconHero = 64;
}
