package com.constanza.constanza_player

import android.appwidget.AppWidgetManager
import android.content.Context
import android.graphics.Bitmap
import android.widget.RemoteViews

/** Widget Recomendação — artwork de fundo + overlay escuro + "Daily Recommendation". */
class WidgetRecommendationProvider : BaseWidgetProvider() {
    override val layoutRes get() = R.layout.widget_recommendation
    override val providerClass get() = WidgetRecommendationProvider::class.java

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

        views.setOnClickPendingIntent(R.id.widget_play_pause, pendingIntent(context, WidgetConstants.ACTION_PLAY_PAUSE, 50))
        launchPendingIntent(context)?.let { views.setOnClickPendingIntent(R.id.widget_root, it) }

        mgr.updateAppWidget(widgetId, views)
    }

    companion object {
        fun updateAllWidgets(context: Context) =
            BaseWidgetProvider.updateAllWidgets(context, WidgetRecommendationProvider::class.java)
    }
}
