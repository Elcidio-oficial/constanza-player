import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:constanza_player/core/theme/app_backgrounds.dart';
import 'package:constanza_player/presentation/providers/theme_provider.dart';

/// Wrapper que aplica fundo customizado ao app inteiro.
///
/// Renderiza um gradiente ou imagem atrás de todo o conteúdo,
/// com opacidade e blur configuráveis.
class BackgroundWrapper extends ConsumerWidget {
  const BackgroundWrapper({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Desktop (Windows/Linux): o fundo é pintado UMA vez no
    // MaterialApp.builder, cobrindo a janela inteira (inclusive atrás da
    // title bar) — ver main.dart. Repintar aqui geraria um recorte
    // diferente e uma emenda visível logo abaixo da barra de título.
    if (Platform.isWindows || Platform.isLinux) {
      return child;
    }

    final hasBackground = ref.watch(
      themeProvider.select((s) => s.hasBackground),
    );

    if (!hasBackground) {
      return child;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        const AppBackgroundLayer(),
        child,
      ],
    );
  }
}

/// Apenas o fundo customizado (cor base + gradiente/imagem), sem conteúdo.
///
/// Reutilizável fora do [BackgroundWrapper] — usado também pela barra de
/// título do Windows para acompanhar o fundo escolhido em vez de ficar
/// preta fixa. Retorna [SizedBox.shrink] quando não há fundo ativo.
class AppBackgroundLayer extends ConsumerWidget {
  const AppBackgroundLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final colors = Theme.of(context).colorScheme;

    if (!themeState.hasBackground) return const SizedBox.shrink();

    return Stack(
      fit: StackFit.expand,
      children: [
        // === Cor base ===
        Container(color: colors.surface),

        // === Fundo (gradiente ou imagem) ===
        if (themeState.backgroundType == BackgroundType.gradient &&
            themeState.currentGradient != null)
          _GradientBackground(
            gradient: themeState.currentGradient!,
            opacity: themeState.backgroundOpacity,
            blur: themeState.backgroundBlur,
          ),

        if (themeState.hasImageBackground)
          _ImageBackground(
            imagePath: themeState.backgroundImagePath!,
            opacity: themeState.backgroundOpacity,
            blur: themeState.backgroundBlur,
          ),
      ],
    );
  }
}

class _GradientBackground extends StatelessWidget {
  const _GradientBackground({
    required this.gradient,
    required this.opacity,
    required this.blur,
  });

  final GradientPreset gradient;
  final double opacity;
  final double blur;

  @override
  Widget build(BuildContext context) {
    Widget bg = Opacity(
      opacity: opacity,
      child: Container(
        decoration: BoxDecoration(gradient: gradient.toGradient()),
      ),
    );

    if (blur > 0) {
      bg = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: bg,
      );
    }

    return bg;
  }
}

class _ImageBackground extends StatelessWidget {
  const _ImageBackground({
    required this.imagePath,
    required this.opacity,
    required this.blur,
  });

  final String imagePath;
  final double opacity;
  final double blur;

  @override
  Widget build(BuildContext context) {
    final file = File(imagePath);
    if (!file.existsSync()) return const SizedBox.shrink();

    Widget bg = Opacity(
      opacity: opacity,
      child: Image.file(
        file,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );

    if (blur > 0) {
      bg = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: bg,
      );
    }

    return bg;
  }
}
