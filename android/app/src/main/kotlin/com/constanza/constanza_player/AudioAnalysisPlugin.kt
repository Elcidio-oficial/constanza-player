package com.constanza.constanza_player

import android.content.Context
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.nio.ByteOrder
import kotlin.coroutines.coroutineContext
import kotlin.math.*

/**
 * Plugin nativo para análise DSP de áudio — versão profissional 2026.
 *
 * BPM : Multi-band Spectral Flux (8 bandas) + autocorrelação harmônica +
 *       parabolic interpolation + octave normalization
 * Key : HPCP Chromagram com FFT 8192 + janela Blackman-Harris + 6 harmônicas
 *       + dual-profile matching (Krumhansl-Kessler × Temperley)
 *
 * Melhorias desta versão:
 *  • DC blocker no input (remove offset DC antes da análise)
 *  • Pre-ênfase de alta frequência (melhora onset detection)
 *  • Janela Blackman-Harris para detecção de pitch (leakage mínimo)
 *  • FFT de chroma 8192 (~5 Hz/bin @ 44100 Hz — resolução de pitch ≈ ½ semitom)
 *  • 8 bandas de onset com pesos perceptuais calibrados
 *  • 6 harmônicas HPCP com peso 1/h² (detecta tônica em música com timbre rico)
 *  • Threshold adaptativo de onset por mediana local (ativa em 7-frame window)
 *  • Estimativa e compensação de afinação de referência (desvio ±50 cents)
 *  • Normalização L2 do cromagram (mais estável que normalização max)
 *  • Confidence BPM via entropia relativa da ACF
 *  • Confidence Key via distância de Pearson normalizada
 */
class AudioAnalysisPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private var context: Context? = null
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    // Mutex garante que no máximo UMA análise rode por vez. Sem isto, cada
    // skip rápido dispara uma coroutine que aloca FloatArray(60*sampleRate) —
    // 4 análises concorrentes × ~10MB = OOM garantido no heap de 256MB.
    private val analysisMutex = Mutex()

    // Job ativo — ao chegar um novo pedido, o anterior é cancelado. Combinado
    // com ensureActive() no loop de decodificação, libera memória imediatamente
    // em vez de esperar a análise terminar.
    private var activeAnalysisJob: Job? = null

    companion object {
        private const val TAG = "AudioAnalysis"
        private const val CHANNEL_NAME = "com.constanza.audio_analysis"

        // ── Duração e timing ──────────────────────────────────────────
        /** Segundos de áudio analisados. 60 s = estatísticas mais robustas. */
        private const val ANALYSIS_DURATION_SEC = 60

        // ── BPM ───────────────────────────────────────────────────────
        /** Frame 4096 → resolução espectral de ~10 Hz @44100 (melhor que 2048). */
        private const val BPM_FRAME_SIZE = 4096

        /** Hop 512 → ~86 frames/s @44100 → resolução temporal de onset ≈ 11 ms. */
        private const val BPM_HOP_SIZE = 512

        private const val BPM_MIN = 50.0
        private const val BPM_MAX = 220.0

        /** 8 bandas: cobertura sub-bass a brilho (percussão completa). */
        private const val NUM_BANDS = 8

        /** Bordas de banda em Hz — calibradas para percussão + harmônicos. */
        private val BAND_EDGES = doubleArrayOf(
            20.0, 80.0, 160.0, 320.0, 640.0, 1280.0, 2560.0, 5120.0, 10240.0
        )

        /** Pesos perceptuais por banda: sub-bass e bass dominam o ritmo. */
        private val BAND_WEIGHTS = doubleArrayOf(
            2.2,  // 20–80 Hz   : sub-bass / kick
            2.0,  // 80–160 Hz  : bass
            1.5,  // 160–320 Hz : low-mid
            1.1,  // 320–640 Hz : mid
            0.9,  // 640–1280 Hz: upper-mid
            0.7,  // 1280–2560  : presence
            0.5,  // 2560–5120  : brilliance
            0.3,  // 5120–10240 : air / hi-hat
        )

        /** Janela de mediana local para threshold adaptativo de onset (frames). */
        private const val ONSET_MEDIAN_HALF = 7

        // ── Key ───────────────────────────────────────────────────────
        /**
         * 8192 → ~5.4 Hz/bin @44100.
         * Distância entre Lá4 (440 Hz) e Si4b (466 Hz) ≈ 26 Hz → ~5 bins.
         * Suficiente para distinguir semitons com harmônicas.
         */
        private const val KEY_FRAME_SIZE = 8192

        /** Hop = metade do frame → 50 % de overlap. */
        private const val KEY_HOP_SIZE = 4096

        private const val NUM_CHROMA = 12

        /** 6 harmônicas → pesos 1, 1/4, 1/9, 1/16, 1/25, 1/36. */
        private const val NUM_HARMONICS = 6

        /** Frequência de referência para MIDI ↔ freq (A4 = 440 Hz). */
        private const val A4_REF = 440.0

        /** Faixa de frequência considerada no chroma: A1 (55 Hz) → B7 (3951 Hz). */
        private const val CHROMA_FREQ_MIN = 55.0
        private const val CHROMA_FREQ_MAX = 3951.0

        private val NOTE_NAMES = arrayOf(
            "C", "C#", "D", "D#", "E", "F",
            "F#", "G", "G#", "A", "A#", "B"
        )

        // ── Krumhansl-Kessler (1982) ──────────────────────────────────
        private val KK_MAJOR = doubleArrayOf(
            6.35, 2.23, 3.48, 2.33, 4.38, 4.09,
            2.52, 5.19, 2.39, 3.66, 2.29, 2.88
        )
        private val KK_MINOR = doubleArrayOf(
            6.33, 2.68, 3.52, 5.38, 2.60, 3.53,
            2.54, 4.75, 3.98, 2.69, 3.34, 3.17
        )

        // ── Temperley (2001) ─────────────────────────────────────────
        private val TEMP_MAJOR = doubleArrayOf(
            5.0, 2.0, 3.5, 2.0, 4.5, 4.0,
            2.0, 4.5, 2.0, 3.5, 1.5, 4.0
        )
        private val TEMP_MINOR = doubleArrayOf(
            5.0, 2.0, 3.5, 4.5, 2.0, 3.5,
            2.0, 4.5, 3.5, 2.0, 1.5, 4.0
        )
    }

    // ════════════════════════════════════════════════════════════
    // FLUTTER PLUGIN LIFECYCLE
    // ════════════════════════════════════════════════════════════

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
        context = binding.applicationContext
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        scope.cancel()
        context = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "analyze" -> {
                val uri = call.argument<String>("uri")
                if (uri == null) {
                    result.error("INVALID_ARGS", "uri required", null)
                    return
                }
                // Cancela análise em curso (skip rápido) — libera o FloatArray
                // na próxima checagem de ensureActive() dentro do decoder.
                activeAnalysisJob?.cancel()
                activeAnalysisJob = scope.launch {
                    try {
                        // Mutex assegura serialização: próxima análise só começa
                        // quando a anterior finalizar/cancelar, evitando pico de
                        // memória com dois buffers de PCM alocados ao mesmo tempo.
                        val analysis = analysisMutex.withLock { analyzeAudio(uri) }
                        withContext(Dispatchers.Main) { result.success(analysis) }
                    } catch (e: CancellationException) {
                        // Cancelamento esperado (skip rápido) — responde sem erro
                        // pra não poluir o log do Dart.
                        withContext(Dispatchers.Main) { result.success(null) }
                    } catch (e: Exception) {
                        Log.e(TAG, "Analysis failed for $uri", e)
                        withContext(Dispatchers.Main) {
                            result.error("ANALYSIS_ERROR", e.message ?: "Unknown error", null)
                        }
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    // ════════════════════════════════════════════════════════════
    // MAIN ANALYSIS PIPELINE
    // ════════════════════════════════════════════════════════════

    private data class DecodedAudio(val samples: FloatArray, val sampleRate: Int)

    private suspend fun analyzeAudio(uri: String): Map<String, Any?> {
        val ctx = context ?: throw IllegalStateException("No context")

        val decoded = decodeToMonoFloat(ctx, uri)
        val samples = applyDcBlockerAndPreEmphasis(decoded.samples)
        val sampleRate = decoded.sampleRate

        if (samples.size < BPM_FRAME_SIZE * 4) {
            return mapOf(
                "bpm" to null, "key" to null, "scale" to null,
                "bpmConfidence" to 0.0, "keyConfidence" to 0.0
            )
        }

        Log.d(TAG, "Decoded ${samples.size} samples @${sampleRate}Hz " +
                "(${samples.size / sampleRate.toFloat()}s)")

        val bpmResult = detectBPM(samples, sampleRate)
        val keyResult = detectKey(samples, sampleRate)

        return mapOf(
            "bpm"           to bpmResult?.first?.roundToInt(),
            "bpmConfidence" to (bpmResult?.second ?: 0.0),
            "key"           to keyResult?.first,
            "scale"         to keyResult?.second,
            "keyConfidence" to (keyResult?.third ?: 0.0)
        )
    }

    // ════════════════════════════════════════════════════════════
    // PRE-PROCESSING
    // ════════════════════════════════════════════════════════════

    /**
     * 1. DC blocker: y[n] = x[n] - x[n-1] + 0.995 * y[n-1]
     *    Remove offset DC que causa vazamento espectral na bin 0.
     * 2. Pre-ênfase: amplifica altas frequências (melhora onset em hi-hats/snares).
     *    Coeficiente 0.97 = padrão telecomunicações / speech processing.
     */
    private fun applyDcBlockerAndPreEmphasis(input: FloatArray): FloatArray {
        val out = FloatArray(input.size)
        var prevIn = 0f
        var prevOut = 0f
        for (i in input.indices) {
            // DC blocker
            val dcOut = input[i] - prevIn + 0.995f * prevOut
            prevIn = input[i]
            prevOut = dcOut
            // Pre-ênfase leve (0.97)
            out[i] = dcOut - 0.97f * (if (i > 0) out[i - 1] else 0f)
        }
        return out
    }

    // ════════════════════════════════════════════════════════════
    // AUDIO DECODING
    // ════════════════════════════════════════════════════════════

    private suspend fun decodeToMonoFloat(ctx: Context, uri: String): DecodedAudio {
        val extractor = MediaExtractor()
        var codec: MediaCodec? = null
        try {
            if (uri.startsWith("content://") || uri.startsWith("http")) {
                extractor.setDataSource(ctx, android.net.Uri.parse(uri), null)
            } else {
                extractor.setDataSource(uri)
            }

            var audioTrack = -1
            var sampleRate = 44100
            var channelCount = 2
            for (i in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
                if (mime.startsWith("audio/")) {
                    audioTrack = i
                    sampleRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                    channelCount = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                    break
                }
            }
            if (audioTrack < 0) throw IllegalArgumentException("No audio track found")

            extractor.selectTrack(audioTrack)
            val format = extractor.getTrackFormat(audioTrack)
            val mime = format.getString(MediaFormat.KEY_MIME)
                ?: throw IllegalArgumentException("No mime type")

            codec = MediaCodec.createDecoderByType(mime)
            codec.configure(format, null, null, 0)
            codec.start()

            // FloatArray primitivo — 4 bytes/sample vs ~16 bytes/sample do
            // ArrayList<Float> (boxing). Reduz o footprint de ~60MB p/ ~10MB
            // em 60s @44100Hz.
            val maxSamples = ANALYSIS_DURATION_SEC * sampleRate
            val monoSamples = FloatArray(maxSamples)
            var sampleCount = 0
            val bufferInfo = MediaCodec.BufferInfo()
            var inputDone = false
            var outputDone = false
            val timeoutUs = 10_000L

            while (!outputDone && sampleCount < maxSamples) {
                // Cancellation cooperativa: se o usuário deu skip rápido,
                // interrompe aqui e libera todo o buffer imediatamente.
                coroutineContext.ensureActive()

                if (!inputDone) {
                    val inputIdx = codec.dequeueInputBuffer(timeoutUs)
                    if (inputIdx >= 0) {
                        val inputBuf = codec.getInputBuffer(inputIdx) ?: continue
                        val sampleSize = extractor.readSampleData(inputBuf, 0)
                        if (sampleSize < 0) {
                            codec.queueInputBuffer(
                                inputIdx, 0, 0, 0,
                                MediaCodec.BUFFER_FLAG_END_OF_STREAM
                            )
                            inputDone = true
                        } else {
                            codec.queueInputBuffer(
                                inputIdx, 0, sampleSize,
                                extractor.sampleTime, 0
                            )
                            extractor.advance()
                        }
                    }
                }

                val outputIdx = codec.dequeueOutputBuffer(bufferInfo, timeoutUs)
                if (outputIdx >= 0) {
                    if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                        outputDone = true
                    }
                    val outputBuf = codec.getOutputBuffer(outputIdx)
                    if (outputBuf == null) {
                        codec.releaseOutputBuffer(outputIdx, false)
                        continue
                    }
                    outputBuf.order(ByteOrder.LITTLE_ENDIAN)
                    val shortBuf = outputBuf.asShortBuffer()
                    val samplesInBuffer = shortBuf.remaining()

                    for (i in 0 until samplesInBuffer step channelCount) {
                        if (sampleCount >= maxSamples) break
                        var sum = 0f
                        for (ch in 0 until channelCount) {
                            if (i + ch < samplesInBuffer) {
                                sum += shortBuf.get(i + ch).toFloat() / 32768f
                            }
                        }
                        monoSamples[sampleCount++] = sum / channelCount
                    }
                    codec.releaseOutputBuffer(outputIdx, false)
                }
            }

            // Trim para o tamanho real. copyOf cria uma nova FloatArray;
            // aqui o pico temporário é ~20MB (original + copia) — aceitável,
            // e GC recolhe o 'monoSamples' logo em seguida.
            val trimmed = if (sampleCount == maxSamples) monoSamples
                else monoSamples.copyOf(sampleCount)
            return DecodedAudio(trimmed, sampleRate)
        } finally {
            // Codec release em finally: garante liberação mesmo em exceção/cancel.
            // Sem isto, MediaCodec vaza até o próximo GC — Android 16 reclama.
            try {
                codec?.stop()
            } catch (_: Exception) { /* stop pode falhar se já parou */ }
            try {
                codec?.release()
            } catch (_: Exception) { /* release pode falhar se já liberado */ }
            extractor.release()
        }
    }

    // ════════════════════════════════════════════════════════════
    // BPM DETECTION
    // ════════════════════════════════════════════════════════════

    /**
     * Pipeline:
     *  1. Spectral flux retificado por half-wave em 8 bandas (Hann window)
     *  2. Threshold adaptativo por mediana local (janela ±7 frames)
     *  3. Combinação ponderada das bandas com pesos perceptuais
     *  4. Autocorrelação + soma harmônica (1x + 2x×0.5 + 3x×0.3 + 0.5x×0.4)
     *  5. Bias perceptual: Gaussiana centrada em 120 BPM σ=50
     *  6. Interpolação parabólica sub-sample no pico da ACF
     *  7. Normalização de oitava (50–220 BPM)
     *  8. Confidence: razão sinal/ruído da ACF (entropia relativa)
     */
    private fun detectBPM(samples: FloatArray, sampleRate: Int): Pair<Double, Double>? {
        val frameSize = BPM_FRAME_SIZE
        val hop = BPM_HOP_SIZE
        val numFrames = (samples.size - frameSize) / hop
        if (numFrames < 8) return null

        val framesPerSecond = sampleRate.toDouble() / hop
        val binWidth = sampleRate.toDouble() / frameSize

        // Step 1 — magnitude spectra (Hann window para BPM)
        val spectra = Array(numFrames) { f ->
            val start = f * hop
            val windowed = DoubleArray(frameSize)
            for (i in 0 until frameSize) {
                if (start + i < samples.size) {
                    val hann = 0.5 * (1.0 - cos(2.0 * PI * i / (frameSize - 1)))
                    windowed[i] = samples[start + i].toDouble() * hann
                }
            }
            fftMagnitude(windowed)
        }

        // Step 2 — spectral flux por banda
        val rawFlux = Array(NUM_BANDS) { DoubleArray(numFrames - 1) }
        for (f in 1 until numFrames) {
            for (band in 0 until NUM_BANDS) {
                val lowBin  = max(1, (BAND_EDGES[band] / binWidth).toInt())
                val highBin = min(spectra[f].size - 1, (BAND_EDGES[band + 1] / binWidth).toInt())
                if (lowBin >= highBin) continue
                var flux = 0.0
                for (bin in lowBin until highBin) {
                    val diff = spectra[f][bin] - spectra[f - 1][bin]
                    if (diff > 0.0) flux += diff  // half-wave rectified
                }
                rawFlux[band][f - 1] = flux
            }
        }

        // Step 3 — threshold adaptativo por mediana local → onset normalizado
        val combinedOnset = DoubleArray(numFrames - 1)
        for (band in 0 until NUM_BANDS) {
            val flux = rawFlux[band]
            val fluxMax = flux.maxOrNull() ?: continue
            if (fluxMax < 1e-10) continue

            val thresholded = DoubleArray(flux.size)
            for (i in flux.indices) {
                val lo = max(0, i - ONSET_MEDIAN_HALF)
                val hi = min(flux.size - 1, i + ONSET_MEDIAN_HALF)
                val window = flux.slice(lo..hi).sorted()
                val median = window[window.size / 2]
                val above = flux[i] - 1.5 * median
                thresholded[i] = if (above > 0.0) above else 0.0
            }

            val thMax = thresholded.maxOrNull() ?: continue
            if (thMax < 1e-10) continue

            for (i in combinedOnset.indices) {
                combinedOnset[i] += (thresholded[i] / thMax) * BAND_WEIGHTS[band]
            }
        }

        // Step 4 — ACF no intervalo BPM_MIN..BPM_MAX
        val minLag = (framesPerSecond * 60.0 / BPM_MAX).toInt()
        val maxLag = (framesPerSecond * 60.0 / BPM_MIN)
            .toInt().coerceAtMost(combinedOnset.size / 2)
        if (minLag >= maxLag) return null

        val acf = DoubleArray(maxLag + 1)
        for (lag in minLag..maxLag) {
            var corr = 0.0
            val n = combinedOnset.size - lag
            for (i in 0 until n) corr += combinedOnset[i] * combinedOnset[i + lag]
            acf[lag] = corr / n
        }

        // Harmonic summation
        val harmonicAcf = DoubleArray(maxLag + 1)
        for (lag in minLag..maxLag) {
            var sum = acf[lag]
            val lag2 = lag * 2; val lag3 = lag * 3; val lagHalf = lag / 2
            if (lag2 <= maxLag)  sum += acf[lag2]    * 0.5
            if (lag3 <= maxLag)  sum += acf[lag3]    * 0.3
            if (lagHalf >= minLag) sum += acf[lagHalf] * 0.4

            // Bias perceptual: Gaussiana σ=50 centrada em 120 BPM
            val bpmAtLag = framesPerSecond * 60.0 / lag
            val gauss = exp(-((bpmAtLag - 120.0).pow(2)) / (2.0 * 50.0.pow(2)))
            harmonicAcf[lag] = sum * (1.0 + 0.25 * gauss)
        }

        // Step 5 — pico
        var bestLag = minLag
        var bestVal = Double.MIN_VALUE
        for (lag in minLag..maxLag) {
            if (harmonicAcf[lag] > bestVal) { bestVal = harmonicAcf[lag]; bestLag = lag }
        }

        // Step 6 — interpolação parabólica
        val refinedLag = if (bestLag > minLag && bestLag < maxLag) {
            val a = harmonicAcf[bestLag - 1]
            val b = harmonicAcf[bestLag]
            val c = harmonicAcf[bestLag + 1]
            val denom = a - 2.0 * b + c
            if (abs(denom) > 1e-12) {
                val delta = 0.5 * (a - c) / denom
                if (delta.isFinite()) bestLag + delta else bestLag.toDouble()
            } else bestLag.toDouble()
        } else bestLag.toDouble()

        val rawBpm = framesPerSecond * 60.0 / refinedLag

        // Step 7 — normalização de oitava
        val bpm = when {
            rawBpm in BPM_MIN..BPM_MAX -> rawBpm
            rawBpm * 2 in BPM_MIN..BPM_MAX -> rawBpm * 2
            rawBpm / 2 in BPM_MIN..BPM_MAX -> rawBpm / 2
            rawBpm * 2 < BPM_MIN && rawBpm * 4 in BPM_MIN..BPM_MAX -> rawBpm * 4
            else -> rawBpm.coerceIn(BPM_MIN, BPM_MAX)
        }

        // Step 8 — confidence via SNR da ACF
        val acfSlice = harmonicAcf.slice(minLag..maxLag)
        val mean = acfSlice.average()
        val confidence = if (mean > 1e-10) {
            ((bestVal / mean - 1.0) / 5.0).coerceIn(0.0, 1.0)
        } else 0.0

        Log.d(TAG, "BPM: ${bpm.roundToInt()} (raw=${rawBpm.roundToInt()}, " +
                "conf=${"%.2f".format(confidence)})")
        return Pair(bpm, confidence)
    }

    // ════════════════════════════════════════════════════════════
    // KEY DETECTION
    // ════════════════════════════════════════════════════════════

    /**
     * Pipeline:
     *  1. Janela Blackman-Harris (leakage espectral mínimo — melhor que Hann para pitch)
     *  2. FFT 8192 → resolução ~5.4 Hz/bin @44100
     *  3. HPCP com 6 harmônicas (pesos 1/h²)
     *  4. Estimativa de desvio de afinação (±50 cents) e compensação
     *  5. Normalização L2 do chroma (mais estável que normalização max)
     *  6. Dual-profile matching: Krumhansl-Kessler + Temperley → média
     *  7. Confidence: gap normalizado entre 1º e 2º candidatos
     */
    private fun detectKey(samples: FloatArray, sampleRate: Int): Triple<String, String, Double>? {
        val frameSize = KEY_FRAME_SIZE
        val hop = KEY_HOP_SIZE
        val numFrames = (samples.size - frameSize) / hop
        if (numFrames < 1) return null

        val binWidth = sampleRate.toDouble() / frameSize

        // Acumula chroma ponderado pelo RMS do frame
        val chromaAcc = DoubleArray(NUM_CHROMA)
        var totalWeight = 0.0

        // Buffer pré-alocado para a janela
        val windowed = DoubleArray(frameSize)
        val blackmanCoeffs = buildBlackmanHarrisCoeffs(frameSize)

        // Primeira passagem — estimativa do desvio de afinação (tuning offset)
        val tuningBins = DoubleArray(100)  // centavos -50..+49
        var tuningTotal = 0.0

        for (f in 0 until numFrames) {
            val start = f * hop
            for (i in 0 until frameSize) {
                windowed[i] = if (start + i < samples.size)
                    samples[start + i].toDouble() * blackmanCoeffs[i]
                else 0.0
            }
            val spectrum = fftMagnitude(windowed)
            for (bin in 1 until spectrum.size) {
                val freq = bin * binWidth
                if (freq < CHROMA_FREQ_MIN || freq > CHROMA_FREQ_MAX) continue
                val mag = spectrum[bin]
                if (mag < 1e-8) continue
                val midi = 12.0 * log2(freq / A4_REF) + 69.0
                val frac = midi - floor(midi)  // 0..1
                val cents = ((frac * 100).roundToInt() + 50) % 100  // 0..99
                tuningBins[cents] += mag
                tuningTotal += mag
            }
        }

        // Desvio de afinação em semitom fracional (-0.5..+0.5)
        val tuningOffset = if (tuningTotal > 1e-10) {
            var best = 0; var bestVal = 0.0
            for (i in tuningBins.indices) {
                if (tuningBins[i] > bestVal) { bestVal = tuningBins[i]; best = i }
            }
            // cents: 0..49 → offset positivo, 50..99 → offset negativo
            val rawCents = if (best <= 49) best else best - 100
            rawCents / 100.0  // semitom fracional
        } else 0.0

        Log.d(TAG, "Tuning offset: ${"%.3f".format(tuningOffset)} semitones")

        // Segunda passagem — HPCP com compensação de afinação
        for (f in 0 until numFrames) {
            val start = f * hop
            var rms = 0.0
            for (i in 0 until frameSize) {
                val s = if (start + i < samples.size)
                    samples[start + i].toDouble() else 0.0
                windowed[i] = s * blackmanCoeffs[i]
                rms += s * s
            }
            rms = sqrt(rms / frameSize)
            if (rms < 1e-6) continue  // skip frames silenciosos

            val spectrum = fftMagnitude(windowed)
            val frameChroma = DoubleArray(NUM_CHROMA)

            for (bin in 1 until spectrum.size) {
                val freq = bin * binWidth
                if (freq < CHROMA_FREQ_MIN || freq > CHROMA_FREQ_MAX) continue
                val mag = spectrum[bin]
                if (mag < 1e-8) continue

                for (h in 1..NUM_HARMONICS) {
                    val fundFreq = freq / h
                    if (fundFreq < CHROMA_FREQ_MIN || fundFreq > 2500.0) continue
                    // MIDI com compensação de afinação
                    val midi = 12.0 * log2(fundFreq / A4_REF) + 69.0 - tuningOffset
                    val chromaIdx = ((midi.roundToInt() % 12) + 12) % 12
                    val harmonicWeight = 1.0 / (h.toDouble() * h.toDouble())
                    frameChroma[chromaIdx] += mag * harmonicWeight
                }
            }

            // Normalização L2 do frame antes de acumular (ponderado por RMS)
            val l2 = sqrt(frameChroma.sumOf { it * it })
            if (l2 > 1e-10) {
                val w = rms  // frames mais fortes têm mais peso
                for (i in 0 until NUM_CHROMA) chromaAcc[i] += (frameChroma[i] / l2) * w
                totalWeight += w
            }
        }

        if (totalWeight < 1e-10) return null

        // Normalização L2 global
        for (i in 0 until NUM_CHROMA) chromaAcc[i] /= totalWeight
        val l2Global = sqrt(chromaAcc.sumOf { it * it })
        if (l2Global < 1e-10) return null
        for (i in 0 until NUM_CHROMA) chromaAcc[i] /= l2Global

        // Multi-profile matching
        data class KeyCandidate(val key: Int, val scale: String, val corr: Double)

        val candidates = mutableListOf<KeyCandidate>()
        for (shift in 0 until NUM_CHROMA) {
            val kkMaj = pearsonCorrelation(chromaAcc, rotateProfile(KK_MAJOR, shift))
            val kkMin = pearsonCorrelation(chromaAcc, rotateProfile(KK_MINOR, shift))
            val tMaj  = pearsonCorrelation(chromaAcc, rotateProfile(TEMP_MAJOR, shift))
            val tMin  = pearsonCorrelation(chromaAcc, rotateProfile(TEMP_MINOR, shift))
            candidates += KeyCandidate(shift, "Major", (kkMaj + tMaj) / 2.0)
            candidates += KeyCandidate(shift, "Minor", (kkMin + tMin) / 2.0)
        }
        candidates.sortByDescending { it.corr }

        val best = candidates[0]
        val second = candidates[1]
        val gap = best.corr - second.corr
        // 0.25 de gap = confiança máxima (gap típico para tonalidade clara ≈ 0.2–0.4)
        val confidence = (gap / 0.25).coerceIn(0.0, 1.0)

        Log.d(TAG, "Key: ${NOTE_NAMES[best.key]} ${best.scale} " +
                "(corr=${"%.3f".format(best.corr)}, " +
                "2nd=${NOTE_NAMES[second.key]} ${second.scale} " +
                "${"%.3f".format(second.corr)}, " +
                "conf=${"%.2f".format(confidence)})")

        return Triple(NOTE_NAMES[best.key], best.scale, confidence)
    }

    // ════════════════════════════════════════════════════════════
    // DSP UTILITIES
    // ════════════════════════════════════════════════════════════

    /** Coeficientes Blackman-Harris 4 termos — minimiza lobes laterais (-92 dB). */
    private fun buildBlackmanHarrisCoeffs(n: Int): DoubleArray {
        val a0 = 0.35875; val a1 = 0.48829; val a2 = 0.14128; val a3 = 0.01168
        return DoubleArray(n) { i ->
            val x = 2.0 * PI * i / (n - 1)
            a0 - a1 * cos(x) + a2 * cos(2 * x) - a3 * cos(3 * x)
        }
    }

    /**
     * FFT de magnitude — Cooley-Tukey Radix-2 in-place.
     * Pads para próxima potência de 2 se necessário.
     */
    private fun fftMagnitude(input: DoubleArray): DoubleArray {
        val n = nextPowerOf2(input.size)
        val real = DoubleArray(n)
        input.copyInto(real, 0, 0, min(input.size, n))
        val imag = DoubleArray(n)

        // Bit-reversal permutation
        var j = 0
        for (i in 0 until n) {
            if (i < j) {
                var tmp = real[i]; real[i] = real[j]; real[j] = tmp
                tmp = imag[i]; imag[i] = imag[j]; imag[j] = tmp
            }
            var m = n / 2
            while (m >= 1 && j >= m) { j -= m; m /= 2 }
            j += m
        }

        // Cooley-Tukey butterfly
        var step = 2
        while (step <= n) {
            val half = step / 2
            val angle = -2.0 * PI / step
            for (k in 0 until n step step) {
                for (l in 0 until half) {
                    val theta = angle * l
                    val wr = cos(theta); val wi = sin(theta)
                    val i1 = k + l; val i2 = k + l + half
                    val tR = wr * real[i2] - wi * imag[i2]
                    val tI = wr * imag[i2] + wi * real[i2]
                    real[i2] = real[i1] - tR; imag[i2] = imag[i1] - tI
                    real[i1] += tR; imag[i1] += tI
                }
            }
            step *= 2
        }

        val halfN = n / 2
        return DoubleArray(halfN) { i -> sqrt(real[i] * real[i] + imag[i] * imag[i]) }
    }

    private fun nextPowerOf2(n: Int): Int {
        var p = 1; while (p < n) p = p shl 1; return p
    }

    private fun rotateProfile(profile: DoubleArray, shift: Int): DoubleArray {
        val n = profile.size
        return DoubleArray(n) { profile[(it + shift) % n] }
    }

    private fun pearsonCorrelation(x: DoubleArray, y: DoubleArray): Double {
        val n = x.size
        val meanX = x.average(); val meanY = y.average()
        var num = 0.0; var denX = 0.0; var denY = 0.0
        for (i in 0 until n) {
            val dx = x[i] - meanX; val dy = y[i] - meanY
            num += dx * dy; denX += dx * dx; denY += dy * dy
        }
        val den = sqrt(denX * denY)
        return if (den < 1e-10) 0.0 else num / den
    }

    private fun Double.roundToInt(): Int = this.roundToLong().toInt()
    private fun Double.roundToLong(): Long = if (this >= 0.0) (this + 0.5).toLong()
    else (this - 0.5).toLong()
}
