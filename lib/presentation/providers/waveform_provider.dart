import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:constanza_player/services/waveform_service.dart';

/// Forma de onda real da música em [uri] (null enquanto carrega ou quando a
/// plataforma não suporta — as barras caem no formato gerado pelo seed).
final waveformProvider = FutureProvider.autoDispose
    .family<List<double>?, String>((ref, uri) => WaveformService.load(uri));
