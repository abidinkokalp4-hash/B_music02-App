package com.example.b_music02

import android.app.PendingIntent
import android.app.ActivityManager
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.view.KeyEvent
import android.widget.RemoteViews

class MusicWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        update(context, manager, ids)
    }
    companion object {
        fun save(context: Context, values: Map<*, *>) {
            context.getSharedPreferences("b_music02_widget", Context.MODE_PRIVATE).edit()
                .putString("title", values["title"] as? String ?: "Müziğini seç")
                .putString("artist", values["artist"] as? String ?: "B_music02")
                .putString("artPath", values["artPath"] as? String)
                .putBoolean("playing", values["playing"] == true).apply()
            val manager = AppWidgetManager.getInstance(context)
            update(context, manager, manager.getAppWidgetIds(ComponentName(context, MusicWidgetProvider::class.java)))
        }
        private fun mediaIntent(context: Context, code: Int): PendingIntent {
            val intent = Intent(Intent.ACTION_MEDIA_BUTTON)
                .setComponent(ComponentName(context, "com.ryanheise.audioservice.MediaButtonReceiver"))
                .putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_DOWN, code))
            return PendingIntent.getBroadcast(context, code, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }
        private fun artwork(path: String?): Bitmap? {
            if (path.isNullOrEmpty()) return null
            return try {
                val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                BitmapFactory.decodeFile(path, bounds)
                if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
                val options = BitmapFactory.Options().apply {
                    inSampleSize = 1
                    while (bounds.outWidth / inSampleSize > 256 || bounds.outHeight / inSampleSize > 256) inSampleSize *= 2
                }
                BitmapFactory.decodeFile(path, options)
            } catch (_: Exception) { null }
        }
        @Suppress("DEPRECATION")
        private fun update(context: Context, manager: AppWidgetManager, ids: IntArray) {
            if (ids.isEmpty()) return
            val prefs = context.getSharedPreferences("b_music02_widget", Context.MODE_PRIVATE)
            val views = RemoteViews(context.packageName, R.layout.music_widget)
            views.setTextViewText(R.id.widget_title, prefs.getString("title", "Müziğini seç"))
            views.setTextViewText(R.id.widget_artist, prefs.getString("artist", "B_music02"))
            val services = (context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager).getRunningServices(30)
            val playing = prefs.getBoolean("playing", false) && services.any {
                it.service.className == "com.ryanheise.audioservice.AudioService"
            }
            views.setImageViewResource(R.id.widget_play,
                if (playing) R.drawable.audio_service_pause else R.drawable.audio_service_play_arrow)
            views.setContentDescription(R.id.widget_play, if (playing) "Duraklat" else "Oynat")
            val bitmap = artwork(prefs.getString("artPath", null))
            if (bitmap == null) views.setImageViewResource(R.id.widget_art, R.drawable.ic_stat_music)
            else views.setImageViewBitmap(R.id.widget_art, bitmap)
            val open = PendingIntent.getActivity(context, 400,
                Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.widget_art, open)
            views.setOnClickPendingIntent(R.id.widget_title, open)
            views.setOnClickPendingIntent(R.id.widget_artist, open)
            views.setOnClickPendingIntent(R.id.widget_previous, mediaIntent(context, KeyEvent.KEYCODE_MEDIA_PREVIOUS))
            views.setOnClickPendingIntent(R.id.widget_play, mediaIntent(context, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE))
            views.setOnClickPendingIntent(R.id.widget_next, mediaIntent(context, KeyEvent.KEYCODE_MEDIA_NEXT))
            manager.updateAppWidget(ids, views)
            bitmap?.recycle()
        }
    }
}
