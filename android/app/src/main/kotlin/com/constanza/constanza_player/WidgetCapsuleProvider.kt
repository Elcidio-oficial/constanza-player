package com.constanza.constanza_player

import android.appwidget.AppWidgetManager
import android.content.Context
import android.graphics.Bitmap
import android.widget.RemoteViews

/** Widget Cápsula — formato pílula com artwork circular, título, pause e next. */
class WidgetCapsuleProvider : BaseWidgetProvider() {
    override val layoutRes get() = R.layout.widget_capsule
    override val providerClass get() = WidgetCapsuleProvider::class.java
    // Capsule é pílula → artwork circular para acompanhar a curvatura.
    override val artworkRadiusFraction: Float = 0.5f

    override fun bindViews(
        context: Context,
        mgr: AppWidgetManager,
        widgetId: Int,
        title: String,
        artist: String,
        isPlaying: Boolean,
        artwork: Bitmap?,
        playPauseRes: Int,
        isFavorite: Boolean,
        repeatMode: Int,
    ) {
        val views = RemoteViews(context.packageName, layoutRes)

        views.setTextViewText(R.id.widget_title, title)
        views.setImageViewResource(R.id.widget_play_pause, playPauseRes)
        if (artwork != null) views.setImageViewBitmap(R.id.widget_artwork, artwork)

        views.setOnClickPendingIntent(R.id.widget_play_pause, pendingIntent(context, WidgetConstants.ACTION_PLAY_PAUSE, 40))
        views.setOnClickPendingIntent(R.id.widget_next,       pendingIntent(context, WidgetConstants.ACTION_NEXT, 41))
        launchPendingIntent(context)?.let { views.setOnClickPendingIntent(R.id.widget_root, it) }

        mgr.updateAppWidget(widgetId, views)
    }

    companion object {
        fun updateAllWidgets(context: Context) =
            BaseWidgetProvider.updateAllWidgets(context, WidgetCapsuleProvider::class.java)
    }
}
