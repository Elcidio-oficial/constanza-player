package com.constanza.constanza_player

import android.media.audiofx.BassBoost
import android.media.audiofx.Equalizer
import android.media.audiofx.Virtualizer
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class AudioEffectsPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private var equalizer: Equalizer? = null
    private var bassBoost: BassBoost? = null
    private var virtualizer: Virtualizer? = null
    private var currentSessionId: Int = 0

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "com.constanza.audio_effects")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        releaseEffects()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "init" -> {
                val sessionId = call.argument<Int>("sessionId") ?: 0
                initEffects(sessionId)
                result.success(getEqInfo())
            }
            "setEnabled" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                setEnabled(enabled)
                result.success(null)
            }
            "setBandLevel" -> {
                val band = call.argument<Int>("band") ?: 0
                val level = call.argument<Int>("level") ?: 0
                setBandLevel(band, level.toShort())
                result.success(null)
            }
            "setAllBands" -> {
                @Suppress("UNCHECKED_CAST")
                val levels = call.argument<List<Int>>("levels") ?: emptyList()
                setAllBands(levels)
                result.success(null)
            }
            "setBassBoost" -> {
                val strength = call.argument<Int>("strength") ?: 0
                setBassBoostStrength(strength.toShort())
                result.success(null)
            }
            "setVirtualizer" -> {
                val strength = call.argument<Int>("strength") ?: 0
                setVirtualizerStrength(strength.toShort())
                result.success(null)
            }
            "release" -> {
                releaseEffects()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun initEffects(sessionId: Int) {
        if (sessionId == currentSessionId && equalizer != null) return
        releaseEffects()
        currentSessionId = sessionId

        try {
            equalizer = Equalizer(0, sessionId).apply {
                enabled = false
            }
            bassBoost = BassBoost(0, sessionId).apply {
                enabled = false
            }
            virtualizer = Virtualizer(0, sessionId).apply {
                enabled = false
            }
        } catch (e: Exception) {
            // Alguns devices não suportam todos os efeitos
        }
    }

    private fun getEqInfo(): Map<String, Any> {
        val eq = equalizer ?: return emptyMap()
        val numBands = eq.numberOfBands.toInt()
        val bandRange = listOf(eq.bandLevelRange[0].toInt(), eq.bandLevelRange[1].toInt())
        val bandFreqs = (0 until numBands).map { eq.getCenterFreq(it.toShort()) / 1000 }

        return mapOf(
            "numBands" to numBands,
            "bandRange" to bandRange,
            "bandFreqs" to bandFreqs
        )
    }

    private fun setEnabled(enabled: Boolean) {
        try {
            equalizer?.enabled = enabled
            bassBoost?.enabled = enabled
            virtualizer?.enabled = enabled
        } catch (_: Exception) {}
    }

    private fun setBandLevel(band: Int, level: Short) {
        try {
            equalizer?.setBandLevel(band.toShort(), level)
        } catch (_: Exception) {}
    }

    private fun setAllBands(levels: List<Int>) {
        try {
            val eq = equalizer ?: return
            for (i in levels.indices) {
                if (i < eq.numberOfBands) {
                    eq.setBandLevel(i.toShort(), levels[i].toShort())
                }
            }
        } catch (_: Exception) {}
    }

    private fun setBassBoostStrength(strength: Short) {
        try {
            bassBoost?.setStrength(strength)
        } catch (_: Exception) {}
    }

    private fun setVirtualizerStrength(strength: Short) {
        try {
            virtualizer?.setStrength(strength)
        } catch (_: Exception) {}
    }

    private fun releaseEffects() {
        try {
            equalizer?.release()
            bassBoost?.release()
            virtualizer?.release()
        } catch (_: Exception) {}
        equalizer = null
        bassBoost = null
        virtualizer = null
        currentSessionId = 0
    }
}
