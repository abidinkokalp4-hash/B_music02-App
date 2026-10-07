package com.bmusic.app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.core.app.NotificationCompat

/**
 * B Music branding for every notification: the white BM silhouette as the
 * (alpha-only) small icon tinted with the app purple, and the full-colour BM
 * logo as the large icon.
 */
object Brand {
    const val COLOR = 0xFFA53CFF.toInt()
    @Volatile private var logo: Bitmap? = null

    fun largeIcon(context: Context): Bitmap? {
        logo?.let { return it }
        return try {
            context.assets.open("flutter_assets/assets/images/b_music02_logo.png").use { stream ->
                val original = BitmapFactory.decodeStream(stream) ?: return null
                val size = (64 * context.resources.displayMetrics.density).toInt().coerceIn(96, 256)
                Bitmap.createScaledBitmap(original, size, size, true).also { if (it !== original) original.recycle(); logo = it }
            }
        } catch (_: Exception) { null }
    }

    fun apply(builder: NotificationCompat.Builder, context: Context): NotificationCompat.Builder =
        builder.setSmallIcon(R.drawable.ic_stat_bm).setColor(COLOR).apply { largeIcon(context)?.let { setLargeIcon(it) } }
}
