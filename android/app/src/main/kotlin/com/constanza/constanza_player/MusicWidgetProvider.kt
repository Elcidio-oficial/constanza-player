package com.constanza.constanza_player

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.widget.RemoteViews

class MusicWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val PREFS = "widget_prefs"
        private const val KEY_TITLE = "widget_title"
        private const val KEY_ARTIST = "widget_artist"
        private const val KEY_IS_PLAYING = "widget_is_playing"
        private const val KEY_ARTWORK_PATH = "widget_artwork_path"

        const val ACTION_PREV = "com.constanza.constanza_player.WIDGET_PREV"
        const val ACTION_PLAY_PAUSE = "com.constanza.constanza_player.WIDGET_PLAY_PAUSE"
        const val ACTION_NEXT = "com.constanza.constanza_player.WIDGET_NEXT"

        fun updateAllWidgets(context: Context) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(ComponentName(context, MusicWidgetProvider::class.java))
            if (ids.isNotEmpty()) {
                val intent = Intent(context, MusicWidgetProvider::class.java).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                }
                context.sendBroadcast(intent)
            }
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (id in appWidgetIds) {
            updateWidget(context, appWidgetManager, id)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            ACTION_PREV, ACTION_PLAY_PAUSE, ACTION_NEXT -> {
                // Forward media commands via broadcast that audio_service picks up
                val mediaIntent = Intent().apply {
                    action = when (intent.action) {
                        ACTION_PREV -> "com.constanza.constanza_player.MEDIA_PREV"
                        ACTION_PLAY_PAUSE -> "com.constanza.constanza_player.MEDIA_PLAY_PAUSE"
                        ACTION_NEXT -> "com.constanza.constanza_player.MEDIA_NEXT"
                        else -> return
                    }
                    setPackage(context.packageName)
                }
                context.sendBroadcast(mediaIntent)

                // Also open the app
                val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                if (launchIntent != null) {
                    launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(launchIntent)
                }
            }
        }
    }

    private fun updateWidget(context: Context, mgr: AppWidgetManager, widgetId: Int) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val title = prefs.getString(KEY_TITLE, "Constanza Músicas") ?: "Constanza Músicas"
        val artist = prefs.getString(KEY_ARTIST, "Sua música. Seu momento.") ?: ""
        val isPlaying = prefs.getBoolean(KEY_IS_PLAYING, false)
        val artworkPath = prefs.getString(KEY_ARTWORK_PATH, null)

        val views = RemoteViews(context.packageName, R.layout.music_widget)

        views.setTextViewText(R.id.widget_title, title)
        views.setTextViewText(R.id.widget_artist, artist)

        // Play/pause icon
        val playPauseRes = if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play
        views.setImageViewResource(R.id.widget_play_pause, playPauseRes)

        // Artwork
        if (artworkPath != null) {
            try {
                val bmp = BitmapFactory.decodeFile(artworkPath)
                if (bmp != null) {
                    views.setImageViewBitmap(R.id.widget_artwork, bmp)
                }
            } catch (_: Exception) {}
        }

        // Click intents
        views.setOnClickPendingIntent(R.id.widget_prev, makePendingIntent(context, ACTION_PREV, 1))
        views.setOnClickPendingIntent(R.id.widget_play_pause, makePendingIntent(context, ACTION_PLAY_PAUSE, 2))
        views.setOnClickPendingIntent(R.id.widget_next, makePendingIntent(context, ACTION_NEXT, 3))

        // Tap anywhere else opens app
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        if (launchIntent != null) {
            val pi = PendingIntent.getActivity(context, 0, launchIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.widget_root, pi)
        }

        mgr.updateAppWidget(widgetId, views)
    }

    private fun makePendingIntent(context: Context, action: String, requestCode: Int): PendingIntent {
        val intent = Intent(context, MusicWidgetProvider::class.java).apply {
            this.action = action
        }
        return PendingIntent.getBroadcast(context, requestCode, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }
}
