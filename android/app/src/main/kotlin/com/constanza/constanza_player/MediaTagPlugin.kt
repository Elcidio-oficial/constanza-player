package com.constanza.constanza_player

import android.app.Activity
import android.content.ContentValues
import android.content.Context
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.util.Log
import androidx.annotation.RequiresApi
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import org.jaudiotagger.audio.AudioFileIO
import org.jaudiotagger.tag.FieldKey
import org.jaudiotagger.tag.images.ArtworkFactory
import java.io.File

class MediaTagPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware,
    PluginRegistry.ActivityResultListener {

    private lateinit var channel: MethodChannel
    private var context: Context? = null
    private var activity: Activity? = null
    private var pendingResult: MethodChannel.Result? = null

    // Pending write data — stored while waiting for user permission dialog
    private var pendingWriteFilePath: String? = null
    private var pendingWriteTags: Map<String, Any?>? = null
    private var pendingWriteCover: ByteArray? = null
    private var pendingContentUri: Uri? = null

    companion object {
        private const val TAG = "MediaTagPlugin"
        private const val REQUEST_WRITE = 9000
        private const val REQUEST_DELETE = 9001
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "com.constanza.media_tag")
        channel.setMethodCallHandler(this)
        context = binding.applicationContext
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        context = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() { activity = null }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }
    override fun onDetachedFromActivity() { activity = null }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "writeTags" -> {
                val filePath = call.argument<String>("filePath")
                val tags = call.argument<Map<String, Any?>>("tags")
                val coverBytes = call.argument<ByteArray>("coverBytes")
                if (filePath == null || tags == null) {
                    result.error("INVALID_ARGS", "filePath and tags required", null)
                    return
                }
                writeTags(filePath, tags, coverBytes, result)
            }
            "deleteSong" -> {
                val filePath = call.argument<String>("filePath")
                val songId = call.argument<Int>("songId")
                if (filePath == null) {
                    result.error("INVALID_ARGS", "filePath required", null)
                    return
                }
                deleteSong(filePath, songId, result)
            }
            else -> result.notImplemented()
        }
    }

    // ════════════════════════════════════════════════════════════
    // WRITE TAGS
    // ════════════════════════════════════════════════════════════

    private fun writeTags(filePath: String, tags: Map<String, Any?>, coverBytes: ByteArray?, result: MethodChannel.Result) {
        val file = File(filePath)
        if (!file.exists()) {
            result.error("FILE_NOT_FOUND", "File not found: $filePath", null)
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val ctx = context ?: run {
                result.error("NO_CONTEXT", "Context unavailable", null)
                return
            }
            val contentUri = findContentUri(ctx, filePath)
            if (contentUri != null) {
                requestWritePermissionAndWrite(contentUri, filePath, tags, coverBytes, result)
            } else {
                // Not in MediaStore — write directly (app-private file)
                doWriteTags(filePath, tags, coverBytes, result)
            }
        } else {
            doWriteTags(filePath, tags, coverBytes, result)
        }
    }

    @RequiresApi(Build.VERSION_CODES.R)
    private fun requestWritePermissionAndWrite(
        contentUri: Uri,
        filePath: String,
        tags: Map<String, Any?>,
        coverBytes: ByteArray?,
        result: MethodChannel.Result
    ) {
        val act = activity
        if (act == null) {
            result.error("NO_ACTIVITY", "Activity unavailable", null)
            return
        }
        try {
            val writeRequest = MediaStore.createWriteRequest(
                act.contentResolver,
                listOf(contentUri)
            )
            pendingResult = result
            pendingWriteFilePath = filePath
            pendingWriteTags = tags
            pendingWriteCover = coverBytes
            pendingContentUri = contentUri
            act.startIntentSenderForResult(
                writeRequest.intentSender,
                REQUEST_WRITE, null, 0, 0, 0
            )
        } catch (e: Exception) {
            Log.w(TAG, "createWriteRequest failed, trying direct: ${e.message}")
            doWriteTags(filePath, tags, coverBytes, result)
        }
    }

    // ── Writes tags directly via File path (Android < 11 or app-private files) ──
    private fun doWriteTags(filePath: String, tags: Map<String, Any?>, coverBytes: ByteArray?, result: MethodChannel.Result) {
        try {
            val file = File(filePath)
            val audioFile = AudioFileIO.read(file)
            val tag = audioFile.tagOrCreateAndSetDefault

            applyTagFields(tag, tags, coverBytes)
            audioFile.commit()

            updateMediaStore(filePath, tags)
            triggerMediaScan(filePath)
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Error writing tags to $filePath", e)
            result.error("WRITE_ERROR", e.message ?: "Failed to write tags", null)
        }
    }

    // ── Writes tags via ContentResolver (Android 11+ with MediaStore permission) ──
    @RequiresApi(Build.VERSION_CODES.R)
    private fun doWriteTagsViaContentResolver(
        contentUri: Uri,
        filePath: String,
        tags: Map<String, Any?>,
        coverBytes: ByteArray?,
        result: MethodChannel.Result
    ) {
        val ctx = context ?: run {
            result.error("NO_CONTEXT", "Context unavailable", null)
            return
        }

        val ext = filePath.substringAfterLast('.', "mp3")
        val tempFile = File(ctx.cacheDir, "constanza_tag_edit_${System.currentTimeMillis()}.$ext")

        try {
            // 1. Copy original from MediaStore to temp file
            ctx.contentResolver.openInputStream(contentUri)?.use { input ->
                tempFile.outputStream().use { output -> input.copyTo(output) }
            } ?: run {
                tempFile.delete()
                result.error("READ_ERROR", "Cannot open input stream for $contentUri", null)
                return
            }

            // 2. Edit tags on temp file using jaudiotagger
            val audioFile = AudioFileIO.read(tempFile)
            val tag = audioFile.tagOrCreateAndSetDefault
            applyTagFields(tag, tags, coverBytes)
            audioFile.commit()

            // 3. Write modified file back to MediaStore via ContentResolver
            // Use "wt" mode to truncate before writing (overwrite)
            ctx.contentResolver.openOutputStream(contentUri, "wt")?.use { output ->
                tempFile.inputStream().use { input -> input.copyTo(output) }
            } ?: run {
                tempFile.delete()
                result.error("WRITE_ERROR", "Cannot open output stream for $contentUri", null)
                return
            }

            tempFile.delete()
            updateMediaStore(filePath, tags)
            triggerMediaScan(filePath)
            result.success(true)
        } catch (e: Exception) {
            tempFile.delete()
            Log.e(TAG, "Error writing tags via ContentResolver to $filePath", e)
            result.error("WRITE_ERROR", e.message ?: "Failed to write tags", null)
        }
    }

    // ── Applies tag fields to an open jaudiotagger Tag object ──
    private fun applyTagFields(tag: org.jaudiotagger.tag.Tag, tags: Map<String, Any?>, coverBytes: ByteArray?) {
        tags["title"]?.toString()?.let { tag.setField(FieldKey.TITLE, it) }
        tags["artist"]?.toString()?.let { tag.setField(FieldKey.ARTIST, it) }
        tags["album"]?.toString()?.let { tag.setField(FieldKey.ALBUM, it) }
        tags["genre"]?.toString()?.let { tag.setField(FieldKey.GENRE, it) }
        tags["composer"]?.toString()?.let { tag.setField(FieldKey.COMPOSER, it) }
        tags["trackNumber"]?.toString()?.let { tag.setField(FieldKey.TRACK, it) }

        if (coverBytes != null && coverBytes.isNotEmpty()) {
            try {
                tag.deleteArtworkField()
                val artwork = ArtworkFactory.getNew()
                artwork.binaryData = coverBytes
                artwork.mimeType = "image/jpeg"
                artwork.pictureType = 3 // Cover (front)
                tag.setField(artwork)
            } catch (e: Exception) {
                Log.w(TAG, "Cover art embed failed (non-fatal): ${e.message}")
            }
        }
    }

    private fun updateMediaStore(filePath: String, tags: Map<String, Any?>) {
        val ctx = context ?: return
        val values = ContentValues().apply {
            tags["title"]?.toString()?.let { put(MediaStore.Audio.Media.TITLE, it) }
            tags["artist"]?.toString()?.let { put(MediaStore.Audio.Media.ARTIST, it) }
            tags["album"]?.toString()?.let { put(MediaStore.Audio.Media.ALBUM, it) }
            tags["composer"]?.toString()?.let { put(MediaStore.Audio.Media.COMPOSER, it) }
            tags["trackNumber"]?.let {
                val num = it.toString().toIntOrNull()
                if (num != null) put(MediaStore.Audio.Media.TRACK, num)
            }
        }

        try {
            // Prefer updating via content URI (works on all Android versions)
            val contentUri = findContentUri(ctx, filePath)
            if (contentUri != null) {
                ctx.contentResolver.update(contentUri, values, null, null)
            } else {
                // Fallback: update by file path (legacy)
                val uri = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
                val selection = "${MediaStore.Audio.Media.DATA} = ?"
                ctx.contentResolver.update(uri, values, selection, arrayOf(filePath))
            }
        } catch (e: Exception) {
            Log.w(TAG, "MediaStore update failed (non-fatal): ${e.message}")
        }
    }

    private fun triggerMediaScan(filePath: String) {
        val ctx = context ?: return
        try {
            MediaScannerConnection.scanFile(ctx, arrayOf(filePath), null, null)
        } catch (e: Exception) {
            Log.w(TAG, "MediaScanner trigger failed (non-fatal): ${e.message}")
        }
    }

    // ════════════════════════════════════════════════════════════
    // DELETE SONG
    // ════════════════════════════════════════════════════════════

    private fun deleteSong(filePath: String, songId: Int?, result: MethodChannel.Result) {
        val ctx = context ?: run {
            result.error("NO_CONTEXT", "Context unavailable", null)
            return
        }

        try {
            val uri = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
            val selection = "${MediaStore.Audio.Media.DATA} = ?"

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val contentUri = findContentUri(ctx, filePath)
                if (contentUri != null) {
                    deleteWithRequest(contentUri, result)
                } else {
                    val deleted = ctx.contentResolver.delete(uri, selection, arrayOf(filePath))
                    val file = File(filePath)
                    if (file.exists()) file.delete()
                    result.success(deleted > 0 || !File(filePath).exists())
                }
            } else {
                val deleted = ctx.contentResolver.delete(uri, selection, arrayOf(filePath))
                val file = File(filePath)
                if (file.exists()) file.delete()
                result.success(deleted > 0 || !file.exists())
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error deleting $filePath", e)
            result.error("DELETE_ERROR", e.message ?: "Failed to delete", null)
        }
    }

    @RequiresApi(Build.VERSION_CODES.R)
    private fun deleteWithRequest(contentUri: Uri, result: MethodChannel.Result) {
        val act = activity
        if (act == null) {
            result.error("NO_ACTIVITY", "Activity unavailable", null)
            return
        }
        try {
            val deleteRequest = MediaStore.createDeleteRequest(
                act.contentResolver,
                listOf(contentUri)
            )
            pendingResult = result
            pendingWriteFilePath = null
            pendingWriteTags = null
            pendingContentUri = null
            act.startIntentSenderForResult(
                deleteRequest.intentSender,
                REQUEST_DELETE, null, 0, 0, 0
            )
        } catch (e: Exception) {
            result.error("DELETE_ERROR", e.message, null)
        }
    }

    // ════════════════════════════════════════════════════════════
    // SHARED HELPERS
    // ════════════════════════════════════════════════════════════

    private fun findContentUri(ctx: Context, filePath: String): Uri? {
        val uri = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        val projection = arrayOf(MediaStore.Audio.Media._ID)
        val selection = "${MediaStore.Audio.Media.DATA} = ?"
        ctx.contentResolver.query(uri, projection, selection, arrayOf(filePath), null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val id = cursor.getLong(0)
                return Uri.withAppendedPath(uri, id.toString())
            }
        }
        return null
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: android.content.Intent?): Boolean {
        when (requestCode) {
            REQUEST_WRITE -> {
                if (resultCode == Activity.RESULT_OK) {
                    val fp = pendingWriteFilePath
                    val tags = pendingWriteTags
                    val cover = pendingWriteCover
                    val res = pendingResult
                    val contentUri = pendingContentUri
                    // Clear pending state before async work
                    pendingWriteFilePath = null
                    pendingWriteTags = null
                    pendingWriteCover = null
                    pendingResult = null
                    pendingContentUri = null

                    if (fp != null && tags != null && res != null) {
                        if (contentUri != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                            // Android 11+: must write via ContentResolver
                            doWriteTagsViaContentResolver(contentUri, fp, tags, cover, res)
                        } else {
                            doWriteTags(fp, tags, cover, res)
                        }
                    }
                } else {
                    pendingResult?.success(false)
                    pendingResult = null
                    pendingWriteFilePath = null
                    pendingWriteTags = null
                    pendingWriteCover = null
                    pendingContentUri = null
                }
                return true
            }
            REQUEST_DELETE -> {
                pendingResult?.success(resultCode == Activity.RESULT_OK)
                pendingResult = null
                return true
            }
        }
        return false
    }
}
