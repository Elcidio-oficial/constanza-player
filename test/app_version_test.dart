import 'dart:io';

import 'package:constanza_player/core/constants/app_constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A versão mostrada em "Sobre" é uma constante; sem este teste ficou parada
  // em 1.5.1 durante várias versões publicadas.
  test('AppConstants.appVersion acompanha o pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(
      r'^version:\s*([0-9.]+)',
      multiLine: true,
    ).firstMatch(pubspec)!.group(1);
    expect(AppConstants.appVersion, version);
  });
}
