package com.constanza.constanza_player

// MainActivity DEVE estender AudioServiceFragmentActivity.
// Isso garante que o FlutterEngine partilhado seja o mesmo que o
// audio_service usa internamente (validado em AudioServicePlugin.java:315).
// Se usar FlutterActivity ou FlutterFragmentActivity simples, o plugin
// detecta um "wrong engine" e lança PlatformException ao iniciar.
import com.ryanheise.audioservice.AudioServiceFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : AudioServiceFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(AudioEffectsPlugin())
    }
}
