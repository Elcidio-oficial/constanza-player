import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:constanza_player/core/theme/app_theme.dart';
import 'package:constanza_player/core/router/app_router.dart';
import 'package:constanza_player/presentation/providers/theme_provider.dart';
import 'package:constanza_player/presentation/providers/player_provider.dart';
import 'package:constanza_player/services/audio_handler.dart';
import 'package:constanza_player/services/settings_storage_service.dart';
import 'package:constanza_player/services/lyrics_service.dart';
import 'package:constanza_player/services/audio_analysis_service.dart';
import 'package:constanza_player/services/bpm_key_fetch_service.dart';
import 'package:constanza_player/services/crash_reporter.dart';
import 'package:audio_session/audio_session.dart';

void main() async {
  // Captura erros globais — garante que o app nunca crashe silenciosamente.
  // Em release builds, debugPrint não vai a lugar algum; o CrashReporter
  // persiste os erros em <AppDir>/crashes.jsonl para diagnóstico posterior.
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Inicializa reporter ANTES de instalar handlers, para não perder erros
      // precoces (p.ex. falha na inicialização do SharedPreferences).
      await CrashReporter.init();
      CrashReporter.installGlobalHandlers();

      // Inicializa SharedPreferences antes de qualquer coisa
      await SettingsStorageService.init();
      // Cada serviço isolado: falha num não impede inicialização dos demais
      await Future.wait([
        LyricsService.init().catchError((Object e) {
          debugPrint('[Main] LyricsService.init failed: $e');
        }),
        AudioAnalysisService.loadCache().catchError((Object e) {
          debugPrint('[Main] AudioAnalysisService.loadCache failed: $e');
        }),
        BpmKeyFetchService.loadCache().catchError((Object e) {
          debugPrint('[Main] BpmKeyFetchService.loadCache failed: $e');
        }),
      ]);

      // Configura AudioSession — duck volume em notificações, retomar após chamadas
      try {
        final session = await AudioSession.instance;
        await session.configure(
          const AudioSessionConfiguration(
            avAudioSessionCategory: AVAudioSessionCategory.playback,
            avAudioSessionCategoryOptions:
                AVAudioSessionCategoryOptions.duckOthers,
            avAudioSessionMode: AVAudioSessionMode.defaultMode,
            androidAudioAttributes: AndroidAudioAttributes(
              contentType: AndroidAudioContentType.music,
              usage: AndroidAudioUsage.media,
            ),
            androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          ),
        );
      } catch (e) {
        debugPrint('[Main] AudioSession config failed: $e');
      }

      // Inicializa o AudioService (requer MainActivity extends AudioServiceFragmentActivity).
      // Se falhar (configuração errada de Activity no Manifest), o app ainda funciona
      // sem notificações — evita travar na tela inicial do Flutter.
      late final ConstanzaAudioHandler audioHandler;
      try {
        audioHandler = await AudioService.init<ConstanzaAudioHandler>(
          builder: () => ConstanzaAudioHandler(),
          config: const AudioServiceConfig(
            androidNotificationChannelId:
                'com.constanza.constanza_player.audio',
            androidNotificationChannelName: 'Constanza Músicas',
            // ongoing:true impede o usuário de deslizar e matar o foreground
            // service enquanto tocando (notificação não-dispensável). Ao pausar,
            // o service sai de foreground (stopForegroundOnPause:true) — exigido
            // pelo audio_service quando ongoing:true.
            androidNotificationOngoing: true,
            androidStopForegroundOnPause: true,
            androidNotificationIcon: 'mipmap/ic_launcher',
            androidShowNotificationBadge: true,
            androidResumeOnClick: true,
          ),
        );
      } catch (e) {
        debugPrint('[Main] AudioService.init failed: $e');
        audioHandler = ConstanzaAudioHandler();
      }

      // UI imersiva — transparência total nas barras do sistema
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarContrastEnforced: false,
        ),
      );

      runApp(
        ProviderScope(
          overrides: [audioHandlerProvider.overrideWithValue(audioHandler)],
          child: const ConstanzaApp(),
        ),
      );
    },
    (error, stack) {
      // Captura erros globais não tratados (zona raiz).
      // Persistidos em <AppDir>/crashes.jsonl via CrashReporter.readLogs().
      CrashReporter.recordZoneError(error, stack);
    },
  );
}

class ConstanzaApp extends ConsumerWidget {
  const ConstanzaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final accent = themeState.accentColor;
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Constanza Músicas',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(accentColor: accent),
      darkTheme: AppTheme.dark(accentColor: accent),
      themeMode: themeState.themeMode,
      routerConfig: router,
    );
  }
}
