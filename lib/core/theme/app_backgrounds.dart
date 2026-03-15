import 'package:flutter/material.dart';

/// Tipos de fundo do app.
enum BackgroundType { none, gradient, image }

/// Preset de gradiente para fundo.
class GradientPreset {
  const GradientPreset({
    required this.id,
    required this.name,
    required this.colors,
    this.begin = Alignment.topLeft,
    this.end = Alignment.bottomRight,
    this.stops,
  });

  final String id;
  final String name;
  final List<Color> colors;
  final Alignment begin;
  final Alignment end;
  final List<double>? stops;

  LinearGradient toGradient() =>
      LinearGradient(colors: colors, begin: begin, end: end, stops: stops);
}

/// Presets de fundo disponíveis.
abstract final class AppBackgrounds {
  static const List<GradientPreset> gradients = [
    // Escuros (para tema dark)
    GradientPreset(
      id: 'midnight',
      name: 'Meia-Noite',
      colors: [Color(0xFF0D1B2A), Color(0xFF1B263B), Color(0xFF0D1B2A)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    GradientPreset(
      id: 'aurora',
      name: 'Aurora',
      colors: [Color(0xFF0A0A0A), Color(0xFF1A0A2E), Color(0xFF0D1F2D)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    GradientPreset(
      id: 'deep_ocean',
      name: 'Oceano Profundo',
      colors: [Color(0xFF0A0F1A), Color(0xFF0A1628), Color(0xFF0D0A1A)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    GradientPreset(
      id: 'forest',
      name: 'Floresta',
      colors: [Color(0xFF0A1A0A), Color(0xFF0D1F12), Color(0xFF0A0F0A)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    GradientPreset(
      id: 'wine',
      name: 'Vinho',
      colors: [Color(0xFF1A0A0F), Color(0xFF2D0A1A), Color(0xFF1A0A0F)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    GradientPreset(
      id: 'sunset',
      name: 'Pôr do Sol',
      colors: [Color(0xFF1A0F0A), Color(0xFF2D1A0A), Color(0xFF1A100A)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    // Claros (para tema light)
    GradientPreset(
      id: 'cloud',
      name: 'Nuvem',
      colors: [Color(0xFFF0F4F8), Color(0xFFE2E8F0), Color(0xFFF7FAFC)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    GradientPreset(
      id: 'lavender',
      name: 'Lavanda',
      colors: [Color(0xFFF5F3FF), Color(0xFFEDE9FE), Color(0xFFF5F3FF)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    GradientPreset(
      id: 'peach',
      name: 'Pêssego',
      colors: [Color(0xFFFFF7ED), Color(0xFFFED7AA), Color(0xFFFFF7ED)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    GradientPreset(
      id: 'mint',
      name: 'Menta',
      colors: [Color(0xFFF0FDF4), Color(0xFFD1FAE5), Color(0xFFF0FDF4)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    GradientPreset(
      id: 'rose',
      name: 'Rosa',
      colors: [Color(0xFFFFF1F2), Color(0xFFFFE4E6), Color(0xFFFFF1F2)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    GradientPreset(
      id: 'sky',
      name: 'Céu',
      colors: [Color(0xFFF0F9FF), Color(0xFFBAE6FD), Color(0xFFF0F9FF)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  ];

  /// Gradientes escuros (para dark mode).
  static List<GradientPreset> get darkGradients => gradients
      .where(
        (g) => [
          'midnight',
          'aurora',
          'deep_ocean',
          'forest',
          'wine',
          'sunset',
        ].contains(g.id),
      )
      .toList();

  /// Gradientes claros (para light mode).
  static List<GradientPreset> get lightGradients => gradients
      .where(
        (g) => [
          'cloud',
          'lavender',
          'peach',
          'mint',
          'rose',
          'sky',
        ].contains(g.id),
      )
      .toList();

  /// Busca preset por ID.
  static GradientPreset? findById(String id) {
    try {
      return gradients.firstWhere((g) => g.id == id);
    } catch (_) {
      return null;
    }
  }
}
