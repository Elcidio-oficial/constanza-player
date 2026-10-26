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

    // Planos de FFT (twiddle factors + bit-reversal) por tamanho. A FFT é
    // chamada milhares de vezes por análise (≈5000 frames p/ BPM + ≈640 p/
    // tonalidade), e antes recalculava cos/sin DENTRO do butterfly a cada
    // chamada — o gargalo que fazia a análise "ficar processando" por dezenas
    // de segundos. Pré-computar uma vez por tamanho reduz o custo em ~3-5×.
    // Acesso serializado pelo analysisMutex (uma análise por vez), logo o
    // HashMap não precisa de sincronização.
    private val fftPlans = HashMap<Int, FftPlan>()

    private fun planFor(n: Int): FftPlan = fftPlans.getOrPut(n) { FftPlan(n) }

    /** Twiddle factors e índices de bit-reversal pré-computados para FFT de tamanho [n]. */
    private class FftPlan(val n: Int) {
        val cos = DoubleArray(n / 2)
        val sin = DoubleArray(n / 2)
        val rev = IntArray(n)
        init {
            for (i in 0 until n / 2) {
                val a = -2.0 * PI * i / n
                cos[i] = kotlin.math.cos(a)
                sin[i] = kotlin.math.sin(a)
            }
            var j = 0
            for (i in 0 until n) {
                rev[i] = j
                var m = n / 2
                while (m >= 1 && j >= m) { j -= m; m /= 2 }
                j += m
            }
        }
    }

    companion object {
        private const val TAG = "AudioAnalysis"
        private const val CHANNEL_NAME = "com.constanza.audio_analysis"

        // ── Duração e timing ──────────────────────────────────────────
        /** Segundos de áudio analisados. 60 s = estatísticas mais robustas. */
        private const val ANALYSIS_DURATION_SEC = 60

        // ── Envelope (barras de progresso) ────────────────────────────
        /** Janela de RMS do envelope: 50 ms = 20 leituras/s, suficiente p/ batidas. */
        private const val ENVELOPE_FRAME_MS = 50
        /** RMS que vira 255. Fixo (não pelo pico) para poder enviar em pedaços. */
        private const val ENVELOPE_REF_RMS = 0.5
        /** 2 s por pedaço; os 2 primeiros têm 0,5 s para a barra reagir logo. */
        private const val ENVELOPE_CHUNK_FRAMES = 40
        private const val ENVELOPE_FIRST_CHUNK_FRAMES = 10

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

        /** Pico espectral só conta se tiver ≥ 2 % do maior pico do frame. */
        private const val PEAK_REL_THRESHOLD = 0.02

        /** Frequência de referência para MIDI ↔ freq (A4 = 440 Hz). */
        private const val A4_REF = 440.0

        /** Faixa do chroma: C2 (65 Hz) → C7 (2093 Hz). Acima disso é brilho/percussão. */
        private const val CHROMA_FREQ_MIN = 65.0
        private const val CHROMA_FREQ_MAX = 2100.0

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
            "envelope" -> {
                val uri = call.argument<String>("uri")
                val requestId = call.argument<Int>("id")
                val startMs = (call.argument<Int>("startMs") ?: 0).coerceAtLeast(0)
                if (uri == null || requestId == null) {
                    result.error("INVALID_ARGS", "uri and id required", null)
                    return
                }
                // Job e mutex próprios: o envelope é pedido a cada troca
                // de música e não deve esperar (nem cancelar) a análise BPM/Key.
                activeWaveformJob?.cancel()
                activeWaveformJob = scope.launch {
                    try {
                        val frames = waveformMutex.withLock {
                            computeEnvelope(uri, startMs) { start, bytes ->
                                withContext(Dispatchers.Main) {
                                    channel.invokeMethod("envelopeChunk", mapOf(
                                        "id" to requestId,
                                        "start" to start,
                                        "data" to bytes,
                                    ))
                                }
                            }
                        }
                        withContext(Dispatchers.Main) {
                            result.success(mapOf(
                                "frameMs" to ENVELOPE_FRAME_MS,
                                "frames" to frames,
                            ))
                        }
                    } catch (e: CancellationException) {
                        withContext(Dispatchers.Main + NonCancellable) { result.success(null) }
                    } catch (e: Exception) {
                        Log.e(TAG, "Envelope failed for $uri", e)
                        withContext(Dispatchers.Main) {
                            result.error("ENVELOPE_ERROR", e.message ?: "Unknown error", null)
                        }
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    // ════════════════════════════════════════════════════════════
    // ENVELOPE — energia da música a cada ENVELOPE_FRAME_MS
    // ════════════════════════════════════════════════════════════

    private val waveformMutex = Mutex()
    private var activeWaveformJob: Job? = null

    /**
     * Decodifica a música em streaming e envia, em pedaços, o RMS de cada
     * janela de [ENVELOPE_FRAME_MS] como bytes 0..255 (escala fixa, então
     * partes baixas da música ficam baixas mesmo antes do fim da leitura).
     *
     * Começa em [startMs] (onde a reprodução está) para as barras pulsarem
     * em ~100 ms, segue até o fim e depois lê 0..startMs. Memória constante:
     * o PCM nunca é guardado. Retorna o total de quadros.
     */
    private suspend fun computeEnvelope(
        uri: String,
        startMs: Int,
        emit: suspend (start: Int, bytes: ByteArray) -> Unit,
    ): Int {
        val ctx = context ?: throw IllegalStateException("No context")
        val extractor = MediaExtractor()
        var codec: MediaCodec? = null
        try {
            if (uri.startsWith("content://")) {
                extractor.setDataSource(ctx, android.net.Uri.parse(uri), null)
            } else {
                extractor.setDataSource(uri)
            }
            var audioTrack = -1
            for (i in 0 until extractor.trackCount) {
                val mime = extractor.getTrackFormat(i).getString(MediaFormat.KEY_MIME)
                if (mime?.startsWith("audio/") == true) { audioTrack = i; break }
            }
            if (audioTrack < 0) throw IllegalArgumentException("No audio track found")
            extractor.selectTrack(audioTrack)
            val format = extractor.getTrackFormat(audioTrack)
            val mime = format.getString(MediaFormat.KEY_MIME)
                ?: throw IllegalArgumentException("No mime type")

            codec = MediaCodec.createDecoderByType(mime)
            codec.configure(format, null, null, 0)
            codec.start()

            val pcm = PcmFormat(
                channels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT),
                sampleRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE),
            )
            val startUs = startMs * 1000L
            var maxFrame = decodeRange(codec, extractor, pcm, startUs, Long.MAX_VALUE, emit)
            if (startUs > 0) {
                maxFrame = max(maxFrame, decodeRange(codec, extractor, pcm, 0L, startUs, emit))
            }
            return maxFrame + 1
        } finally {
            try { codec?.stop() } catch (_: Exception) {}
            try { codec?.release() } catch (_: Exception) {}
            extractor.release()
        }
    }

    private class PcmFormat(var channels: Int, var sampleRate: Int, var isFloat: Boolean = false)

    /** Decodifica [fromUs, toUs) e emite os quadros; retorna o maior índice visto. */
    private suspend fun decodeRange(
        codec: MediaCodec,
        extractor: MediaExtractor,
        pcm: PcmFormat,
        fromUs: Long,
        toUs: Long,
        emit: suspend (start: Int, bytes: ByteArray) -> Unit,
    ): Int {
        extractor.seekTo(fromUs, MediaExtractor.SEEK_TO_PREVIOUS_SYNC)
        codec.flush()

        val frameUs = ENVELOPE_FRAME_MS * 1000L
        var chunkStart = -1
        val chunk = ByteArray(ENVELOPE_CHUNK_FRAMES)
        var chunkLen = 0
        var chunksSent = 0
        var curFrame = -1
        var sumSq = 0.0
        var count = 0
        var maxFrame = -1

        suspend fun flushChunk() {
            if (chunkLen == 0) return
            emit(chunkStart, chunk.copyOf(chunkLen))
            chunksSent++
            chunkStart = -1
            chunkLen = 0
        }

        suspend fun closeFrame() {
            if (curFrame < 0 || count == 0) return
            val rms = sqrt(sumSq / count)
            // Escala fixa: RMS 0.5 (≈ volume máximo de um master moderno) = 255.
            val byte = (sqrt(rms / ENVELOPE_REF_RMS).coerceAtMost(1.0) * 255).roundToInt()
            if (chunkStart >= 0 && curFrame != chunkStart + chunkLen) flushChunk()
            if (chunkStart < 0) chunkStart = curFrame
            chunk[chunkLen++] = byte.toByte()
            maxFrame = max(maxFrame, curFrame)
            // Primeiros pedaços pequenos: a barra começa a pulsar logo.
            val limit = if (chunksSent < 2) ENVELOPE_FIRST_CHUNK_FRAMES else ENVELOPE_CHUNK_FRAMES
            if (chunkLen >= limit) flushChunk()
            sumSq = 0.0
            count = 0
        }

        val bufferInfo = MediaCodec.BufferInfo()
        var inputDone = false
        var done = false
        val timeoutUs = 10_000L

        while (!done) {
            coroutineContext.ensureActive()
            if (!inputDone) {
                val inputIdx = codec.dequeueInputBuffer(timeoutUs)
                if (inputIdx >= 0) {
                    val inputBuf = codec.getInputBuffer(inputIdx)
                    val size = if (inputBuf == null) -1 else extractor.readSampleData(inputBuf, 0)
                    if (size < 0 || extractor.sampleTime >= toUs) {
                        codec.queueInputBuffer(inputIdx, 0, 0, 0,
                            MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                        inputDone = true
                    } else {
                        codec.queueInputBuffer(inputIdx, 0, size, extractor.sampleTime, 0)
                        extractor.advance()
                    }
                }
            }

            val outputIdx = codec.dequeueOutputBuffer(bufferInfo, timeoutUs)
            if (outputIdx == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                val out = codec.outputFormat
                pcm.channels = out.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                pcm.sampleRate = out.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                pcm.isFloat = out.containsKey(MediaFormat.KEY_PCM_ENCODING) &&
                    out.getInteger(MediaFormat.KEY_PCM_ENCODING) ==
                    android.media.AudioFormat.ENCODING_PCM_FLOAT
                continue
            }
            if (outputIdx < 0) continue
            if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) done = true

            val outputBuf = codec.getOutputBuffer(outputIdx)
            if (outputBuf != null && bufferInfo.size > 0 && bufferInfo.presentationTimeUs < toUs) {
                outputBuf.position(bufferInfo.offset)
                outputBuf.limit(bufferInfo.offset + bufferInfo.size)
                outputBuf.order(ByteOrder.LITTLE_ENDIAN)
                val floats = if (pcm.isFloat) outputBuf.asFloatBuffer() else null
                val shorts = if (pcm.isFloat) null else outputBuf.asShortBuffer()
                val total = floats?.remaining() ?: shorts!!.remaining()
                val ch = pcm.channels
                // Índice do quadro pelo timestamp do buffer: funciona após seek.
                val usPerSample = 1_000_000.0 / pcm.sampleRate
                var i = 0
                var k = 0
                while (i + ch <= total) {
                    val frame = ((bufferInfo.presentationTimeUs + k * usPerSample) / frameUs).toInt()
                    if (frame != curFrame) {
                        closeFrame()
                        curFrame = frame
                    }
                    var mono = 0f
                    for (c in 0 until ch) {
                        mono += floats?.get(i + c) ?: (shorts!!.get(i + c) / 32768f)
                    }
                    mono /= ch
                    sumSq += mono * mono
                    count++
                    i += ch
                    k++
                }
            }
            codec.releaseOutputBuffer(outputIdx, false)
        }
        closeFrame()
        flushChunk()
        return maxFrame
    }

    // ════════════════════════════════════════════════════════════
    // MAIN ANALYSIS PIPELINE
    // ════════════════════════════════════════════════════════════

    private data class DecodedAudio(val samples: FloatArray, val sampleRate: Int)

    private suspend fun analyzeAudio(uri: String): Map<String, Any?> {
        val ctx = context ?: throw IllegalStateException("No context")

        val decoded = decodeToMonoFloat(ctx, uri)
        val samples = applyDcBlocker(decoded.samples)
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
     * DC blocker in-place: y[n] = x[n] - x[n-1] + 0.995 * y[n-1].
     * Remove offset DC que causa vazamento espectral na bin 0. Sem pré-ênfase:
     * ela distorcia o cromagrama (agudos dominavam a tonalidade), e o BPM já
     * pesa as bandas separadamente.
     */
    private fun applyDcBlocker(samples: FloatArray): FloatArray {
        var prevIn = 0f
        var prevOut = 0f
        for (i in samples.indices) {
            val x = samples[i]
            val y = x - prevIn + 0.995f * prevOut
            prevIn = x
            prevOut = y
            samples[i] = y
        }
        return samples
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

            // Pula a introdução: analisa a partir de 25 % da faixa (limitado
            // para ainda caber ANALYSIS_DURATION_SEC). Intros sem bateria ou
            // fora do tom davam BPM/tonalidade aleatórios.
            val durationUs = if (format.containsKey(MediaFormat.KEY_DURATION))
                format.getLong(MediaFormat.KEY_DURATION) else 0L
            val windowUs = ANALYSIS_DURATION_SEC * 1_000_000L
            val startUs = min(durationUs / 4, durationUs - windowUs).coerceAtLeast(0L)
            if (startUs > 0) extractor.seekTo(startUs, MediaExtractor.SEEK_TO_PREVIOUS_SYNC)

            codec = MediaCodec.createDecoderByType(mime)
            codec.configure(format, null, null, 0)
            codec.start()

            // FloatArray primitivo — 4 bytes/sample vs ~16 bytes/sample do
            // ArrayList<Float> (boxing). Reduz o footprint de ~60MB p/ ~10MB
            // em 60s @44100Hz.
            // Folga de 2× para decoders (HE-AAC) que dobram a taxa de saída.
            val monoSamples = FloatArray(ANALYSIS_DURATION_SEC * sampleRate * 2)
            var maxSamples = ANALYSIS_DURATION_SEC * sampleRate
            var sampleCount = 0
            var isFloat = false
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
                if (outputIdx == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    // A taxa/canais reais vêm daqui, não do container: com a
                    // taxa errada o BPM saía multiplicado ou dividido.
                    val out = codec.outputFormat
                    channelCount = out.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                    sampleRate = out.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                    isFloat = out.containsKey(MediaFormat.KEY_PCM_ENCODING) &&
                        out.getInteger(MediaFormat.KEY_PCM_ENCODING) ==
                        android.media.AudioFormat.ENCODING_PCM_FLOAT
                    maxSamples = min(ANALYSIS_DURATION_SEC * sampleRate, monoSamples.size)
                    continue
                }
                if (outputIdx >= 0) {
                    if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                        outputDone = true
                    }
                    val outputBuf = codec.getOutputBuffer(outputIdx)
                    if (outputBuf == null) {
                        codec.releaseOutputBuffer(outputIdx, false)
                        continue
                    }
                    outputBuf.position(bufferInfo.offset)
                    outputBuf.limit(bufferInfo.offset + bufferInfo.size)
                    outputBuf.order(ByteOrder.LITTLE_ENDIAN)
                    val floats = if (isFloat) outputBuf.asFloatBuffer() else null
                    val shorts = if (isFloat) null else outputBuf.asShortBuffer()
                    val samplesInBuffer = floats?.remaining() ?: shorts!!.remaining()

                    var i = 0
                    while (i + channelCount <= samplesInBuffer && sampleCount < maxSamples) {
                        var sum = 0f
                        for (ch in 0 until channelCount) {
                            sum += floats?.get(i + ch) ?: (shorts!!.get(i + ch) / 32768f)
                        }
                        monoSamples[sampleCount++] = sum / channelCount
                        i += channelCount
                    }
                    codec.releaseOutputBuffer(outputIdx, false)
                }
            }

            // Trim para o tamanho real. copyOf cria uma nova FloatArray;
            // aqui o pico temporário é ~20MB (original + copia) — aceitável,
            // e GC recolhe o 'monoSamples' logo em seguida.
            val trimmed = if (sampleCount == monoSamples.size) monoSamples
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

        // Step 1 — magnitude spectra (Hann window para BPM).
        // Janela pré-computada uma vez (antes recalculava cos por amostra/frame).
        val hannWindow = DoubleArray(frameSize) { i ->
            0.5 * (1.0 - cos(2.0 * PI * i / (frameSize - 1)))
        }
        // Step 2 — spectral flux por banda, só com o espectro anterior em
        // memória. Magnitude comprimida por log(1 + γ·|X|): sem isso o fluxo
        // seguia o volume (crescendos) em vez das batidas.
        val rawFlux = Array(NUM_BANDS) { DoubleArray(numFrames - 1) }
        val windowed = DoubleArray(frameSize)
        var prev: DoubleArray? = null
        for (f in 0 until numFrames) {
            val start = f * hop
            for (i in 0 until frameSize) {
                windowed[i] = if (start + i < samples.size)
                    samples[start + i].toDouble() * hannWindow[i] else 0.0
            }
            val spec = fftMagnitude(windowed)
            for (bin in spec.indices) spec[bin] = ln(1.0 + 100.0 * spec[bin])
            val p = prev
            if (p != null) {
                for (band in 0 until NUM_BANDS) {
                    val lowBin  = max(1, (BAND_EDGES[band] / binWidth).toInt())
                    val highBin = min(spec.size - 1, (BAND_EDGES[band + 1] / binWidth).toInt())
                    if (lowBin >= highBin) continue
                    var flux = 0.0
                    for (bin in lowBin until highBin) {
                        val diff = spec[bin] - p[bin]
                        if (diff > 0.0) flux += diff  // half-wave rectified
                    }
                    rawFlux[band][f - 1] = flux / (highBin - lowBin)
                }
            }
            prev = spec
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

            // Prior perceptual (Ellis 2007): log-Gaussiana em 120 BPM, σ = 1
            // oitava. Resolve a ambiguidade dobro/metade a favor do andamento
            // que a pessoa marcaria batendo o pé.
            val bpmAtLag = framesPerSecond * 60.0 / lag
            val oct = log2(bpmAtLag / 120.0)
            harmonicAcf[lag] = sum * exp(-0.5 * oct * oct)
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
        val coarseBpm = when {
            rawBpm in BPM_MIN..BPM_MAX -> rawBpm
            rawBpm * 2 in BPM_MIN..BPM_MAX -> rawBpm * 2
            rawBpm / 2 in BPM_MIN..BPM_MAX -> rawBpm / 2
            rawBpm * 2 < BPM_MIN && rawBpm * 4 in BPM_MIN..BPM_MAX -> rawBpm * 4
            else -> rawBpm.coerceIn(BPM_MIN, BPM_MAX)
        }

        // Step 7b — refinamento fino. Cada passo de lag vale ~3,5 BPM perto
        // de 136, e a parábola não basta para acertar a unidade.
        val bpm = refineTempo(combinedOnset, framesPerSecond, coarseBpm)
        Log.d(TAG, "BPM refine: ${"%.2f".format(coarseBpm)} → ${"%.2f".format(bpm)}")

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

    /**
     * Refina o andamento em ±3 % de [bpm] com passos de 0,02 BPM. Para cada
     * candidato, alinha um pente de batidas (com meia-batida a 0,5) sobre o
     * onset inteiro e pega a melhor fase; como o erro acumula ao longo dos
     * 60 s, só o andamento exato mantém o pente sobre os ataques até o fim.
     * Onset suavizado (±1 frame) para tolerar o jitter de 11 ms do hop.
     */
    private fun refineTempo(onset: DoubleArray, fps: Double, bpm: Double): Double {
        val n = onset.size
        if (n < 16) return bpm
        val smooth = DoubleArray(n) { i ->
            0.25 * onset[max(0, i - 1)] + 0.5 * onset[i] + 0.25 * onset[min(n - 1, i + 1)]
        }
        fun at(t: Double): Double {
            val i = t.toInt()
            if (i < 0 || i >= n - 1) return 0.0
            val fr = t - i
            return smooth[i] * (1 - fr) + smooth[i + 1] * fr
        }

        var bestBpm = bpm
        var bestScore = -1.0
        val lo = bpm * 0.97
        val hi = bpm * 1.03
        var cand = lo
        while (cand <= hi) {
            val period = fps * 60.0 / cand
            val beats = ((n - 1) / period).toInt()
            if (beats >= 4) {
                // Fases a cada 0,5 frame dentro de um período.
                var phase = 0.0
                while (phase < period) {
                    var s = 0.0
                    for (k in 0 until beats) {
                        val t = phase + k * period
                        s += at(t) + 0.5 * at(t + period / 2)
                    }
                    s /= beats
                    if (s > bestScore) { bestScore = s; bestBpm = cand }
                    phase += 0.5
                }
            }
            cand += 0.02
        }
        return bestBpm
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

        // Passagem única: guarda só os picos espectrais de cada frame (freq com
        // interpolação parabólica + magnitude). Bins fora de pico são vazamento
        // da janela e ruído de bateria — somá-los borrava o cromagrama inteiro.
        class Peak(val midi: Double, val mag: Double)
        val framePeaks = ArrayList<List<Peak>>(numFrames)
        val frameRms = DoubleArray(numFrames)
        // Afinação por média circular da fase de semitom dos picos.
        var tuneRe = 0.0
        var tuneIm = 0.0

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
            frameRms[f] = rms
            if (rms < 1e-4) { framePeaks.add(emptyList()); continue }

            val spectrum = fftMagnitude(windowed)
            val loBin = max(2, (CHROMA_FREQ_MIN / binWidth).toInt())
            val hiBin = min(spectrum.size - 2, (CHROMA_FREQ_MAX / binWidth).toInt())
            var frameMax = 0.0
            for (bin in loBin..hiBin) frameMax = max(frameMax, spectrum[bin])
            val floor = frameMax * PEAK_REL_THRESHOLD

            val peaks = ArrayList<Peak>()
            for (bin in loBin..hiBin) {
                val b = spectrum[bin]
                if (b < floor || b <= spectrum[bin - 1] || b < spectrum[bin + 1]) continue
                // Interpolação parabólica em escala log → frequência sub-bin.
                val a = ln(spectrum[bin - 1] + 1e-12)
                val lb = ln(b + 1e-12)
                val c = ln(spectrum[bin + 1] + 1e-12)
                val denom = a - 2 * lb + c
                val delta = if (abs(denom) > 1e-12) (0.5 * (a - c) / denom).coerceIn(-0.5, 0.5) else 0.0
                val freq = (bin + delta) * binWidth
                val midi = 12.0 * log2(freq / A4_REF) + 69.0
                // sqrt comprime a dinâmica: graves fortes não dominam sozinhos.
                val mag = sqrt(b)
                peaks.add(Peak(midi, mag))
                val phase = 2.0 * PI * midi
                tuneRe += mag * cos(phase)
                tuneIm += mag * sin(phase)
            }
            framePeaks.add(peaks)
        }

        // Desvio em semitom fracional (-0.5..+0.5); 0 = afinado em A4 = 440 Hz.
        val tuningOffset = if (tuneRe * tuneRe + tuneIm * tuneIm > 1e-20)
            atan2(tuneIm, tuneRe) / (2.0 * PI) else 0.0

        Log.d(TAG, "Tuning offset: ${"%.3f".format(tuningOffset)} semitones")

        for (f in 0 until numFrames) {
            val peaks = framePeaks[f]
            if (peaks.isEmpty()) continue
            val rms = frameRms[f]
            val frameChroma = DoubleArray(NUM_CHROMA)

            for (p in peaks) {
                val midi = p.midi - tuningOffset
                val nearest = midi.roundToInt()
                // Pico longe do semitom (> 35 cents) é ruído/percussão.
                val dev = abs(midi - nearest)
                if (dev > 0.35) continue
                val w = cos(PI * dev / 0.7).pow(2)
                val chromaIdx = ((nearest % 12) + 12) % 12
                frameChroma[chromaIdx] += p.mag * w
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
     * FFT de magnitude — Cooley-Tukey Radix-2 com twiddle factors e
     * bit-reversal pré-computados (ver [FftPlan]). Pads para a próxima
     * potência de 2 se necessário.
     */
    private fun fftMagnitude(input: DoubleArray): DoubleArray {
        val n = nextPowerOf2(input.size)
        val plan = planFor(n)
        val real = DoubleArray(n)
        val imag = DoubleArray(n)

        // Copia já aplicando a permutação bit-reversal: real[rev[i]] = input[i].
        // Slots não escritos (padding) ficam 0 — equivalente a zero-pad + reversa.
        val copyLen = min(input.size, n)
        for (i in 0 until copyLen) real[plan.rev[i]] = input[i]

        // Cooley-Tukey butterfly usando a tabela de twiddles do plano.
        var step = 2
        while (step <= n) {
            val half = step / 2
            val tableStep = n / step
            var k = 0
            while (k < n) {
                var ti = 0
                for (l in 0 until half) {
                    val wr = plan.cos[ti]; val wi = plan.sin[ti]
                    val i1 = k + l; val i2 = k + l + half
                    val tR = wr * real[i2] - wi * imag[i2]
                    val tI = wr * imag[i2] + wi * real[i2]
                    real[i2] = real[i1] - tR; imag[i2] = imag[i1] - tI
                    real[i1] += tR; imag[i1] += tI
                    ti += tableStep
                }
                k += step
            }
            step *= 2
        }

        val halfN = n / 2
        return DoubleArray(halfN) { i -> sqrt(real[i] * real[i] + imag[i] * imag[i]) }
    }

    private fun nextPowerOf2(n: Int): Int {
        var p = 1; while (p < n) p = p shl 1; return p
    }

    /** Perfil com a tônica em [shift]: rotated[shift] = profile[0]. */
    private fun rotateProfile(profile: DoubleArray, shift: Int): DoubleArray {
        val n = profile.size
        return DoubleArray(n) { profile[(it - shift + n) % n] }
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
