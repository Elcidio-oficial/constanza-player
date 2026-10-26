import 'package:flutter/material.dart';

extension ColorSchemeX on ColorScheme {
  /// Texto/ícone secundário como fração de [onSurface].
  ///
  /// No escuro devolve `onSurface` com a opacidade pedida, como sempre foi.
  /// No claro a mesma opacidade dá cinza sem contraste (branco a 40% sobre
  /// preto lê-se; preto a 40% sobre branco não), por isso é remapeada para
  /// `0,45 + a·0,55`: 0,35→0,64, 0,4→0,67, 0,5→0,72. A ordem entre níveis
  /// mantém-se e o texto fica acima de ~4,5:1.
  Color fadedText(double alpha) => onSurface.withValues(
    alpha: brightness == Brightness.dark ? alpha : 0.45 + alpha * 0.55,
  );

  bool get isLight => brightness == Brightness.light;

  /// Cartão elevado do modo claro: superfície branca (com um toque opcional
  /// do destaque), contorno fino e sombra larga e fraca. No claro, o "vidro
  /// tingido + brilho" do escuro vira cinza sujo com sombra pesada.
  BoxDecoration lightCard({
    required BorderRadius borderRadius,
    double tint = 0,
  }) => BoxDecoration(
    color: Color.alphaBlend(
      primary.withValues(alpha: tint),
      surfaceContainerLowest,
    ),
    borderRadius: borderRadius,
    border: Border.all(color: outlineVariant.withValues(alpha: 0.7)),
    boxShadow: const [
      BoxShadow(color: Color(0x0F000000), blurRadius: 18, offset: Offset(0, 6)),
      BoxShadow(color: Color(0x08000000), blurRadius: 3, offset: Offset(0, 1)),
    ],
  );
}
