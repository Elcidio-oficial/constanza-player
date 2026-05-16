package com.constanza.constanza_player

// MainActivity DEVE estender AudioServiceFragmentActivity.
// Isso garante que o FlutterEngine partilhado seja o mesmo que o
// audio_service usa internamente (validado em AudioServicePlugin.java:315).
// Se usar FlutterActivity ou FlutterFragmentActivity simples, o plugin
// detecta um "wrong engine" e lança PlatformException ao iniciar.
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.WindowManager
import com.ryanheise.audioservice.AudioServiceFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceFragmentActivity() {

    /** Rota pendente vinda de um clique em widget. Drenada pelo Dart via
     *  MethodChannel "consumePendingRoute" assim que o handler estiver pronto. */
    private var pendingRoute: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        captureDeepLink(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureDeepLink(intent)
        // App já está vivo: tenta despachar imediatamente.
        dispatchPendingRoute()
    }

    private fun captureDeepLink(intent: Intent?) {
        val route = intent?.getStringExtra(WidgetConstants.EXTRA_DEEPLINK_ROUTE) ?: return
        pendingRoute = route
        intent.removeExtra(WidgetConstants.EXTRA_DEEPLINK_ROUTE)
    }

    private fun dispatchPendingRoute() {
        val route = pendingRoute ?: return
        val engine = FlutterEngineCache.getInstance().get(WidgetConstants.FLUTTER_ENGINE_ID) ?: return
        try {
            MethodChannel(engine.dartExecutor.binaryMessenger, WidgetConstants.WIDGET_CHANNEL)
                .invokeMethod("navigate", route)
            pendingRoute = null
        } catch (_: Exception) {
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(AudioEffectsPlugin())
        flutterEngine.plugins.add(MediaNotificationPlugin())
        flutterEngine.plugins.add(MediaTagPlugin())
        flutterEngine.plugins.add(AudioAnalysisPlugin())

        // Cacheia o engine para que BroadcastReceivers (widgets) possam
        // invocar métodos no Dart enquanto o app/processo estiver vivo.
        FlutterEngineCache.getInstance().put(WidgetConstants.FLUTTER_ENGINE_ID, flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.constanza.screen")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "keepOn" -> {
                        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        result.success(null)
                    }
                    "release" -> {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WidgetConstants.WIDGET_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "updateWidget" -> {
                        val prefs = getSharedPreferences(WidgetConstants.PREFS, Context.MODE_PRIVATE)
                        prefs.edit().apply {
                            putString(WidgetConstants.KEY_TITLE,        call.argument("title"))
                            putString(WidgetConstants.KEY_ARTIST,       call.argument("artist"))
                            putBoolean(WidgetConstants.KEY_IS_PLAYING,  call.argument("isPlaying") ?: false)
                            putBoolean(WidgetConstants.KEY_IS_FAVORITE, call.argument("isFavorite") ?: false)
                            putInt(WidgetConstants.KEY_REPEAT_MODE,     call.argument("repeatMode") ?: 0)
                            call.argument<String>("artworkPath")?.let { putString(WidgetConstants.KEY_ARTWORK_PATH, it) }
                            apply()
                        }
                        MusicWidgetProvider.updateAllWidgets(this@MainActivity)
                        WidgetLargeProvider.updateAllWidgets(this@MainActivity)
                        WidgetMediumSearchProvider.updateAllWidgets(this@MainActivity)
                        WidgetCapsuleProvider.updateAllWidgets(this@MainActivity)
                        WidgetRecommendationProvider.updateAllWidgets(this@MainActivity)
                        WidgetRecommendedProvider.updateAllWidgets(this@MainActivity)
                        result.success(null)
                    }
                    "consumePendingRoute" -> {
                        val r = pendingRoute
                        pendingRoute = null
                        result.success(r)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        FlutterEngineCache.getInstance().remove(WidgetConstants.FLUTTER_ENGINE_ID)
        super.onDestroy()
    }
}
