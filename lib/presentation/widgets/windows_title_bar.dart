import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'package:constanza_player/core/router/app_router.dart';
import 'package:constanza_player/presentation/providers/theme_provider.dart';
import 'package:constanza_player/services/window_mode_service.dart';

/// Barra de título customizada para Windows/Linux.
///
/// Substitui a title bar nativa (que é configurada como hidden em main.dart
/// via [WindowOptions.titleBarStyle]).
///
/// Layout: [drag region com nome do app] [minimize] [maximize] [close]
///
/// Em Android/iOS e macOS retorna [SizedBox.shrink] — o sistema operacional
/// já gerencia a barra superior nativamente.
class WindowsTitleBar extends ConsumerStatefulWidget {
  const WindowsTitleBar({super.key, this.height = 36, this.title});

  final double height;
  final String? title;

  static const double defaultHeight = 36;

  @override
  ConsumerState<WindowsTitleBar> createState() => _WindowsTitleBarState();
}

class _WindowsTitleBarState extends ConsumerState<WindowsTitleBar>
    with WindowListener {
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    if (_isDesktop) {
      windowManager.addListener(this);
      _syncMaximized();
    }
  }

  @override
  void dispose() {
    if (_isDesktop) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  Future<void> _syncMaximized() async {
    final m = await windowManager.isMaximized();
    if (mounted && m != _maximized) setState(() => _maximized = m);
  }

  @override
  void onWindowMaximize() => _syncMaximized();

  @override
  void onWindowUnmaximize() => _syncMaximized();

  bool get _isDesktop => Platform.isWindows || Platform.isLinux;

  @override
  Widget build(BuildContext context) {
    if (!_isDesktop) return const SizedBox.shrink();

    final colors = Theme.of(context).colorScheme;
    final onSurface = colors.onSurface;
    final hasBackground = ref.watch(
      themeProvider.select((s) => s.hasBackground),
    );

    // Com fundo customizado: Material transparente + a mesma camada de
    // fundo do app (acompanha gradiente/imagem escolhidos) e um scrim
    // discreto para manter o texto/botões legíveis sobre wallpapers.
    // Sem fundo: cor sólida do tema (comportamento original). O Material
    // também elimina o sublinhado amarelo de debug que o Flutter desenha
    // em Text sem ancestral Material — a WindowsTitleBar fica acima do
    // Navigator, fora de qualquer Scaffold.
    return Material(
      color: hasBackground ? Colors.transparent : colors.surface,
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            // O fundo personalizado já é pintado pelo MaterialApp.builder
            // cobrindo a janela inteira (atrás desta barra inclusive), então
            // aqui NÃO repintamos a imagem — só aplicamos um scrim discreto
            // sobre essa fatia de cima para manter texto/botões legíveis.
            if (hasBackground)
              Positioned.fill(
                child: Container(
                  color: colors.surface.withValues(alpha: 0.32),
                ),
              ),
            Row(
              children: [
          // Drag region — duplo-clique alterna maximizar; arrastar move.
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (_) => windowManager.startDragging(),
              onDoubleTap: () async {
                if (await windowManager.isMaximized()) {
                  await windowManager.unmaximize();
                } else {
                  await windowManager.maximize();
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.title ?? 'Constanza Músicas',
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 0.3,
                      color: onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Toggle do mini-leitor (estilo Windows Media Player 10).
          // Aparece antes do botão de minimizar — encolhe a janela e
          // empurra a rota /mini-player. Clicar de novo restaura.
          _TitleBarButton(
            icon: WindowModeService.isMini
                ? Icons.open_in_full_rounded
                : Icons.picture_in_picture_alt_outlined,
            tooltip: WindowModeService.isMini
                ? 'Restaurar'
                : 'Mini-leitor',
            onTap: () async {
              // Lê o router via Riverpod — context.go() falharia aqui porque
              // a WindowsTitleBar é montada no MaterialApp.builder, ACIMA do
              // Router no widget tree, sem InheritedNotifier do GoRouter
              // acessível por contexto.
              final router = ref.read(appRouterProvider);
              final wasMini = WindowModeService.isMini;
              debugPrint(
                '[TitleBar] pip tap — wasMini=$wasMini → '
                '${wasMini ? "/home" : "/mini-player"}',
              );
              if (wasMini) {
                router.go('/home');
              } else {
                router.go('/mini-player');
              }
              await WindowModeService.toggle();
            },
            color: onSurface,
          ),
          _TitleBarButton(
            icon: Icons.remove,
            tooltip: 'Minimizar',
            onTap: () => windowManager.minimize(),
            color: onSurface,
          ),
          _TitleBarButton(
            icon: _maximized
                ? Icons.filter_none_outlined
                : Icons.crop_square_outlined,
            tooltip: _maximized ? 'Restaurar' : 'Maximizar',
            onTap: () async {
              if (await windowManager.isMaximized()) {
                await windowManager.unmaximize();
              } else {
                await windowManager.maximize();
              }
            },
            color: onSurface,
          ),
          _TitleBarButton(
            icon: Icons.close,
            tooltip: 'Fechar',
            onTap: () => windowManager.close(),
            color: onSurface,
            hoverColor: Colors.red,
            hoverIconColor: Colors.white,
          ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleBarButton extends StatefulWidget {
  const _TitleBarButton({
    required this.icon,
    required this.onTap,
    required this.color,
    this.tooltip,
    this.hoverColor,
    this.hoverIconColor,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final String? tooltip;
  final Color? hoverColor;
  final Color? hoverIconColor;

  @override
  State<_TitleBarButton> createState() => _TitleBarButtonState();
}

class _TitleBarButtonState extends State<_TitleBarButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bgHover =
        widget.hoverColor ?? colors.onSurface.withValues(alpha: 0.08);
    final iconColor =
        _hover && widget.hoverIconColor != null
            ? widget.hoverIconColor!
            : widget.color.withValues(alpha: 0.8);

    // IMPORTANTE: não usamos [Tooltip] aqui porque a [WindowsTitleBar] é
    // injetada via MaterialApp.builder ACIMA do Navigator — não há Overlay
    // ancestral, e Tooltip lança "No Overlay widget found" nesse contexto.
    // O `tooltip` virou hint nativo do cursor via [MouseRegion.hint].
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 46,
          color: _hover ? bgHover : Colors.transparent,
          alignment: Alignment.center,
          child: Semantics(
            label: widget.tooltip,
            button: true,
            child: Icon(widget.icon, size: 14, color: iconColor),
          ),
        ),
      ),
    );
  }
}
