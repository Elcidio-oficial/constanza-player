package com.constanza.constanza_player

// MainActivity DEVE estender AudioServiceFragmentActivity.
// Isso garante que o FlutterEngine partilhado seja o mesmo que o
// audio_service usa internamente (validado em AudioServicePlugin.java:315).
// Se usar FlutterActivity ou FlutterFragmentActivity simples, o plugin
// detecta um "wrong engine" e lança PlatformException ao iniciar.
import android.content.Context
import com.ryanheise.audioservice.AudioServiceFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(AudioEffectsPlugin())
        flutterEngine.plugins.add(MediaNotificationPlugin())
        flutterEngine.plugins.add(MediaTagPlugin())
        flutterEngine.plugins.add(AudioAnalysisPlugin())

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.constanza.constanza_player/widget")
            .setMethodCallHandler { call, result ->
                if (call.method == "updateWidget") {
                    val prefs = getSharedPreferences("widget_prefs", Context.MODE_PRIVATE)
                    prefs.edit().apply {
                        putString("widget_title", call.argument("title"))
                        putString("widget_artist", call.argument("artist"))
                        putBoolean("widget_is_playing", call.argument("isPlaying") ?: false)
                        call.argument<String>("artworkPath")?.let { putString("widget_artwork_path", it) }
                        apply()
                    }
                    MusicWidgetProvider.updateAllWidgets(this@MainActivity)
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }
}
