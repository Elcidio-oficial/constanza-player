import 'package:flutter/material.dart';

/// Uma novidade mostrada no ecrã "O que há de novo".
class ReleaseNoteItem {
  const ReleaseNoteItem({
    required this.icon,
    required this.titlePt,
    required this.bodyPt,
    required this.titleEn,
    required this.bodyEn,
  });

  final IconData icon;
  final String titlePt;
  final String bodyPt;
  final String titleEn;
  final String bodyEn;

  String title(Locale locale) =>
      locale.languageCode == 'pt' ? titlePt : titleEn;
  String body(Locale locale) => locale.languageCode == 'pt' ? bodyPt : bodyEn;
}

class ReleaseNotes {
  const ReleaseNotes({
    required this.version,
    required this.date,
    required this.highlights,
    this.fixesPt = const [],
    this.fixesEn = const [],
  });

  final String version;
  final DateTime date;
  final List<ReleaseNoteItem> highlights;
  final List<String> fixesPt;
  final List<String> fixesEn;

  List<String> fixes(Locale locale) =>
      locale.languageCode == 'pt' ? fixesPt : fixesEn;
}

/// Notas da versão atual, escritas para quem usa o app (não para quem o
/// programa). Ao mudar a versão no pubspec, atualize [currentReleaseNotes];
/// `test/release_notes_test.dart` falha se ficarem desalinhadas.
final currentReleaseNotes = ReleaseNotes(
  version: '1.7.0',
  date: DateTime(2026, 10, 27),
  highlights: const [
    ReleaseNoteItem(
      icon: Icons.light_mode_rounded,
      titlePt: 'Modo claro em todo o app',
      bodyPt:
          'Escolha Sistema, Claro ou Escuro em Configurações → Aparência. '
          'Now Playing, letras, Modo Carro e o leitor flutuante também mudam.',
      titleEn: 'Light mode everywhere',
      bodyEn:
          'Pick System, Light or Dark in Settings → Appearance. Now Playing, '
          'lyrics, Car Mode and the floating player follow it too.',
    ),
    ReleaseNoteItem(
      icon: Icons.widgets_rounded,
      titlePt: 'Widgets redesenhados',
      bodyPt:
          'Os seis widgets da tela inicial seguem o claro/escuro e as cores '
          'do seu papel de parede, com capas inteiras e controlos maiores.',
      titleEn: 'Redesigned widgets',
      bodyEn:
          'All six home-screen widgets follow light/dark and your wallpaper '
          'colours, with full covers and bigger controls.',
    ),
    ReleaseNoteItem(
      icon: Icons.ios_share_rounded,
      titlePt: 'Partilhar ficou mais bonito',
      bodyPt:
          'Pré-visualize o poster antes de partilhar e escolha entre Capa, '
          'Vinil, Editorial, Cartão e Citação.',
      titleEn: 'Better sharing',
      bodyEn:
          'Preview the poster before sharing and choose Cover, Vinyl, '
          'Editorial, Card or Quote.',
    ),
    ReleaseNoteItem(
      icon: Icons.speed_rounded,
      titlePt: 'Mais rápido e fluido',
      bodyPt:
          '120 Hz nos aparelhos que permitem, tela inicial mais leve durante '
          'a reprodução e BPM/tonalidade mais precisos.',
      titleEn: 'Faster and smoother',
      bodyEn:
          '120 Hz on supported phones, a lighter home screen while playing '
          'and more accurate BPM and key.',
    ),
  ],
  fixesPt: const [
    '"Avaliar na Play Store" volta a abrir a página do app.',
    'Quando outro leitor é o padrão, o app explica como mudar em vez de o '
        'abrir.',
    'O cartão "A tocar" da Início abre o Now Playing completo.',
    'A versão mostrada em "Sobre" estava desatualizada.',
    'Artistas, Álbuns e outras listas ficavam com fundo preto no modo claro.',
    'Novo seletor de colunas e nova página "Sobre".',
  ],
  fixesEn: const [
    '"Rate on Play Store" opens the app page again.',
    'When another player is the default, the app explains how to change it '
        'instead of opening it.',
    'The "Now playing" card on Home opens the full player.',
    'The version shown in "About" was out of date.',
    'Artists, Albums and other lists had a black background in light mode.',
    'New column picker and a new "About" page.',
  ],
);

/// Compara versões "1.7.0" numericamente: >0 se [a] > [b].
int compareVersions(String a, String b) {
  final pa = a.split('.').map((s) => int.tryParse(s) ?? 0).toList();
  final pb = b.split('.').map((s) => int.tryParse(s) ?? 0).toList();
  for (var i = 0; i < 3; i++) {
    final d = (i < pa.length ? pa[i] : 0) - (i < pb.length ? pb[i] : 0);
    if (d != 0) return d;
  }
  return 0;
}

/// Mostrar "O que há de novo"? Só depois de uma atualização: nunca numa
/// instalação nova (já há o onboarding), nem duas vezes para a mesma versão.
bool shouldShowWhatsNew({
  required String current,
  required String? lastSeen,
  required bool hadDataAtLaunch,
}) {
  if (lastSeen == null) return hadDataAtLaunch;
  return compareVersions(current, lastSeen) > 0;
}
