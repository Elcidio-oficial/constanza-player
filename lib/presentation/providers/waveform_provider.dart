import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:constanza_player/presentation/providers/player_provider.dart';
import 'package:constanza_player/services/waveform_service.dart';

/// Envelope de energia da música em [uri], devolvido na hora e preenchido em
/// segundo plano (null quando a plataforma não suporta). A leitura começa na
/// posição atual para as barras pulsarem já na primeira reprodução.
final waveformProvider = Provider.autoDispose.family<SongWaveform?, String>((
  ref,
  uri,
) {
  final startMs = ref.read(playerProvider).position.inMilliseconds;
  return WaveformService.open(uri, startMs: startMs);
});
