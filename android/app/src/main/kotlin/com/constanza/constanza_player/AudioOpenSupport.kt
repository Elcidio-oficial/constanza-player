package com.constanza.constanza_player

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/**
 * Lógica partilhada de **abertura de áudio externo**, usada pelo trampolim
 * [AudioOpenActivity] (activity nativa pura, sem Flutter) e pela [MainActivity]
 * (que recebe os itens já resolvidos no arranque a frio).
 *
 * Centralizar aqui evita duplicação e mantém o marcador do fluxo "tornar
 * padrão" (estático) acessível às duas activities, que vivem em tasks
 * diferentes e nunca partilham instância.
 */
object AudioOpenSupport {

    /** Extra com os itens JÁ RESOLVIDOS (uri/título) que o trampolim entrega à
     *  [MainActivity] no arranque a frio — ela não tem o grant para resolver. */
    const val EXTRA_RESOLVED = "constanza_resolved_audio"

    /** `true` enquanto a [MainActivity] está VIVA (entre onCreate e onDestroy) —
     *  i.e., o FlutterEngine está atado e utilizável. NÃO basta o engine estar em
     *  cache: ao fechar a app pelos recentes, o serviço de áudio mantém o processo
     *  vivo mas a MainActivity é destruída e o engine fica "detached" (FlutterJNI
     *  detached) — empurrar para ele falha em silêncio. Estático → reinicia a
     *  `false` quando o processo morre (arranque a frio real). */
    @Volatile var mainAlive: Boolean = false

    /** Faixa de amostra aberta no resolver "Abrir com" ao definir o app como
     *  padrão. O sistema reenvia esse MESMO áudio quando o usuário escolhe
     *  "Sempre" — não queremos tratar esse eco como um open real (tocar/overlay). */
    @Volatile var setDefaultSampleUri: String? = null
    @Volatile var setDefaultAtMs: Long = 0L

    private val AUDIO_EXTS = listOf(
        ".mp3", ".m4a", ".aac", ".flac", ".wav", ".ogg", ".oga", ".opus",
        ".wma", ".aiff", ".aif", ".mka", ".ape", ".alac", ".m4b",
    )

    /** Extrai a(s) faixa(s) de áudio de um intent ACTION_VIEW / SEND / SEND_MULTIPLE,
     *  preservando a URI ORIGINAL (necessário para detetar o eco do "tornar
     *  padrão"). A resolução para caminho tocável é um passo SEPARADO
     *  ([toPlayableItems]) — só aplicado a opens reais. Cada item é
     *  `{"uri": ..., "title": ...}`. */
    fun extractAudioUris(ctx: Context, intent: Intent?): List<Map<String, String?>> {
        intent ?: return emptyList()
        val uris: List<Uri> = when (intent.action) {
            Intent.ACTION_VIEW -> intent.data?.let { listOf(it) } ?: emptyList()
            Intent.ACTION_SEND -> extractStream(intent)?.let { listOf(it) } ?: emptyList()
            Intent.ACTION_SEND_MULTIPLE -> extractStreamList(intent)
            else -> emptyList()
        }
        if (uris.isEmpty()) return emptyList()
        val audio = uris.filter { isAudioUri(ctx, it, intent.type) }
        if (audio.isEmpty()) return emptyList()
        return audio.map { mapOf("uri" to it.toString(), "title" to displayName(ctx, it)) }
    }

    /** Resolve cada item para um caminho que o player consegue ler SEM depender
     *  do grant temporário do `content://` (que o ExoPlayer não recebe).
     *
     *  • `content://media/...` (MediaStore, faixa escaneada) → fica igual: o
     *    player lê via `READ_MEDIA_AUDIO`, sem grant.
     *  • `content://` de FileProvider/SAF (explorador) → resolve para o caminho
     *    real do ficheiro (via `/proc/self/fd`) ou, em último caso, copia para a
     *    cache. Ambos tocam por caminho de ficheiro, sem grant.
     *
     *  DEVE ser chamado a partir da activity que recebeu o intent (tem o grant
     *  ativo), e idealmente fora da main thread (a cópia pode demorar). */
    fun toPlayableItems(ctx: Context, items: List<Map<String, String?>>): List<Map<String, String?>> =
        items.map { item ->
            val original = item["uri"] ?: return@map item
            mapOf(
                "uri" to resolvePlayable(ctx, original, item["title"]),
                "title" to item["title"],
            )
        }

    /** `true` se [uris] é apenas o reenvio da faixa de amostra que abrimos há
     *  pouco para o usuário definir o app como padrão (escolheu "Sempre"). */
    fun isSetDefaultEcho(uris: List<String>): Boolean {
        val sample = setDefaultSampleUri ?: return false
        if (System.currentTimeMillis() - setDefaultAtMs > 30_000) return false
        return uris.any { it == sample }
    }

    // ── Serialização para o forward a frio ─────────────────────────────────

    fun encodeItems(items: List<Map<String, String?>>): String {
        val arr = JSONArray()
        for (it in items) {
            arr.put(JSONObject().apply {
                put("uri", it["uri"] ?: "")
                put("title", it["title"] ?: JSONObject.NULL)
            })
        }
        return arr.toString()
    }

    fun decodeItems(json: String?): List<Map<String, String?>> {
        json ?: return emptyList()
        return try {
            val arr = JSONArray(json)
            (0 until arr.length()).mapNotNull { i ->
                val o = arr.optJSONObject(i) ?: return@mapNotNull null
                val uri = o.optString("uri", "")
                if (uri.isEmpty()) return@mapNotNull null
                val title = if (o.isNull("title")) null else o.optString("title", null)
                mapOf("uri" to uri, "title" to title)
            }
        } catch (_: Exception) {
            emptyList()
        }
    }

    // ── Resolução de caminho tocável ───────────────────────────────────────

    private fun resolvePlayable(ctx: Context, uriString: String, title: String?): String {
        val uri = try { Uri.parse(uriString) } catch (_: Exception) { return uriString }
        when (uri.scheme) {
            "file" -> return uri.path ?: uriString
            "http", "https" -> return uriString
            "content" -> {
                // MediaStore: o player lê direto via READ_MEDIA_AUDIO, sem grant.
                if (uri.authority == "media") return uriString
                // FileProvider/SAF do explorador: resolve para ficheiro real…
                resolveRealPath(ctx, uri)?.let { return it }
                // …ou, se não der, copia para a cache (usa o grant ATIVO agora).
                copyToCache(ctx, uri, title)?.let { return it }
                return uriString // desiste; falhará, mas não pior que antes
            }
            else -> return uriString
        }
    }

    /** Caminho real do ficheiro por trás de um `content://` de FileProvider,
     *  via o link `/proc/self/fd/N` do descritor aberto (precisa do grant). */
    private fun resolveRealPath(ctx: Context, uri: Uri): String? {
        return try {
            ctx.contentResolver.openFileDescriptor(uri, "r")?.use { pfd ->
                val real = File("/proc/self/fd/${pfd.fd}").canonicalPath
                if (real.startsWith("/proc/")) return null // não é ficheiro (pipe/socket)
                val f = File(real)
                if (f.exists() && f.canRead()) real else null
            }
        } catch (_: Exception) {
            null
        }
    }

    /** Copia o conteúdo do `content://` para a cache da app enquanto o grant
     *  está ativo, devolvendo um caminho estável que toca sem grant. */
    private fun copyToCache(ctx: Context, uri: Uri, title: String?): String? {
        return try {
            val dir = File(ctx.cacheDir, "external_audio").apply { mkdirs() }
            pruneOld(dir)
            val name = sanitize(title ?: uri.lastPathSegment ?: "audio")
            val out = File(dir, "${System.currentTimeMillis()}_$name")
            ctx.contentResolver.openInputStream(uri)?.use { input ->
                out.outputStream().use { input.copyTo(it, DEFAULT_BUFFER_SIZE) }
            } ?: return null
            if (out.length() <= 0L) {
                out.delete(); return null
            }
            out.path
        } catch (_: Exception) {
            null
        }
    }

    /** Apaga cópias com mais de 1 dia para a cache não crescer indefinidamente. */
    private fun pruneOld(dir: File) {
        val cutoff = System.currentTimeMillis() - 24L * 60 * 60 * 1000
        try {
            dir.listFiles()?.forEach { if (it.lastModified() < cutoff) it.delete() }
        } catch (_: Exception) {
        }
    }

    private fun sanitize(name: String): String {
        val cleaned = name.replace(Regex("[^A-Za-z0-9._-]"), "_")
        return if (cleaned.length > 100) cleaned.takeLast(100) else cleaned
    }

    // ── Extração ───────────────────────────────────────────────────────────

    @Suppress("DEPRECATION")
    private fun extractStream(intent: Intent): Uri? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU)
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        else
            intent.getParcelableExtra(Intent.EXTRA_STREAM)

    @Suppress("DEPRECATION")
    private fun extractStreamList(intent: Intent): List<Uri> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU)
            intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java) ?: emptyList()
        else
            intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM) ?: emptyList()

    private fun isAudioUri(ctx: Context, uri: Uri, intentType: String?): Boolean {
        if (intentType?.startsWith("audio") == true) return true
        if (intentType == "application/ogg") return true
        val resolved = try { ctx.contentResolver.getType(uri) } catch (_: Exception) { null }
        if (resolved?.startsWith("audio") == true) return true
        if (resolved == "application/ogg") return true
        val s = uri.toString().lowercase()
        return AUDIO_EXTS.any { s.endsWith(it) }
    }

    private fun displayName(ctx: Context, uri: Uri): String? {
        if (uri.scheme == "content") {
            try {
                ctx.contentResolver.query(
                    uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null,
                )?.use { c ->
                    if (c.moveToFirst()) {
                        val idx = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (idx >= 0) return c.getString(idx)
                    }
                }
            } catch (_: Exception) {
            }
        }
        return uri.lastPathSegment?.substringAfterLast('/')
    }
}
