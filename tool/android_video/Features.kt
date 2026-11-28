package com.bmusic.app

import android.annotation.SuppressLint
import android.app.Service
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.text.TextUtils
import android.view.Gravity
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.content.FileProvider
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.transformer.Composition
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.EditedMediaItemSequence
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.Transformer
import java.io.File
import kotlin.math.abs

/** FileProvider for files B Music shares (story videos, QR images). */
class ShareFileProvider : FileProvider()

/**
 * Story video: a still 1080x1920 card (cover, title, B Music icon) rendered by
 * Flutter + the chosen 15 s of the song's audio -> H.264/AAC MP4 that Instagram
 * Stories, WhatsApp Status etc. accept as a real video with sound.
 */
@UnstableApi
object StoryVideo {
    private var busy = false

    fun dir(context: Context) = File(context.cacheDir, "share").apply { mkdirs() }

    fun export(context: Context, image: String, audio: String, start: Long, end: Long, done: (String?, String?) -> Unit) {
        val main = Handler(Looper.getMainLooper())
        if (busy) { done(null, "busy"); return }
        if (end <= start) { done(null, "range"); return }
        busy = true
        dir(context).listFiles()?.filter { it.name.startsWith("BMusic_Hikaye_") }?.forEach { it.delete() }
        val out = File(dir(context), "BMusic_Hikaye_${System.currentTimeMillis()}.mp4")
        val duration = end - start
        val source = if (audio.startsWith("content:") || audio.startsWith("file:")) Uri.parse(audio) else Uri.fromFile(File(audio))
        val still = EditedMediaItem.Builder(MediaItem.Builder().setUri(Uri.fromFile(File(image)))
            .setMimeType(MimeTypes.IMAGE_PNG).setImageDurationMs(duration).build())
            .setFrameRate(30).build()
        val sound = EditedMediaItem.Builder(MediaItem.Builder().setUri(source)
            .setClippingConfiguration(MediaItem.ClippingConfiguration.Builder().setStartPositionMs(start).setEndPositionMs(end).build()).build())
            .setRemoveVideo(true).build()
        val composition = Composition.Builder(
            EditedMediaItemSequence.Builder(still).build(),
            EditedMediaItemSequence.Builder(sound).build()).build()
        main.post {
            try {
                Transformer.Builder(context).setVideoMimeType(MimeTypes.VIDEO_H264).setAudioMimeType(MimeTypes.AUDIO_AAC)
                    .addListener(object : Transformer.Listener {
                        override fun onCompleted(composition: Composition, result: ExportResult) {
                            busy = false
                            android.util.Log.i("flutter", "[BMusic feature] story-video=${out.name} ${out.length()}")
                            done(out.absolutePath, null)
                        }
                        override fun onError(composition: Composition, result: ExportResult, exception: ExportException) {
                            out.delete(); busy = false
                            done(null, exception.errorCodeName)
                        }
                    }).build().start(composition, out.absolutePath)
            } catch (e: Exception) { out.delete(); busy = false; done(null, e.message ?: "start") }
        }
    }

    /** Shares [path] with [mime]; [target] "instagram" / "whatsapp" opens that app directly. */
    fun share(context: Context, path: String, mime: String, target: String?, text: String?): Boolean {
        val file = File(path)
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.share", file)
        fun base() = Intent(Intent.ACTION_SEND).setType(mime).putExtra(Intent.EXTRA_STREAM, uri)
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
            .also { i -> i.clipData = ClipData.newRawUri("B Music", uri); if (!text.isNullOrEmpty()) i.putExtra(Intent.EXTRA_TEXT, text) }
        val pkg = when (target) { "instagram" -> "com.instagram.android"; "whatsapp" -> "com.whatsapp"; else -> null }
        if (pkg != null) {
            try { context.startActivity(base().setPackage(pkg)); return true } catch (_: ActivityNotFoundException) { }
            if (pkg == "com.whatsapp") try { context.startActivity(base().setPackage("com.whatsapp.w4b")); return true } catch (_: ActivityNotFoundException) { }
        }
        context.startActivity(Intent.createChooser(base(), "B Music").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        return pkg == null
    }
}

/** Ses yükseltici: LoudnessEnhancer on the music player's audio session (100..200 %). */
object VolumeBoost {
    private var effect: android.media.audiofx.LoudnessEnhancer? = null
    private var session = 0

    fun gainMb(percent: Int): Int = ((percent.coerceIn(100, 200) - 100) * 10)

    fun apply(sessionId: Int, percent: Int): Boolean {
        return try {
            if (percent <= 100 || sessionId == 0) {
                effect?.release(); effect = null; session = 0
                return percent <= 100
            }
            if (effect == null || session != sessionId) {
                effect?.release()
                effect = android.media.audiofx.LoudnessEnhancer(sessionId); session = sessionId
            }
            effect!!.setTargetGain(gainMb(percent)); effect!!.enabled = true
            android.util.Log.i("flutter", "[BMusic feature] boost=$percent gain=${gainMb(percent)}")
            true
        } catch (e: Exception) { effect = null; session = 0; false }
    }
}

/** Mini müzik baloncuğu: floating now-playing bubble over other apps. */
object Bubble {
    var enabled = false
    var title = ""
    var artist = ""
    var art: String? = null
    var playing = false
    var service: BubbleService? = null

    fun canDraw(context: Context) = Build.VERSION.SDK_INT < 23 || Settings.canDrawOverlays(context)

    fun update(context: Context, values: Map<*, *>) {
        (values["enabled"] as? Boolean)?.let { enabled = it; context.getSharedPreferences("bm_bubble", Context.MODE_PRIVATE).edit().putBoolean("enabled", it).apply() }
        (values["title"] as? String)?.let { title = it }
        (values["artist"] as? String)?.let { artist = it }
        if (values.containsKey("art")) art = values["art"] as? String
        (values["playing"] as? Boolean)?.let { playing = it }
        if (!enabled || title.isEmpty()) hide(context) else service?.refresh()
    }

    fun loadEnabled(context: Context) { enabled = context.getSharedPreferences("bm_bubble", Context.MODE_PRIVATE).getBoolean("enabled", false) }

    fun show(context: Context) {
        if (!enabled || title.isEmpty() || !playing || !canDraw(context)) return
        try { context.startService(Intent(context, BubbleService::class.java)) } catch (e: Exception) {
            android.util.Log.w("flutter", "bubble start failed: ${e.message}")
        }
    }

    fun hide(context: Context) { if (service != null) context.stopService(Intent(context, BubbleService::class.java)) }

    fun key(context: Context, code: Int) {
        val audio = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        audio.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, code))
        audio.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_UP, code))
    }
}

class BubbleService : Service() {
    private var root: LinearLayout? = null
    private lateinit var cover: ImageView
    private lateinit var name: TextView
    private lateinit var sub: TextView
    private lateinit var play: ImageView
    private var params: WindowManager.LayoutParams? = null
    private var shownArt: String? = "-"

    override fun onBind(intent: Intent?): IBinder? = null

    private fun dp(v: Int) = (v * resources.displayMetrics.density).toInt()

    @SuppressLint("ClickableViewAccessibility")
    override fun onCreate() {
        super.onCreate()
        Bubble.service = this
        if (!Bubble.canDraw(this)) { stopSelf(); return }
        val wm = getSystemService(WINDOW_SERVICE) as WindowManager
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL
            background = GradientDrawable().apply { cornerRadius = dp(40).toFloat(); setColor(0xF0141018.toInt()); setStroke(dp(1), 0x33FFFFFF) }
            setPadding(dp(4), dp(4), dp(10), dp(4)); elevation = dp(8).toFloat()
        }
        cover = ImageView(this).apply {
            scaleType = ImageView.ScaleType.CENTER_CROP; clipToOutline = true
            background = GradientDrawable().apply { shape = GradientDrawable.OVAL; setColor(0xFF2A211A.toInt()); setStroke(dp(2), Brand.COLOR) }
            outlineProvider = android.view.ViewOutlineProvider.BACKGROUND
            contentDescription = "B Music"
        }
        layout.addView(cover, LinearLayout.LayoutParams(dp(52), dp(52)))
        val texts = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding(dp(10), 0, dp(6), 0) }
        name = TextView(this).apply { setTextColor(Color.WHITE); textSize = 13f; maxLines = 1; ellipsize = TextUtils.TruncateAt.END; paint.isFakeBoldText = true }
        sub = TextView(this).apply { setTextColor(0xB3FFFFFF.toInt()); textSize = 11f; maxLines = 1; ellipsize = TextUtils.TruncateAt.END }
        texts.addView(name); texts.addView(sub)
        layout.addView(texts, LinearLayout.LayoutParams(dp(110), -2))
        play = ImageView(this).apply { setColorFilter(Color.WHITE); setPadding(dp(8), dp(8), dp(8), dp(8)); contentDescription = "Oynat / Duraklat" }
        play.setOnClickListener { Bubble.key(this, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE); Bubble.playing = !Bubble.playing; refresh() }
        layout.addView(play, LinearLayout.LayoutParams(dp(40), dp(40)))
        val next = ImageView(this).apply { setImageResource(android.R.drawable.ic_media_next); setColorFilter(Color.WHITE); setPadding(dp(8), dp(8), dp(8), dp(8)); contentDescription = "Sonraki" }
        next.setOnClickListener { Bubble.key(this, KeyEvent.KEYCODE_MEDIA_NEXT) }
        layout.addView(next, LinearLayout.LayoutParams(dp(40), dp(40)))
        val type = if (Build.VERSION.SDK_INT >= 26) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY else @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE
        val lp = WindowManager.LayoutParams(-2, -2, type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS, PixelFormat.TRANSLUCENT).apply {
            gravity = Gravity.TOP or Gravity.START
            val saved = getSharedPreferences("bm_bubble", MODE_PRIVATE)
            x = saved.getInt("x", dp(12)); y = saved.getInt("y", dp(220))
        }
        // Drag anywhere on the cover; tap opens B Music; long press hides the bubble.
        var downX = 0f; var downY = 0f; var startX = 0; var startY = 0; var moved = false
        val longPress = Runnable { if (!moved) { Bubble.enabled = false; getSharedPreferences("bm_bubble", MODE_PRIVATE).edit().putBoolean("enabled", false).apply(); stopSelf() } }
        cover.setOnTouchListener { v, e ->
            when (e.actionMasked) {
                MotionEvent.ACTION_DOWN -> { downX = e.rawX; downY = e.rawY; startX = lp.x; startY = lp.y; moved = false; v.postDelayed(longPress, 900) }
                MotionEvent.ACTION_MOVE -> {
                    val dx = e.rawX - downX; val dy = e.rawY - downY
                    if (abs(dx) > dp(6) || abs(dy) > dp(6)) { moved = true; v.removeCallbacks(longPress) }
                    if (moved) { lp.x = startX + dx.toInt(); lp.y = startY + dy.toInt(); try { wm.updateViewLayout(layout, lp) } catch (_: Exception) { } }
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    v.removeCallbacks(longPress)
                    if (moved) getSharedPreferences("bm_bubble", MODE_PRIVATE).edit().putInt("x", lp.x).putInt("y", lp.y).apply()
                    else if (e.actionMasked == MotionEvent.ACTION_UP && e.eventTime - e.downTime < 900) {
                        packageManager.getLaunchIntentForPackage(packageName)?.let { startActivity(it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
                    }
                }
            }
            true
        }
        try { wm.addView(layout, lp); root = layout; params = lp } catch (e: Exception) { stopSelf(); return }
        refresh()
        android.util.Log.i("flutter", "[BMusic feature] bubble-shown")
    }

    fun refresh() {
        if (root == null) return
        name.text = Bubble.title
        sub.text = Bubble.artist
        play.setImageResource(if (Bubble.playing) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play)
        if (shownArt != Bubble.art) {
            shownArt = Bubble.art
            val bitmap = try { Bubble.art?.let { BitmapFactory.decodeFile(Uri.parse(it).path ?: it) } } catch (_: Exception) { null }
            if (bitmap != null) cover.setImageBitmap(bitmap) else cover.setImageBitmap(Brand.largeIcon(this))
        }
    }

    override fun onTaskRemoved(rootIntent: Intent?) { stopSelf() }

    override fun onDestroy() {
        root?.let { try { (getSystemService(WINDOW_SERVICE) as WindowManager).removeView(it) } catch (_: Exception) { } }
        root = null
        if (Bubble.service === this) Bubble.service = null
        super.onDestroy()
    }
}

/** Deep links: bmusic://mektup/<id> (şarkı mektubu) and bmusic://liste?d=<data> (QR liste). */
object Links {
    var pending: String? = null
    fun accept(intent: Intent?): Boolean {
        if (intent?.action != Intent.ACTION_VIEW) return false
        val uri = intent.data ?: return false
        val ok = uri.scheme == "bmusic" || (uri.scheme == "https" && uri.host == "bmusic02-app.web.app")
        if (!ok) return false
        pending = uri.toString()
        return true
    }
}
