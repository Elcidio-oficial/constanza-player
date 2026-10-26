import 'dart:io';

import 'package:constanza_player/core/constants/app_constants.dart';
import 'package:constanza_player/core/constants/release_notes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final version = RegExp(
    r'^version:\s*([0-9.]+)',
    multiLine: true,
  ).firstMatch(pubspec)!.group(1)!;

  // A versão mostrada em "Sobre" é uma constante; sem este teste ficou parada
  // em 1.5.1 durante várias versões publicadas.
  test('AppConstants.appVersion acompanha o pubspec.yaml', () {
    expect(AppConstants.appVersion, version);
  });

  // O instalador do Windows (MSIX) tem a sua própria versão de 4 partes.
  test('msix_version acompanha o pubspec.yaml', () {
    final msix = RegExp(
      r'^\s*msix_version:\s*([0-9.]+)',
      multiLine: true,
    ).firstMatch(pubspec)!.group(1);
    expect(msix, '$version.0');
  });

  // As notas do ecrã "O que há de novo" têm de ser as desta versão.
  test('notas de versão correspondem à versão do app', () {
    expect(currentReleaseNotes.version, version);
  });

  // Gravar o pubspec num encoding errado já trocou "Músicas" por
  // "MÃºsicas" e depois por "M????sicas" (nome do instalador Windows).
  test('pubspec.yaml sem texto corrompido', () {
    expect(pubspec, contains('display_name: Constanza Músicas'));
    expect(pubspec.contains('????'), isFalse);
    // Dupla codificação: "Ã" seguido de um byte de continuação (Ãº, Ã§…).
    // "Ã" sozinho é legítimo (NAVEGAÇÃO).
    expect(RegExp('Ã[\u0080-¿]').hasMatch(pubspec), isFalse);
  });
}
