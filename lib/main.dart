import 'dart:async';
import 'dart:io' show Platform;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:constanza_player/l10n/gen/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:constanza_player/services/widget_service.dart';
import 'package:constanza_player/core/theme/app_theme.dart';
import 'package:constanza_player/core/router/app_router.dart';
import 'package:constanza_player/presentation/pages/now_playing/now_playing_page.dart'
    show showSleepTimerSheet, openQueuePage;
import 'package:constanza_player/presentation/providers/theme_provider.dart';
import 'package:constanza_player/presentation/providers/player_provider.dart';
import 'package:constanza_player/presentation/widgets/background_wrapper.dart';
import 'package:constanza_player/presentation/widgets/windows_title_bar.dart';
import 'package:constanza_player/services/audio_handler.dart';
import 'package:constanza_player/services/window_mode_service.dart';
import 'package:constanza_player/services/media_library/media_library_backend.dart';
import 'package:constanza_player/services/media_library/scan_crash_guard.dart';
import 'package:constanza_player/services/windows_smtc_service.dart';
import 'package:constanza_player/services/settings_storage_service.dart';
import 'package:constanza_player/services/lyrics_service.dart';
import 'package:constanza_player/services/audio_analysis_service.dart';
import 'package:constanza_player/services/bpm_key_fetch_service.dart';
import 'package:constanza_player/services/crash_reporter.dart';
import 'package:audio_session/audio_session.dart';

void main() async {
  // Captura erros globais — garante que o app nunca crashe silenciosamente.
  // Em release builds, silenciamos debugPrint para não vazar logs em logcat;
  // o CrashReporter persiste os erros em <AppDir>/crashes.jsonl para diagnóstico.
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Windows/Linux: registra o backend libmpv para o just_audio. Sem isto,
      // setFilePath() não emite áudio nem erro — apenas falha em silêncio.
      // Deve rodar ANTES de qualquer AudioPlayer ser instanciado.
      if (Platform.isWindows || Platform.isLinux) {
        JustAudioMediaKit.ensureInitialized(windows: true, linux: true);

        // Desktop: tira a title bar nativa (substituída pelo [WindowsTitleBar])
        // e define tamanho mínimo. Sem awaitar tudo: ensureInitialized é
        // obrigatório antes de qualquer outra chamada do window_manager.
        await windowManager.ensureInitialized();
        const opts = WindowOptions(
          size: Size(1100, 720),
          minimumSize: Size(900, 600),
          center: true,
          backgroundColor: Colors.transparent,
          skipTaskbar: false,
          titleBarStyle: TitleBarStyle.hidden,
          title: 'Constanza Músicas',
        );
        await windowManager.waitUntilReadyToShow(opts, () async {
          await windowManager.show();
          await windowManager.focus();
        });
      }

      if (kReleaseMode) {
        debugPrint = (String? message, {int? wrapWidth}) {};
      }

      // Inicializa reporter ANTES de instalar handlers, para não perder erros
      // precoces (p.ex. falha na inicialização do SharedPreferences).
      await CrashReporter.init();
      CrashReporter.installGlobalHandlers();

      // Inicializa SharedPreferences antes de qualquer coisa
      await SettingsStorageService.init();

      // Auto-cura de crashes nativos do `audiotags` no Windows: se o run
      // anterior morreu lendo um arquivo (segfault FFI, não capturável em
      // Dart), o path fica em scan_inprogress.txt e é blacklistado agora.
      // Em Android/iOS é inócuo (não usa audiotags).
      final crashedFile = await ScanCrashGuard.init();
      if (crashedFile != null) {
        debugPrint('[Main] previous scan crashed on: $crashedFile — skipping');
      }

      // Seleciona o backend de biblioteca de mídia para a plataforma atual.
      // Android/iOS: on_audio_query (MediaStore).
      // Windows/Linux/macOS: varredura de filesystem + audiotags.
      await MediaLibrary.init(
        windowsScanFolders:
            SettingsStorageService.loadMusicFolders() ?? const [],
      );

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

      // AudioSession + audio_service só existem em Android/iOS.
      // Em desktop (Windows/Linux/macOS) instanciamos o handler diretamente
      // — sem notificação de mídia (será coberto por smtc_windows depois).
      late final ConstanzaAudioHandler audioHandler;
      if (Platform.isAndroid || Platform.isIOS) {
        // AudioSession configurada como um app de música padrão: requisita
        // audio focus (gain) e recebe eventos de interrupção. O handler
        // (ConstanzaAudioHandler) escuta interruptionEventStream e:
        //   • duck (SMS, notificação curta) → reduz volume temporariamente
        //   • pause (chamada, outro player) → pausa e retoma ao fim
        //   • becoming noisy (fones desconectados) → pausa
        // androidWillPauseWhenDucked:false garante que duck venha como tipo
        // 'duck' (e não 'pause'), permitindo só baixar o volume.
        try {
          final session = await AudioSession.instance;
          await session.configure(
            const AudioSessionConfiguration(
              avAudioSessionCategory: AVAudioSessionCategory.playback,
              avAudioSessionMode: AVAudioSessionMode.defaultMode,
              androidAudioAttributes: AndroidAudioAttributes(
                contentType: AndroidAudioContentType.music,
                usage: AndroidAudioUsage.media,
              ),
              androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
              androidWillPauseWhenDucked: false,
            ),
          );
        } catch (e) {
          debugPrint('[Main] AudioSession config failed: $e');
        }

        // Inicializa o AudioService (requer MainActivity extends AudioServiceFragmentActivity).
        // Se falhar (configuração errada de Activity no Manifest), o app ainda funciona
        // sem notificações — evita travar na tela inicial do Flutter.
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
        } catch (e, st) {
          // Falha aqui = nenhuma notificação / controles de lockscreen (o app
          // cai num handler sem foreground service). debugPrint é mudo em
          // release, então persistimos no CrashReporter para diagnóstico —
          // visível em Configurações → logs.
          debugPrint('[Main] AudioService.init failed: $e');
          CrashReporter.recordNonFatal(
            e,
            stack: st,
            context: 'AudioService.init — notificação de mídia indisponível',
          );
          audioHandler = ConstanzaAudioHandler();
        }
      } else {
        // Desktop: handler standalone, sem foreground service.
        audioHandler = ConstanzaAudioHandler();
      }

      // Windows: liga o System Media Transport Controls (notificação de mídia
      // nativa + atalhos de teclado + Action Center). No-op em outras plats.
      if (Platform.isWindows) {
        try {
          await WindowsSmtcService.init(audioHandler);
        } catch (e) {
          debugPrint('[Main] SMTC init failed: $e');
        }
      }

      // UI imersiva — transparência total nas barras do sistema (mobile only).
      // SystemChrome.setEnabledSystemUIMode lança PlatformException em desktop.
      if (Platform.isAndroid || Platform.isIOS) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        SystemChrome.setSystemUIOverlayStyle(
          const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarContrastEnforced: false,
          ),
        );
      }

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

class ConstanzaApp extends ConsumerStatefulWidget {
  const ConstanzaApp({super.key});

  @override
  ConsumerState<ConstanzaApp> createState() => _ConstanzaAppState();
}

class _ConstanzaAppState extends ConsumerState<ConstanzaApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final router = ref.read(appRouterProvider);
      WidgetService.registerNavigationHandler((route) {
        // Deeplink especial: /sleep-timer abre o NowPlaying e mostra o sheet.
        if (route == '/sleep-timer') {
          router.go('/now-playing');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final ctx = router.routerDelegate.navigatorKey.currentContext;
            if (ctx != null && ctx.mounted) {
              showSleepTimerSheet(ctx);
            }
          });
        } else if (route == '/queue') {
          // Abre NowPlaying e empurra a Fila por cima.
          router.go('/now-playing');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final ctx = router.routerDelegate.navigatorKey.currentContext;
            if (ctx != null && ctx.mounted) {
              openQueuePage(ctx);
            }
          });
        } else {
          router.go(route);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final accent = themeState.accentColor;
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Constanza Músicas',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(accentColor: accent),
      darkTheme: AppTheme.dark(accentColor: accent),
      themeMode: themeState.themeMode,
      locale: themeState.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      // Desktop: empilha a title bar customizada sobre qualquer rota.
      // No modo mini-leitor a title bar some — a janela fica frameless
      // e o drag/controles ficam dentro da própria [MiniPlayerPage].
      // No mobile (Android/iOS/macOS) o builder devolve o child puro.
      builder: (context, child) {
        if (!Platform.isWindows && !Platform.isLinux) {
          return child ?? const SizedBox.shrink();
        }
        return ValueListenableBuilder<bool>(
          valueListenable: WindowModeService.isMiniNotifier,
          builder: (context, isMini, _) {
            final content = child ?? const SizedBox.shrink();
            // Fundo personalizado pintado UMA única vez, cobrindo a janela
            // inteira (inclusive atrás da title bar). Assim a imagem/gradiente
            // é contínuo: a title bar mostra a fatia de cima da MESMA imagem,
            // sem emenda. A [WindowsTitleBar] e o conteúdo (Scaffolds
            // transparentes) ficam por cima, e [BackgroundWrapper] vira
            // pass-through no desktop para não repintar um recorte diferente.
            final Widget body = isMini
                ? content
                : Column(
                    children: [
                      const WindowsTitleBar(),
                      Expanded(child: content),
                    ],
                  );
            return Stack(
              fit: StackFit.expand,
              children: [const AppBackgroundLayer(), body],
            );
          },
        );
      },
    );
  }
}
