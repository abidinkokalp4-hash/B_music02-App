package com.bmusic.app

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.annotation.SuppressLint
import android.annotation.TargetApi
import android.app.Activity
import android.app.AlertDialog
import android.app.PendingIntent
import android.app.PictureInPictureParams
import android.app.RemoteAction
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ActivityInfo
import android.content.res.ColorStateList
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.Icon
import android.graphics.drawable.RippleDrawable
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.MediaStore
import android.text.TextUtils
import android.util.Rational
import android.view.GestureDetector
import android.view.Gravity
import android.view.MotionEvent
import android.view.ScaleGestureDetector
import android.view.View
import android.view.ViewConfiguration
import android.view.ViewGroup
import android.view.WindowInsets
import android.view.WindowManager
import android.view.accessibility.AccessibilityNodeInfo
import android.view.animation.DecelerateInterpolator
import android.widget.*
import androidx.core.content.ContextCompat
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.MimeTypes
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.session.MediaController
import androidx.media3.session.SessionToken
import androidx.media3.transformer.*
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.ui.PlayerView
import com.google.common.util.concurrent.ListenableFuture
import java.io.File
import java.util.concurrent.Executors
import kotlin.math.abs
import kotlin.math.hypot

/**
 * Local video player (Media3 through VideoPlaybackService).
 *
 * Screen: top bar (back, title, ⋮), bottom seek bar with a thumbnail preview
 * bubble while dragging, one transport row (repeat, −10 s, play/pause, +10 s,
 * rotate). Everything else lives in the ⋮ bottom sheet. Single tap shows/hides
 * the controls, double tap toggles favourite. Swipe gestures (seek,
 * brightness, volume) only work in landscape; in portrait a vertical swipe
 * pages through the list Reels-style.
 */
@UnstableApi
class VideoActivity : Activity() {
    companion object {
        var active: VideoActivity? = null
            private set
        private const val PURPLE = 0xFFBC62FF.toInt()
        private const val ICON_TINT = 0xFFCDA4FF.toInt()
        private const val DANGER = 0xFFFF5C6C.toInt()
        private const val SHEET_BG = 0xFF14111B.toInt()
        private const val DOUBLE_TAP_MS = 240L
    }
    private lateinit var root: FrameLayout
    private lateinit var stage: FrameLayout
    private lateinit var display: PlayerView
    private lateinit var poster: ImageView
    private lateinit var panel: LinearLayout
    private lateinit var heading: LinearLayout
    private lateinit var feedback: TextView
    private lateinit var heart: ImageView
    private lateinit var bubble: LinearLayout
    private lateinit var preview: ImageView
    private lateinit var previewTime: TextView
    private lateinit var timeline: SeekBar
    private lateinit var clock: TextView
    private lateinit var play: ImageButton
    private lateinit var repeatButton: ImageButton
    private lateinit var brightnessSlider: VerticalSlider
    private lateinit var volumeSlider: VerticalSlider
    private lateinit var titleView: TextView
    private lateinit var speedBadge: TextView
    private lateinit var unlock: ImageButton
    private var sheet: FrameLayout? = null
    private var sheetPanel: View? = null
    private var playIcon = 0
    private var sleepDeadline = 0L
    private var sleepMinutes = 0
    private val pipControl = "com.bmusic.app.PIP_CONTROL"
    private val pipReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.getIntExtra("control", 0)) { 1 -> seek(-10000); 2 -> togglePlay(); 3 -> seek(10000) }
            updatePip()
        }
    }
    private var controller: MediaController? = null
    private var future: ListenableFuture<MediaController>? = null
    private val handler = Handler(Looper.getMainLooper())
    private val frames = Executors.newSingleThreadExecutor()
    private val posterWorker = Executors.newSingleThreadExecutor()
    private var source = ""
    private var title = "Video"
    private var dragging = false
    private var listenInBackground = false
    private var speech = false
    private var hold = false
    private var previousSpeed = 1f
    private var startX = 0f
    private var startY = 0f
    private var startPosition = 0L
    private var gestureMode = 0
    private var startVolume = 1f
    private var startBrightness = .5f
    private var targetPosition = 0L
    private var visible = true
    private var clipStart = 0L
    private var clipEnd = 0L
    private var clipPreviewEnd: Long? = null
    private var transformer: Transformer? = null
    private var exportDialog: AlertDialog? = null
    private var output: File? = null
    private var previewGeneration = 0
    private var frameBusy = false
    private var pendingFramePosition: Long? = null
    private var retriever: MediaMetadataRetriever? = null
    private var retrieverSource = ""
    private var reportedProgress = false
    private var lastCheckpoint = -1L
    private var isClosing = false
    private var replacing = false
    private var locked = false
    private var zoom = 1f
    private var cover = false
    private var favorite = false
    private var pendingTap: Runnable? = null
    private var lastTapUp = 0L
    private var lastTapX = 0f
    private var lastTapY = 0f
    // Reels: the list the video was opened from (vertical swipe = previous/next).
    private var ids = arrayListOf<String>()
    private var titles = arrayListOf<String>()
    private var index = 0
    private var favorites = BooleanArray(1)
    private var positions = LongArray(1)
    private var durations = LongArray(1)
    private var visited = BooleanArray(1)
    private val posters = HashMap<Int, Bitmap>()
    private var edited = false
    private var paging = false
    private val reels get() = ids.size > 1
    private val artwork by lazy { try { assets.open("flutter_assets/assets/images/b_music02_logo.png").use { it.readBytes() } } catch (_: Exception) { null } }
    private var pendingEdit: (() -> Unit)? = null
    private var gifBusy = false
    private val landscape get() = resources.configuration.orientation == Configuration.ORIENTATION_LANDSCAPE
    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()
    private fun rounded(radius: Float, color: Int, stroke: Int = 0) = GradientDrawable().apply {
        setColor(color); cornerRadius = dp(radius.toInt()).toFloat(); if (stroke != 0) setStroke(dp(1), stroke)
    }
    private fun dialog() = AlertDialog.Builder(this, android.R.style.Theme_DeviceDefault_Dialog_Alert)
    private fun rotate() { requestedOrientation = if (landscape) ActivityInfo.SCREEN_ORIENTATION_PORTRAIT else ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE }
    private fun rateLabel(rate: Float) = "%.2f".format(java.util.Locale.US, rate).trimEnd('0').let { if (it.endsWith(".")) it + "0" else it } + "×"
    private fun currentRate() = controller?.playbackParameters?.speed ?: 1f
    private fun togglePlay() { controller?.let { if (it.isPlaying) it.pause() else { if (it.playbackState == Player.STATE_ENDED) it.seekTo(0); it.play() } } }
    private fun repeatOn() = controller?.repeatMode == Player.REPEAT_MODE_ONE
    private fun updateRepeat() { if (::repeatButton.isInitialized) { repeatButton.imageTintList = ColorStateList.valueOf(if (repeatOn()) PURPLE else Color.WHITE); repeatButton.contentDescription = if (repeatOn()) "Tekrar oynat: açık" else "Tekrar oynat" } }
    private fun toggleRepeat() {
        controller?.let { it.repeatMode = if (it.repeatMode == Player.REPEAT_MODE_ONE) Player.REPEAT_MODE_OFF else Player.REPEAT_MODE_ONE }
        updateRepeat(); message(if (repeatOn()) "Tekrar oynatma açık" else "Tekrar oynatma kapalı")
    }

    /** Double tap: favourite on/off with a heart pop at the tap position. */
    private fun toggleFavorite(x: Float = root.width / 2f, y: Float = root.height / 2f) {
        favorite = !favorite; favorites[index] = favorite
        android.util.Log.i("flutter", "[BMusic feature] favorite=$favorite")
        heart.setImageResource(if (favorite) R.drawable.bm_favorite else R.drawable.bm_favorite_border)
        heart.imageTintList = ColorStateList.valueOf(if (favorite) 0xFFFF5FA8.toInt() else Color.WHITE)
        val size = dp(96)
        heart.translationX = (x - size / 2f).coerceIn(0f, (root.width - size).toFloat().coerceAtLeast(0f))
        heart.translationY = (y - size / 2f).coerceIn(0f, (root.height - size).toFloat().coerceAtLeast(0f))
        heart.animate().cancel(); heart.visibility = View.VISIBLE; heart.alpha = 0f; heart.scaleX = .4f; heart.scaleY = .4f
        heart.animate().alpha(1f).scaleX(1.15f).scaleY(1.15f).setDuration(160).setInterpolator(DecelerateInterpolator()).withEndAction {
            heart.animate().scaleX(1f).scaleY(1f).setDuration(90).withEndAction {
                heart.animate().alpha(0f).translationYBy(-dp(30).toFloat()).setStartDelay(260).setDuration(260).withEndAction { heart.visibility = View.GONE; heart.animate().setStartDelay(0) }.start()
            }.start()
        }.start()
        message(if (favorite) "Favorilere eklendi" else "Favorilerden çıkarıldı")
    }
    private fun setSleep(minutes: Int) {
        sleepMinutes = minutes
        sleepDeadline = if (minutes > 0) SystemClock.elapsedRealtime() + minutes * 60_000L else 0L
        android.util.Log.i("flutter", "[BMusic feature] sleep=$minutes")
        message(if (minutes > 0) "Video $minutes dakika sonra duraklatılacak" else "Uyku zamanlayıcısı kapatıldı")
    }
    private fun sleepLabel(): String {
        if (sleepDeadline <= 0) return "Kapalı"
        val left = ((sleepDeadline - SystemClock.elapsedRealtime()) / 60000 + 1).coerceAtLeast(1)
        return "$left dk"
    }

    private val ticker = object : Runnable {
        override fun run() {
            val p = controller
            if (p != null) {
                val duration = p.duration.coerceAtLeast(0)
                if (p.isPlaying && p.currentPosition > 1000 && !reportedProgress) {
                    reportedProgress = true
                    android.util.Log.i("flutter", "[B_music02 video] advancing position=${p.currentPosition}ms")
                }
                if (p.isPlaying && poster.visibility == View.VISIBLE && p.currentPosition > 200) hidePoster()
                if (!dragging) timeline.progress = if (duration > 0) (p.currentPosition * 10000 / duration).toInt() else 0
                val label = "${time(p.currentPosition)} / ${time(duration)}"
                if (!dragging && clock.text.toString() != label) clock.text = label
                val icon = if (p.isPlaying) R.drawable.bm_pause else R.drawable.bm_play_arrow
                if (playIcon != icon) { playIcon = icon; play.setImageResource(icon) }
                if (sleepDeadline > 0 && SystemClock.elapsedRealtime() >= sleepDeadline) {
                    sleepDeadline = 0; p.pause(); updatePip()
                    android.util.Log.i("flutter", "[BMusic feature] sleep-paused")
                    message("Uyku zamanlayıcısı: video duraklatıldı")
                }
                val description = if (p.isPlaying) "Duraklat" else "Oynat"
                if (play.contentDescription != description) play.contentDescription = description
                if (source.isNotEmpty() && abs(p.currentPosition / 1000 - lastCheckpoint) >= 5) {
                    lastCheckpoint = p.currentPosition / 1000
                    getSharedPreferences("video_positions", MODE_PRIVATE).edit().putLong(source, p.currentPosition).apply()
                }
                clipPreviewEnd?.let { if (p.currentPosition >= it) { p.pause(); clipPreviewEnd = null; clipDialog(false) } }
            }
            handler.postDelayed(this, 250)
        }
    }
    private val hide = Runnable { if (controller?.isPlaying == true && !dragging && transformer == null && sheet == null) controls(false) }
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        active = this
        source = intent.getStringExtra("path") ?: ""
        title = intent.getStringExtra("title") ?: "Video"
        favorite = intent.getBooleanExtra("favorite", false)
        val listIds = intent.getStringArrayListExtra("ids")
        if (listIds != null && listIds.size > 1) {
            ids = listIds
            titles = intent.getStringArrayListExtra("titles") ?: arrayListOf()
            index = intent.getIntExtra("index", 0).coerceIn(0, ids.size - 1)
            favorites = intent.getBooleanArrayExtra("favorites")?.takeIf { it.size == ids.size } ?: BooleanArray(ids.size)
            positions = intent.getLongArrayExtra("positions")?.takeIf { it.size == ids.size } ?: LongArray(ids.size)
            favorites[index] = favorite
        } else { favorites = booleanArrayOf(favorite); positions = longArrayOf(intent.getLongExtra("position", 0)) }
        durations = LongArray(favorites.size); visited = BooleanArray(favorites.size).also { it[index] = true }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        darkSystemBars()
        buildUi()
        applySystemBars()
        ContextCompat.registerReceiver(this, pipReceiver, IntentFilter(pipControl), ContextCompat.RECEIVER_NOT_EXPORTED)
        val token = SessionToken(this, ComponentName(this, VideoPlaybackService::class.java))
        future = MediaController.Builder(this, token).buildAsync()
        future!!.addListener({
            if (isFinishing || isDestroyed) return@addListener
            try {
                val p = future!!.get(); controller = p; display.player = p
                p.addListener(object : Player.Listener {
                    override fun onPlayerError(error: PlaybackException) {
                        android.util.Log.w("flutter", "[BMusic feature] native-error=${error.errorCodeName}")
                        if (source.isNotEmpty() && intent.getStringExtra("path") != null) {
                            // The Flutter side reopens this video in the libmpv (FFmpeg,
                            // software decoding) player instead of showing an error.
                            setResult(RESULT_OK, resultIntent(p).putExtra("fallback", true))
                            isClosing = true; p.pause(); p.stop(); finish()
                        } else { controls(true); message("Video oynatılamadı: ${error.errorCodeName}") }
                    }
                    override fun onIsPlayingChanged(isPlaying: Boolean) { android.util.Log.i("flutter", "[BMusic feature] native-playing=$isPlaying"); updatePip(); if (!isPlaying && !isInPictureInPictureMode) controls(true) }
                    override fun onRenderedFirstFrame() { hidePoster() }
                    override fun onRepeatModeChanged(repeatMode: Int) { updateRepeat() }
                })
                if (source.isNotEmpty()) {
                    p.setMediaItem(mediaItem(source, title),
                        maxOf(intent.getLongExtra("position", 0),
                            getSharedPreferences("video_positions", MODE_PRIVATE).getLong(source, 0)))
                    p.prepare(); p.play()
                } else {
                    source = p.currentMediaItem?.localConfiguration?.uri?.path ?: ""
                    title = p.mediaMetadata.title?.toString() ?: "Video"
                    titleView.text = title
                }
                updateRepeat()
                handler.post(ticker); scheduleHide()
                preloadNeighbours()
            } catch (e: Exception) { message("Oynatıcı açılamadı: ${e.message}") }
        }, { command -> handler.post(command) })
    }
    private fun mediaItem(path: String, name: String): MediaItem = MediaItem.Builder().setUri(Uri.fromFile(File(path)))
        .setMediaMetadata(MediaMetadata.Builder().setTitle(name).setArtist("B Music").apply { artwork?.let { setArtworkData(it, MediaMetadata.PICTURE_TYPE_FRONT_COVER) } }.build()).build()
    /** File path of a MediaStore video id (reels items are passed by id to keep the intent small). */
    private fun pathFor(id: String): String? = try {
        contentResolver.query(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, arrayOf(MediaStore.MediaColumns.DATA), "${MediaStore.MediaColumns._ID}=?", arrayOf(id), null)
            ?.use { if (it.moveToFirst()) it.getString(0) else null }
    } catch (_: Exception) { null }
    private fun rememberCurrent(p: Player) {
        val position = if (p.duration > 0 && p.duration - p.currentPosition <= 3000) 0 else p.currentPosition
        positions[index] = position; durations[index] = p.duration.coerceAtLeast(0); favorites[index] = favorite
        if (source.isNotEmpty()) getSharedPreferences("video_positions", MODE_PRIVATE).edit().putLong(source, position).apply()
    }
    private fun resultIntent(p: Player?): Intent {
        p?.let { positions[index] = it.currentPosition; durations[index] = it.duration.coerceAtLeast(0) }
        favorites[index] = favorite
        val data = Intent().putExtra("position", p?.currentPosition ?: 0).putExtra("duration", p?.duration?.coerceAtLeast(0) ?: 0)
            .putExtra("favorite", favorite).putExtra("index", index).putExtra("edited", edited)
        if (reels) data.putExtra("visited", visited).putExtra("favorites", favorites).putExtra("positions", positions).putExtra("durations", durations)
        return data
    }
    private fun startPosition(path: String, i: Int) = maxOf(positions.getOrElse(i) { 0L }, getSharedPreferences("video_positions", MODE_PRIVATE).getLong(path, 0))
    /** Reels: open the previous/next video of the list in the same player. */
    private fun switchTo(target: Int): Boolean {
        val p = controller ?: return false
        if (target !in ids.indices) return false
        val path = pathFor(ids[target]) ?: run { message("Video bulunamadı"); return false }
        rememberCurrent(p)
        index = target; source = path; title = titles.getOrElse(target) { "Video" }; favorite = favorites[target]; visited[target] = true
        titleView.text = title
        reportedProgress = false; lastCheckpoint = -1; clipPreviewEnd = null
        zoom = 1f; display.scaleX = 1f; display.scaleY = 1f
        posters[target]?.let { poster.setImageBitmap(it); poster.visibility = View.VISIBLE; handler.removeCallbacks(hidePosterLater); handler.postDelayed(hidePosterLater, 1500) }
        closeRetriever()
        p.setMediaItem(mediaItem(source, title), startPosition(source, target)); p.prepare(); p.play()
        android.util.Log.i("flutter", "[BMusic feature] reels-index=$target")
        preloadNeighbours()
        return true
    }
    private val hidePosterLater = Runnable { hidePoster() }
    private fun hidePoster() { if (poster.visibility == View.VISIBLE) poster.animate().alpha(0f).setDuration(120).withEndAction { poster.visibility = View.GONE; poster.alpha = 1f; poster.setImageDrawable(null) }.start() }
    /** Decode the first frame of the previous/next video so a swipe shows it at once. */
    private fun preloadNeighbours() {
        if (!reels) return
        val wanted = listOf(index - 1, index + 1).filter { it in ids.indices }
        posters.keys.filter { it !in wanted && it != index }.forEach { posters.remove(it) }
        for (i in wanted) {
            if (posters.containsKey(i)) continue
            val id = ids[i]
            posterWorker.execute {
                val path = pathFor(id) ?: return@execute
                val at = startPosition(path, i)
                val bitmap = try {
                    MediaMetadataRetriever().let { r ->
                        try { r.setDataSource(path); if (Build.VERSION.SDK_INT >= 27) r.getScaledFrameAtTime(at * 1000, MediaMetadataRetriever.OPTION_CLOSEST_SYNC, 640, 640) else r.getFrameAtTime(at * 1000, MediaMetadataRetriever.OPTION_CLOSEST_SYNC) }
                        finally { r.release() }
                    }
                } catch (_: Exception) { null }
                if (bitmap != null) handler.post { if (!isDestroyed) posters[i] = bitmap }
            }
        }
    }
    private fun finishPage(dy: Float, fast: Boolean) {
        val height = root.height.toFloat().coerceAtLeast(1f)
        val direction = if (dy < 0) 1 else -1
        val target = index + direction
        if ((abs(dy) > height * .18f || fast) && target in ids.indices) {
            paging = true
            stage.animate().translationY(-direction * height).setDuration(140).withEndAction {
                if (switchTo(target)) stage.translationY = direction * height
                stage.animate().translationY(0f).setDuration(200).withEndAction { paging = false }.start()
            }.start()
        } else {
            if (abs(dy) > height * .18f) message(if (direction > 0) "Listenin sonu" else "Listenin başı")
            stage.animate().translationY(0f).setDuration(160).start()
        }
    }
    /** Brightness/volume bars only appear while the gesture runs, then fade. */
    private fun showLevel(slider: VerticalSlider, level: Float) {
        slider.value = level; slider.animate().cancel(); slider.alpha = 1f; slider.visibility = View.VISIBLE
        handler.removeCallbacks(fadeLevels); handler.postDelayed(fadeLevels, 900)
    }
    private val fadeLevels = Runnable {
        for (slider in listOf(brightnessSlider, volumeSlider)) slider.animate().alpha(0f).setDuration(350).withEndAction { slider.visibility = View.GONE }.start()
    }
    private fun ripple(): android.graphics.drawable.Drawable? {
        val attrs = obtainStyledAttributes(intArrayOf(android.R.attr.selectableItemBackgroundBorderless))
        return try { attrs.getDrawable(0) } finally { attrs.recycle() }
    }
    private fun icon(res: Int, description: String, action: () -> Unit): ImageButton = ImageButton(this).apply {
        setImageResource(res); imageTintList = ColorStateList.valueOf(Color.WHITE); scaleType = ImageView.ScaleType.CENTER
        background = ripple(); contentDescription = description; minimumWidth = dp(48); minimumHeight = dp(48)
        setOnClickListener { action(); scheduleHide() }
    }
    private fun gradient(top: Boolean) = GradientDrawable(if (top) GradientDrawable.Orientation.TOP_BOTTOM else GradientDrawable.Orientation.BOTTOM_TOP,
        intArrayOf(0xD9000000.toInt(), 0x80000000.toInt(), 0x00000000))
    @SuppressLint("ClickableViewAccessibility")
    private fun buildUi() {
        root = FrameLayout(this).apply { setBackgroundColor(Color.BLACK) }
        stage = FrameLayout(this)
        display = PlayerView(this).apply { useController = false; setShowBuffering(PlayerView.SHOW_BUFFERING_WHEN_PLAYING); setShutterBackgroundColor(Color.BLACK) }
        stage.addView(display, FrameLayout.LayoutParams(-1, -1))
        poster = ImageView(this).apply { scaleType = ImageView.ScaleType.FIT_CENTER; visibility = View.GONE; setBackgroundColor(Color.BLACK) }
        stage.addView(poster, FrameLayout.LayoutParams(-1, -1))
        root.addView(stage, FrameLayout.LayoutParams(-1, -1))
        val gestures = View(this).apply { isClickable = true; elevation = dp(2).toFloat() }
        root.addView(gestures, FrameLayout.LayoutParams(-1, -1))

        heading = LinearLayout(this).apply { elevation = dp(4).toFloat(); gravity = Gravity.CENTER_VERTICAL; background = gradient(true); setPadding(dp(4), dp(6), dp(4), dp(22)) }
        heading.addView(icon(R.drawable.bm_arrow_back, "Geri") { finishPlayer() })
        titleView = TextView(this).apply {
            text = title; setTextColor(Color.WHITE); textSize = 15f; maxLines = 1; ellipsize = TextUtils.TruncateAt.END
            gravity = Gravity.CENTER_VERTICAL; typeface = android.graphics.Typeface.DEFAULT_BOLD; setPadding(dp(4), 0, dp(4), 0)
        }
        heading.addView(titleView, LinearLayout.LayoutParams(0, dp(48), 1f))
        heading.addView(icon(R.drawable.bm_more_vert, "Video araçları") { showTools() })
        root.addView(heading, FrameLayout.LayoutParams(-1, -2, Gravity.TOP))

        panel = LinearLayout(this).apply { elevation = dp(4).toFloat(); orientation = LinearLayout.VERTICAL; background = gradient(false); setPadding(dp(10), dp(30), dp(10), dp(10)) }
        timeline = SeekBar(this).apply {
            max = 10000; contentDescription = "Video süresi"; splitTrack = false
            progressTintList = ColorStateList.valueOf(PURPLE); thumbTintList = ColorStateList.valueOf(PURPLE)
            progressBackgroundTintList = ColorStateList.valueOf(0x66FFFFFF)
        }
        panel.addView(timeline, LinearLayout.LayoutParams(-1, dp(32)))
        clock = TextView(this).apply { setTextColor(0xE6FFFFFF.toInt()); textSize = 12f; text = "0:00 / 0:00"; setPadding(dp(16), 0, dp(16), 0) }
        panel.addView(clock, LinearLayout.LayoutParams(-1, dp(20)))
        val row = LinearLayout(this).apply { gravity = Gravity.CENTER }
        repeatButton = icon(R.drawable.bm_repeat, "Tekrar oynat") { toggleRepeat() }
        play = icon(R.drawable.bm_play_arrow, "Oynat") { togglePlay(); controls(true) }.apply {
            background = RippleDrawable(ColorStateList.valueOf(0x55FFFFFF), GradientDrawable().apply { shape = GradientDrawable.OVAL; setColor(0x33BC62FF); setStroke(dp(2), PURPLE) }, null)
            scaleType = ImageView.ScaleType.FIT_CENTER; setPadding(dp(14), dp(14), dp(14), dp(14))
        }
        playIcon = R.drawable.bm_play_arrow
        val cells = listOf(repeatButton, icon(R.drawable.bm_replay_10, "10 saniye geri") { seek(-10000) }, play,
            icon(R.drawable.bm_forward_10, "10 saniye ileri") { seek(10000) }, icon(R.drawable.bm_screen_rotation, "Yatay / dikey döndür") { rotate() })
        for (view in cells) {
            val cell = FrameLayout(this)
            val size = if (view === play) dp(62) else dp(52)
            cell.addView(view, FrameLayout.LayoutParams(size, size, Gravity.CENTER))
            row.addView(cell, LinearLayout.LayoutParams(0, dp(64), 1f))
        }
        panel.addView(row, LinearLayout.LayoutParams(-1, dp(64)))
        root.addView(panel, FrameLayout.LayoutParams(-1, -2, Gravity.BOTTOM))

        brightnessSlider = VerticalSlider(this, R.drawable.bm_brightness_6, PURPLE) { level ->
            window.attributes = window.attributes.apply { screenBrightness = level.coerceIn(.02f, 1f) }
            android.util.Log.i("flutter", "[BMusic feature] brightness=${window.attributes.screenBrightness}"); scheduleHide()
        }.apply { contentDescription = "Parlaklık"; elevation = dp(5).toFloat() }
        volumeSlider = VerticalSlider(this, R.drawable.bm_volume_up, PURPLE) { level ->
            controller?.volume = level
            android.util.Log.i("flutter", "[BMusic feature] volume=$level"); scheduleHide()
        }.apply { contentDescription = "Ses"; elevation = dp(5).toFloat() }
        brightnessSlider.visibility = View.GONE; volumeSlider.visibility = View.GONE
        root.addView(brightnessSlider, FrameLayout.LayoutParams(dp(40), dp(170), Gravity.LEFT or Gravity.CENTER_VERTICAL).apply { leftMargin = dp(24) })
        root.addView(volumeSlider, FrameLayout.LayoutParams(dp(40), dp(170), Gravity.RIGHT or Gravity.CENTER_VERTICAL).apply { rightMargin = dp(24) })
        speedBadge = TextView(this).apply { elevation = dp(8).toFloat(); text = "2×  ▶▶"; textSize = 14f; setTextColor(Color.WHITE); background = rounded(16f, 0xB0000000.toInt()); setPadding(dp(14), dp(6), dp(14), dp(6)); visibility = View.GONE; contentDescription = "2× hız" }
        root.addView(speedBadge, FrameLayout.LayoutParams(-2, -2, Gravity.TOP or Gravity.CENTER_HORIZONTAL).apply { topMargin = dp(70) })
        heart = ImageView(this).apply { elevation = dp(9).toFloat(); visibility = View.GONE; scaleType = ImageView.ScaleType.FIT_CENTER; importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO }
        root.addView(heart, FrameLayout.LayoutParams(dp(96), dp(96), Gravity.TOP or Gravity.LEFT))
        feedback = TextView(this).apply { elevation = dp(10).toFloat(); textSize = 15f; setTextColor(Color.WHITE); background = rounded(20f, 0xCC14111B.toInt(), 0x6649305E); gravity = Gravity.CENTER; setPadding(dp(18), dp(9), dp(18), dp(9)); visibility = View.GONE }
        root.addView(feedback, FrameLayout.LayoutParams(-2, -2, Gravity.CENTER))
        bubble = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL; gravity = Gravity.CENTER_HORIZONTAL; elevation = dp(12).toFloat(); visibility = View.GONE
            background = rounded(12f, 0xF0110E17.toInt(), PURPLE); setPadding(dp(3), dp(3), dp(3), dp(3))
        }
        preview = ImageView(this).apply { scaleType = ImageView.ScaleType.CENTER_CROP; background = rounded(9f, Color.BLACK); clipToOutline = true }
        bubble.addView(preview, LinearLayout.LayoutParams(dp(160), dp(90)))
        previewTime = TextView(this).apply { setTextColor(Color.WHITE); textSize = 13f; typeface = android.graphics.Typeface.DEFAULT_BOLD; gravity = Gravity.CENTER; setPadding(0, dp(3), 0, dp(1)) }
        bubble.addView(previewTime, LinearLayout.LayoutParams(-2, -2))
        root.addView(bubble, FrameLayout.LayoutParams(-2, -2, Gravity.TOP or Gravity.LEFT))
        timeline.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onStartTrackingTouch(bar: SeekBar) {
                targetPosition = ((controller?.duration ?: 0).coerceAtLeast(0) * bar.progress / 10000); dragging = true; handler.removeCallbacks(hide)
                preview.setImageDrawable(null); preview.visibility = View.GONE; showBubble(bar.progress)
            }
            override fun onProgressChanged(bar: SeekBar, progress: Int, fromUser: Boolean) {
                if (!fromUser) return
                val p = controller ?: return
                targetPosition = (p.duration.coerceAtLeast(0) * progress / 10000)
                clock.text = "${time(targetPosition)} / ${time(p.duration)}"
                showBubble(progress)
                requestFrame(targetPosition)
            }
            override fun onStopTrackingTouch(bar: SeekBar) { controller?.seekTo(targetPosition); dragging = false; previewGeneration++; bubble.visibility = View.GONE; scheduleHide() }
        })
        unlock = icon(R.drawable.bm_lock_open, "Kilidi aç") { locked = false; unlock.visibility = View.GONE; controls(true) }.apply { visibility = View.GONE; background = rounded(28f, 0x99000000.toInt()); elevation = dp(6).toFloat() }
        root.addView(unlock, FrameLayout.LayoutParams(dp(56), dp(56), Gravity.TOP or Gravity.RIGHT).apply { setMargins(0, dp(16), dp(16), 0) })
        val scaler = ScaleGestureDetector(this, object : ScaleGestureDetector.SimpleOnScaleGestureListener() {
            override fun onScale(detector: ScaleGestureDetector): Boolean {
                zoom = (zoom * detector.scaleFactor).coerceIn(1f, 5f)
                display.scaleX = zoom; display.scaleY = zoom
                return true
            }
        })
        val detector = GestureDetector(this, object : GestureDetector.SimpleOnGestureListener() {
            override fun onDown(e: MotionEvent): Boolean = true
            override fun onLongPress(e: MotionEvent) {
                // Right side only: hold for 2× speed, release for the previous speed.
                if (gestureMode != 0 || e.x < root.width / 2f) return
                controller?.let { previousSpeed = it.playbackParameters.speed; hold = true; it.setPlaybackSpeed(2f); speedBadge.visibility = View.VISIBLE; android.util.Log.i("flutter", "[BMusic feature] hold=${it.playbackParameters.speed}") }
            }
        })
        var doubleCandidate = false
        gestures.setOnTouchListener { _, e ->
            if (e.actionMasked == MotionEvent.ACTION_DOWN) android.util.Log.i("flutter", "[BMusic feature] touch=${e.x},${e.y}")
            if (locked) return@setOnTouchListener true
            scaler.onTouchEvent(e)
            if (e.pointerCount > 1 || scaler.isInProgress) { gestureMode = 4; return@setOnTouchListener true }
            detector.onTouchEvent(e)
            val p = controller
            when (e.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    startX = e.x; startY = e.y; startPosition = p?.currentPosition ?: 0
                    startVolume = p?.volume ?: 1f
                    startBrightness = window.attributes.screenBrightness.takeIf { it >= 0 } ?: .5f
                    gestureMode = 0
                    val pending = pendingTap
                    doubleCandidate = pending != null && e.downTime - lastTapUp <= DOUBLE_TAP_MS && hypot(e.x - lastTapX, e.y - lastTapY) < dp(100)
                    if (doubleCandidate) handler.removeCallbacks(pending!!)
                }
                MotionEvent.ACTION_MOVE -> if (p != null && !hold) {
                    val dx = e.x - startX; val dy = e.y - startY
                    if (gestureMode == 0 && !paging && (abs(dx) > dp(18) || abs(dy) > dp(18))) {
                        // Landscape: horizontal = seek, vertical left = brightness, right = volume.
                        // Portrait: no level/seek gestures; a vertical swipe pages the list.
                        gestureMode = if (landscape) { if (abs(dx) > abs(dy)) 1 else if (startX < root.width / 2f) 2 else 3 }
                            else if (reels && abs(dy) > abs(dx)) 5 else 6
                        if (doubleCandidate) { doubleCandidate = false; pendingTap?.run() }
                    }
                    when (gestureMode) {
                        1 -> {
                            dragging = true; handler.removeCallbacks(hide)
                            val windowMs = (p.duration / 20).coerceIn(30000, 180000)
                            targetPosition = (startPosition + (dx / root.width * windowMs).toLong()).coerceIn(0, p.duration.coerceAtLeast(0))
                            val delta = (targetPosition - startPosition) / 1000
                            message("${if (delta >= 0) "+" else ""}$delta sn • ${time(targetPosition)}")
                        }
                        2 -> { val level = (startBrightness - dy / root.height * 1.5f).coerceIn(.02f, 1f); window.attributes = window.attributes.apply { screenBrightness = level }; showLevel(brightnessSlider, level); android.util.Log.i("flutter", "[BMusic feature] brightness=${window.attributes.screenBrightness}") }
                        3 -> { val level = (startVolume - dy / root.height * 1.5f).coerceIn(0f, 1f); p.volume = level; showLevel(volumeSlider, level); android.util.Log.i("flutter", "[BMusic feature] volume=${p.volume}") }
                        5 -> { val edge = (index == 0 && dy > 0) || (index == ids.size - 1 && dy < 0); stage.translationY = if (edge) dy / 4 else dy }
                    }
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    val tap = e.actionMasked == MotionEvent.ACTION_UP && gestureMode == 0 && !hold && e.eventTime - e.downTime < 350
                    if (hold) { p?.setPlaybackSpeed(previousSpeed); android.util.Log.i("flutter", "[BMusic feature] release=$previousSpeed"); hold = false; speedBadge.visibility = View.GONE }
                    if (tap) {
                        if (doubleCandidate) { pendingTap = null; doubleCandidate = false; toggleFavorite(e.x, e.y) }
                        else {
                            lastTapUp = e.eventTime; lastTapX = e.x; lastTapY = e.y
                            val single = Runnable { pendingTap = null; android.util.Log.i("flutter", "[BMusic feature] tap controls=$visible"); controls(!visible); scheduleHide() }
                            pendingTap = single; handler.postDelayed(single, DOUBLE_TAP_MS)
                        }
                    } else if (doubleCandidate) { doubleCandidate = false; pendingTap?.run() }
                    if (gestureMode == 1 && e.actionMasked == MotionEvent.ACTION_UP) { p?.seekTo(targetPosition); android.util.Log.i("flutter", "[BMusic feature] seek=$targetPosition") }
                    if (gestureMode == 5) finishPage(e.y - startY, e.actionMasked == MotionEvent.ACTION_UP && e.eventTime - e.downTime < 250 && abs(e.y - startY) > dp(60))
                    if (gestureMode != 0) dragging = false
                    gestureMode = 0; scheduleHide()
                }
            }
            true
        }
        setContentView(root)
        layoutVideo()
        root.setOnApplyWindowInsetsListener { v, insets ->
            @Suppress("DEPRECATION") v.setPadding(insets.systemWindowInsetLeft, insets.systemWindowInsetTop, insets.systemWindowInsetRight, insets.systemWindowInsetBottom)
            insets
        }
    }
    /** Keeps the preview bubble centred over the seek bar thumb. */
    private fun showBubble(progress: Int) {
        val p = controller
        previewTime.text = time((p?.duration ?: 0).coerceAtLeast(0) * progress / 10000)
        if (bubble.visibility != View.VISIBLE) bubble.visibility = View.VISIBLE
        bubble.measure(View.MeasureSpec.UNSPECIFIED, View.MeasureSpec.UNSPECIFIED)
        val w = bubble.measuredWidth; val h = bubble.measuredHeight
        val bar = IntArray(2).also { timeline.getLocationInWindow(it) }
        val base = IntArray(2).also { root.getLocationInWindow(it) }
        val trackStart = bar[0] - base[0] + timeline.paddingLeft
        val trackWidth = timeline.width - timeline.paddingLeft - timeline.paddingRight
        val x = trackStart + trackWidth * progress / 10000f
        bubble.translationX = (x - w / 2f).coerceIn(dp(6).toFloat(), (root.width - w - dp(6)).toFloat().coerceAtLeast(dp(6).toFloat()))
        bubble.translationY = (bar[1] - base[1] - h - dp(6)).toFloat().coerceAtLeast(0f)
    }
    private fun controls(show: Boolean) {
        visible = show
        val pip = Build.VERSION.SDK_INT >= 24 && isInPictureInPictureMode
        val state = if (show && !pip) View.VISIBLE else View.GONE
        for (view in listOf(panel, heading)) {
            if (view.visibility == state) continue
            view.animate().cancel()
            if (state == View.VISIBLE) { view.alpha = 0f; view.visibility = View.VISIBLE; view.animate().alpha(1f).setDuration(150).start() }
            else view.animate().alpha(0f).setDuration(150).withEndAction { view.visibility = View.GONE; view.alpha = 1f }.start()
        }
    }
    private fun lockScreen() { locked = true; controls(false); unlock.visibility = View.VISIBLE; message("Ekran kilitlendi") }
    private fun scheduleHide() { handler.removeCallbacks(hide); handler.postDelayed(hide, 3500) }
    private fun message(text: String) { feedback.text = text; feedback.visibility = View.VISIBLE; handler.removeCallbacks(clearFeedback); handler.postDelayed(clearFeedback, 1300) }
    private val clearFeedback = Runnable { feedback.visibility = View.GONE }
    private fun seek(delta: Long) { controller?.let { it.seekTo((it.currentPosition + delta).coerceIn(0, it.duration.coerceAtLeast(0))) }; message(if (delta < 0) "−10 saniye" else "+10 saniye") }
    private fun time(ms: Long): String { val seconds = ms.coerceAtLeast(0) / 1000; return if (seconds >= 3600) "%d:%02d:%02d".format(seconds / 3600, seconds / 60 % 60, seconds % 60) else "%d:%02d".format(seconds / 60, seconds % 60) }
    /** Black navigation/status bars with light buttons whenever Android shows them. */
    @Suppress("DEPRECATION")
    private fun darkSystemBars() {
        window.navigationBarColor = Color.BLACK
        window.statusBarColor = Color.BLACK
        if (Build.VERSION.SDK_INT >= 28) window.navigationBarDividerColor = Color.BLACK
        if (Build.VERSION.SDK_INT >= 30) window.insetsController?.setSystemBarsAppearance(0,
            android.view.WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS or android.view.WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS)
        else if (Build.VERSION.SDK_INT >= 26) window.decorView.systemUiVisibility = window.decorView.systemUiVisibility and
            (View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR or View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR).inv()
    }
    private fun showSystemBars() {
        window.clearFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN)
        if (Build.VERSION.SDK_INT >= 30) window.insetsController?.show(WindowInsets.Type.systemBars())
        else { @Suppress("DEPRECATION") window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_LAYOUT_STABLE }
        darkSystemBars()
    }
    // Full screen in both orientations; system bars come back only in PiP or by swiping from the edge.
    private fun applySystemBars() { if (!(Build.VERSION.SDK_INT >= 24 && isInPictureInPictureMode)) hideSystemBars() else showSystemBars() }
    private fun hideSystemBars() {
        darkSystemBars()
        if (Build.VERSION.SDK_INT >= 30) {
            window.insetsController?.hide(WindowInsets.Type.systemBars())
            window.insetsController?.systemBarsBehavior = android.view.WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_LAYOUT_STABLE or View.SYSTEM_UI_FLAG_FULLSCREEN or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
        }
    }
    override fun onWindowFocusChanged(hasFocus: Boolean) { super.onWindowFocusChanged(hasFocus); if (hasFocus) applySystemBars() }
    private fun closeRetriever() {
        previewGeneration++
        frames.execute { try { retriever?.release() } catch (_: Exception) { }; retriever = null; retrieverSource = "" }
    }
    /** Scrub preview frames: one retriever per video, nearest key frame (fast). */
    private fun requestFrame(position: Long) {
        if (source.isEmpty()) return
        pendingFramePosition = position
        if (frameBusy) return
        frameBusy = true
        val generation = previewGeneration
        val path = source
        frames.execute {
            val bitmap = try {
                val r = retriever?.takeIf { retrieverSource == path } ?: MediaMetadataRetriever().also { fresh ->
                    try { retriever?.release() } catch (_: Exception) { }
                    fresh.setDataSource(path); retriever = fresh; retrieverSource = path
                }
                if (Build.VERSION.SDK_INT >= 27) r.getScaledFrameAtTime(position * 1000, MediaMetadataRetriever.OPTION_CLOSEST_SYNC, 320, 180)
                else r.getFrameAtTime(position * 1000, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
            } catch (_: Exception) { null }
            handler.post {
                frameBusy = false
                if (!isDestroyed && generation == previewGeneration && dragging) {
                    if (bitmap != null) { preview.setImageBitmap(bitmap); preview.visibility = View.VISIBLE; android.util.Log.i("flutter", "[BMusic feature] preview=$position") }
                    val latest = pendingFramePosition
                    if (latest != null && latest != position) requestFrame(latest)
                } else bitmap?.recycle()
            }
        }
    }
    // ---------------------------------------------------------------- ⋮ sheet
    /** Dark rounded bottom sheet with every secondary tool (swipe down or tap outside to close). */
    private fun showTools() {
        handler.removeCallbacks(hide)
        closeSheet(animated = false)
        val overlay = FrameLayout(this).apply {
            elevation = dp(20).toFloat(); setBackgroundColor(0x00000000); isClickable = true
            setOnClickListener { closeSheet() }
            contentDescription = "Sayfayı kapat"
        }
        val panelView = DragSheet(this) { closeSheet() }.apply {
            orientation = LinearLayout.VERTICAL
            background = GradientDrawable().apply { setColor(SHEET_BG); val r = dp(24).toFloat(); cornerRadii = floatArrayOf(r, r, r, r, 0f, 0f, 0f, 0f) }
            isClickable = true; elevation = dp(24).toFloat()
        }
        val maxWidth = dp(560)
        val width = if (resources.displayMetrics.widthPixels > maxWidth) maxWidth else -1
        overlay.addView(panelView, FrameLayout.LayoutParams(width, -2, Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL).apply { topMargin = dp(if (landscape) 16 else 72) })
        root.addView(overlay, FrameLayout.LayoutParams(-1, -1))
        sheet = overlay; sheetPanel = panelView
        showMainPage(panelView)
        overlay.animate().cancel()
        overlay.setBackgroundColor(0x99000000.toInt()); overlay.alpha = 0f; overlay.animate().alpha(1f).setDuration(160).start()
        panelView.translationY = dp(400).toFloat(); panelView.animate().translationY(0f).setDuration(220).setInterpolator(DecelerateInterpolator()).start()
        android.util.Log.i("flutter", "[BMusic feature] sheet=open")
    }
    private fun closeSheet(animated: Boolean = true) {
        val overlay = sheet ?: return
        val panelView = sheetPanel
        sheet = null; sheetPanel = null
        if (!animated || panelView == null) { root.removeView(overlay) }
        else {
            overlay.animate().alpha(0f).setDuration(180).start()
            panelView.animate().translationY(panelView.height.toFloat().coerceAtLeast(dp(300).toFloat())).setDuration(180).withEndAction { root.removeView(overlay) }.start()
        }
        scheduleHide()
    }
    private fun sheetHandle(): View = View(this).apply { background = rounded(3f, 0x55FFFFFF) }
    private fun sheetScaffold(panelView: DragSheet, header: View?): LinearLayout {
        panelView.removeAllViews()
        panelView.addView(sheetHandle(), LinearLayout.LayoutParams(dp(40), dp(4)).apply { gravity = Gravity.CENTER_HORIZONTAL; topMargin = dp(10); bottomMargin = dp(6) })
        header?.let { panelView.addView(it, LinearLayout.LayoutParams(-1, -2)) }
        val list = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding(0, 0, 0, dp(12)) }
        val scroll = ScrollView(this).apply { isVerticalScrollBarEnabled = false; overScrollMode = View.OVER_SCROLL_NEVER; addView(list) }
        panelView.scroller = scroll
        panelView.addView(scroll, LinearLayout.LayoutParams(-1, -2))
        return list
    }
    private fun sectionTitle(list: LinearLayout, text: String) {
        list.addView(TextView(this).apply {
            this.text = text.uppercase(java.util.Locale("tr")); setTextColor(0xFF9C8AB5.toInt()); textSize = 12f; letterSpacing = .08f
            typeface = android.graphics.Typeface.DEFAULT_BOLD; setPadding(dp(22), dp(14), dp(22), dp(4))
        })
    }
    /** One monochrome row: purple icon, white label, optional value on the right. */
    private fun sheetRow(list: LinearLayout, iconRes: Int, label: String, value: String? = null, tint: Int = ICON_TINT,
                         textColor: Int = Color.WHITE, onClick: (TextView?) -> Unit): TextView? {
        val row = LinearLayout(this).apply {
            gravity = Gravity.CENTER_VERTICAL; setPadding(dp(22), 0, dp(20), 0); isClickable = true; isFocusable = true
            background = RippleDrawable(ColorStateList.valueOf(0x33BC62FF), null, GradientDrawable().apply { setColor(Color.WHITE) })
            contentDescription = label
        }
        row.addView(ImageView(this).apply { setImageResource(iconRes); imageTintList = ColorStateList.valueOf(tint); importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO }, LinearLayout.LayoutParams(dp(22), dp(22)))
        row.addView(TextView(this).apply { text = label; setTextColor(textColor); textSize = 15f; setPadding(dp(18), 0, dp(8), 0); maxLines = 1; ellipsize = TextUtils.TruncateAt.END; importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO }, LinearLayout.LayoutParams(0, -2, 1f))
        val valueView = value?.let { TextView(this).apply { text = it; setTextColor(0xFFB9A6D3.toInt()); textSize = 13f; importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO }.also { v -> row.addView(v) } }
        row.setOnClickListener { onClick(valueView) }
        list.addView(row, LinearLayout.LayoutParams(-1, dp(52)))
        return valueView
    }
    private fun onOff(on: Boolean) = if (on) "Açık" else "Kapalı"
    /** Closes the sheet and then runs [action] (tools that open their own UI). */
    private fun thenClose(action: () -> Unit): (TextView?) -> Unit = { closeSheet(); handler.postDelayed({ if (!isDestroyed) action() }, 120) }
    private fun showMainPage(panelView: DragSheet) {
        val list = sheetScaffold(panelView, null)
        sectionTitle(list, "Oynatma")
        sheetRow(list, R.drawable.bm_speed, "Oynatma hızı", rateLabel(currentRate())) { showChoicePage(panelView, "Oynatma hızı", speeds.map { rateLabel(it) }, speeds.indexOfFirst { abs(it - currentRate()) < .01f }) { i -> controller?.setPlaybackSpeed(speeds[i]); android.util.Log.i("flutter", "[BMusic feature] speed=${speeds[i]}"); message("Hız ${rateLabel(speeds[i])}") } }
        sheetRow(list, R.drawable.bm_repeat, "Tekrar oynat", onOff(repeatOn())) { v -> toggleRepeat(); v?.text = onOff(repeatOn()) }
        sheetRow(list, R.drawable.bm_fit_screen, "Ekranı doldur", onOff(cover)) { v ->
            cover = !cover; display.resizeMode = if (cover) AspectRatioFrameLayout.RESIZE_MODE_ZOOM else AspectRatioFrameLayout.RESIZE_MODE_FIT; v?.text = onOff(cover)
            android.util.Log.i("flutter", "[BMusic feature] cover=$cover")
        }
        sheetRow(list, R.drawable.bm_lock, "Ekran kilidi", onClick = thenClose { lockScreen() })
        sheetRow(list, R.drawable.bm_picture_in_picture_alt, "Yüzen video", onClick = thenClose { floating() })
        sheetRow(list, R.drawable.bm_bedtime, "Uyku zamanlayıcısı", sleepLabel()) {
            val current = sleepChoices.indexOf(sleepMinutes).takeIf { sleepDeadline > 0 || sleepMinutes == 0 } ?: -1
            showChoicePage(panelView, "Uyku zamanlayıcısı", sleepChoices.map { if (it == 0) "Kapalı" else "$it dakika" }, if (sleepDeadline > 0) current else 0) { i -> setSleep(sleepChoices[i]) }
        }
        sheetRow(list, R.drawable.bm_headphones, "Ekran kapalı dinleme", onOff(listenInBackground)) { v ->
            listenInBackground = !listenInBackground; v?.text = onOff(listenInBackground)
            message(if (listenInBackground) "Ekran kapanınca ses devam eder" else "Ekran kapalı dinleme kapatıldı")
        }
        sheetRow(list, R.drawable.bm_volume_up, "Konuşmaları belirginleştir", onOff(speech)) { v ->
            if (VideoPlaybackService.active?.applySpeech(!speech) == true) { speech = !speech; v?.text = onOff(speech) } else message("Bu cihazda ses efekti desteklenmiyor")
        }
        sheetRow(list, R.drawable.bm_closed_caption, "Altyazı ekle", onClick = thenClose {
            @Suppress("DEPRECATION") startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE).setType("*/*"), 813)
        })
        if (zoom > 1.01f) sheetRow(list, R.drawable.bm_zoom_out_map, "Yakınlaştırmayı sıfırla", onClick = thenClose { zoom = 1f; display.scaleX = 1f; display.scaleY = 1f })
        sectionTitle(list, "Düzenle")
        sheetRow(list, R.drawable.bm_content_cut, "Kırp", onClick = thenClose { clipDialog() })
        sheetRow(list, R.drawable.bm_gif_box, "GIF oluştur", onClick = thenClose { gifDialog() })
        sheetRow(list, R.drawable.bm_photo_camera, "Ekran görüntüsü", onClick = thenClose { snapshot() })
        sheetRow(list, R.drawable.bm_music_note, "Sesi kaydet", onClick = thenClose { export(true, 0, controller?.duration?.coerceAtLeast(0) ?: 0) })
        sectionTitle(list, "Dosya")
        sheetRow(list, R.drawable.bm_info, "Video bilgileri", onClick = thenClose { videoInfo() })
        sheetRow(list, R.drawable.bm_share, "Paylaş", onClick = thenClose { shareVideo() })
        sheetRow(list, R.drawable.bm_drive_file_move, "Klasöre taşı", onClick = thenClose { editFile(false) })
        sheetRow(list, R.drawable.bm_edit, "Yeniden adlandır", onClick = thenClose { editFile(true) })
        list.addView(View(this).apply { setBackgroundColor(0x22FFFFFF) }, LinearLayout.LayoutParams(-1, dp(1)).apply { setMargins(dp(22), dp(8), dp(22), dp(4)) })
        sheetRow(list, R.drawable.bm_delete, "Sil", tint = DANGER, textColor = DANGER, onClick = thenClose { deleteVideo() })
    }
    private val speeds = floatArrayOf(.5f, .75f, 1f, 1.25f, 1.5f, 1.75f, 2f)
    private val sleepChoices = intArrayOf(0, 10, 15, 30, 45, 60, 90)
    /** Sub page of the sheet (speed, sleep timer): back arrow + options with a check mark. */
    private fun showChoicePage(panelView: DragSheet, heading: String, options: List<String>, selected: Int, onPick: (Int) -> Unit) {
        val header = LinearLayout(this).apply { gravity = Gravity.CENTER_VERTICAL; setPadding(dp(8), 0, dp(16), 0) }
        header.addView(ImageButton(this).apply {
            setImageResource(R.drawable.bm_arrow_back); imageTintList = ColorStateList.valueOf(Color.WHITE); background = ripple(); contentDescription = "Geri"
            setOnClickListener { showMainPage(panelView) }
        }, LinearLayout.LayoutParams(dp(48), dp(48)))
        header.addView(TextView(this).apply { text = heading; setTextColor(Color.WHITE); textSize = 16f; typeface = android.graphics.Typeface.DEFAULT_BOLD; setPadding(dp(6), 0, 0, 0) })
        val list = sheetScaffold(panelView, header)
        options.forEachIndexed { i, label ->
            val row = LinearLayout(this).apply {
                gravity = Gravity.CENTER_VERTICAL; setPadding(dp(24), 0, dp(20), 0); isClickable = true; contentDescription = label
                background = RippleDrawable(ColorStateList.valueOf(0x33BC62FF), null, GradientDrawable().apply { setColor(Color.WHITE) })
                setOnClickListener { onPick(i); closeSheet() }
            }
            row.addView(TextView(this).apply { text = label; textSize = 15f; setTextColor(if (i == selected) PURPLE else Color.WHITE); if (i == selected) typeface = android.graphics.Typeface.DEFAULT_BOLD }, LinearLayout.LayoutParams(0, -2, 1f))
            if (i == selected) row.addView(TextView(this).apply { text = "✓"; textSize = 17f; setTextColor(PURPLE) })
            list.addView(row, LinearLayout.LayoutParams(-1, dp(50)))
        }
    }
    private fun layoutVideo() {
        display.layoutParams = FrameLayout.LayoutParams(-1, -1)
        if (::brightnessSlider.isInitialized) controls(visible)
    }
    override fun onConfigurationChanged(newConfig: Configuration) { super.onConfigurationChanged(newConfig); layoutVideo(); applySystemBars() }
    private fun videoInfo() {
        val p=controller
        dialog().setTitle("Video Bilgileri").setMessage("$title\n\nSüre: ${time(p?.duration?:0)}\nÇözünürlük: ${p?.videoSize?.width?:0} × ${p?.videoSize?.height?:0}\nBoyut: ${"%.1f".format(File(source).length()/1048576.0)} MB\n\n$source").setPositiveButton("Tamam",null).show()
    }
    private fun mediaUri():Uri? {
        var uri:Uri?=null
        contentResolver.query(MediaStore.Video.Media.EXTERNAL_CONTENT_URI,arrayOf("_id"),"_data = ?",arrayOf(source),null)?.use { if(it.moveToFirst()) uri=android.content.ContentUris.withAppendedId(MediaStore.Video.Media.EXTERNAL_CONTENT_URI,it.getLong(0)) }
        return uri
    }
    private fun editFile(rename:Boolean) {
        val field=EditText(this).apply { setSingleLine(); setText(if(rename) File(source).nameWithoutExtension else "BMusic") }
        dialog().setTitle(if(rename) "Yeniden Adlandır" else "Movies içindeki klasöre taşı").setView(field).setNegativeButton("İptal",null).setPositiveButton("Kaydet") { _,_ ->
            val name=field.text.toString().trim()
            if(name.isEmpty() || name=="." || name==".." || name.any { it=='/' || it=='\\' }) { message("Geçerli bir ad girin"); return@setPositiveButton }
            val uri=mediaUri() ?: run { message("Dosya arşivde bulunamadı"); return@setPositiveButton }
            if(!rename && Build.VERSION.SDK_INT<29) { message("Taşımak için telefonun dosya yöneticisini kullanın"); return@setPositiveButton }
            val values=ContentValues().apply { if(rename) put(MediaStore.MediaColumns.DISPLAY_NAME,"$name.${File(source).extension}") else put(MediaStore.MediaColumns.RELATIVE_PATH,"Movies/$name") }
            val action={ contentResolver.update(uri,values,null,null); message("Dosya güncellendi"); finishPlayer() }
            runEdit(uri,action)
        }.show()
    }
    private fun runEdit(uri:Uri,action:()->Unit) {
        try { action(); edited = true }
        catch(e:SecurityException) {
            pendingEdit=action
            if(Build.VERSION.SDK_INT>=30) startIntentSenderForResult(MediaStore.createWriteRequest(contentResolver,listOf(uri)).intentSender,814,null,0,0,0)
            else if(Build.VERSION.SDK_INT>=29 && e is android.app.RecoverableSecurityException) startIntentSenderForResult(e.userAction.actionIntent.intentSender,814,null,0,0,0)
            else { pendingEdit=null; message("Dosyayı değiştirme izni yok") }
        } catch(e:Exception) { message("Dosya güncellenemedi: ${e.message}") }
    }
    private fun deleteVideo() {
        dialog().setTitle("Video silinsin mi?").setMessage(title).setNegativeButton("İptal",null).setPositiveButton("Sil") { _,_ ->
            val uri=mediaUri() ?: return@setPositiveButton
            if(Build.VERSION.SDK_INT>=30) startIntentSenderForResult(MediaStore.createDeleteRequest(contentResolver,listOf(uri)).intentSender,815,null,0,0,0)
            else runEdit(uri) { contentResolver.delete(uri,null,null); finishPlayer() }
        }.show()
    }
    private fun gifDialog() {
        if(gifBusy) { message("GIF hazırlanıyor"); return }
        // AlertDialog hides setItems() when a message is set, so the hint lives in the title.
        dialog().setTitle("GIF Oluşturma • bu andan itibaren (320 px, 6 kare/sn)").setItems(arrayOf("3 saniye","5 saniye","10 saniye")) { _,which ->
            val p=controller?:return@setItems
            val start=p.currentPosition; val end=(start+longArrayOf(3000,5000,10000)[which]).coerceAtMost(p.duration)
            if(end<=start) return@setItems
            gifBusy=true; val file=File(cacheDir,"BMusic_${System.currentTimeMillis()}.gif"); output=file
            exportDialog=dialog().setTitle("GIF hazırlanıyor").setView(ProgressBar(this)).setCancelable(false).create(); exportDialog?.show()
            frames.execute {
                var uri:Uri?=null
                try {
                    val r=MediaMetadataRetriever()
                    try {
                        r.setDataSource(source)
                        file.outputStream().use { out ->
                            var encoder:PreviewGif?=null
                            var at=start
                            while(at<end) {
                                val original=r.getFrameAtTime(at*1000,MediaMetadataRetriever.OPTION_CLOSEST)?:throw IllegalStateException("Sahne alınamadı")
                                val w=minOf(320,original.width); val h=(original.height.toLong()*w/original.width).toInt().coerceAtLeast(1)
                                val frame=android.graphics.Bitmap.createScaledBitmap(original,w,h,true)
                                if(encoder==null) encoder=PreviewGif(out,w,h)
                                encoder.frame(frame)
                                if(frame!==original) frame.recycle(); original.recycle(); at+=167
                            }
                            encoder?.finish()
                        }
                    } finally { r.release() }
                    if(Build.VERSION.SDK_INT>=29) {
                        uri=contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI,ContentValues().apply { put(MediaStore.MediaColumns.DISPLAY_NAME,file.name); put(MediaStore.MediaColumns.MIME_TYPE,"image/gif"); put(MediaStore.MediaColumns.RELATIVE_PATH,"Pictures/BMusic"); put(MediaStore.MediaColumns.IS_PENDING,1) })?:throw IllegalStateException("Dosya oluşturulamadı")
                        contentResolver.openOutputStream(uri!!)?.use { out -> file.inputStream().use { it.copyTo(out) } }?:throw IllegalStateException("Yazılamadı")
                        contentResolver.update(uri!!,ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING,0) },null,null)
                        file.delete(); output=null
                        handler.post { message("GIF galeriye kaydedildi") }
                    } else handler.post { startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE).setType("image/gif").putExtra(Intent.EXTRA_TITLE,file.name),812) }
                } catch(e:Exception) { uri?.let { contentResolver.delete(it,null,null) }; file.delete(); output=null; handler.post { message("GIF oluşturulamadı: ${e.message}") } }
                finally { gifBusy=false; handler.post { exportDialog?.dismiss(); exportDialog=null } }
            }
        }.show()
    }
    private fun floating() {
        if (Build.VERSION.SDK_INT < 26 || !packageManager.hasSystemFeature("android.software.picture_in_picture")) { message("Bu cihaz yüzen videoyu desteklemiyor"); return }
        try {
            controls(false)
            val params = pipParams()
            android.util.Log.i("flutter", "[BMusic feature] pip-actions=${pipActionCount}")
            val ok = enterPictureInPictureMode(params)
            if (!ok) { controls(true); message("Yüzen video iznini telefon ayarlarından açın") }
        } catch (_: Exception) { controls(true); message("Yüzen video iznini telefon ayarlarından açın") }
    }
    private var pipActionCount = 0
    /** PiP window (screen 8): 10 s back, play/pause and 10 s forward. */
    @TargetApi(26)
    private fun pipParams(): PictureInPictureParams {
        val size = controller?.videoSize
        val ratio = if (size != null && size.width > 0 && size.height > 0) (size.width.toFloat() / size.height).coerceIn(.42f, 2.38f) else 16f / 9
        val playing = controller?.isPlaying == true
        fun action(code: Int, icon: Int, title: String) = RemoteAction(Icon.createWithResource(this, icon), title, title,
            PendingIntent.getBroadcast(this, code, Intent(pipControl).setPackage(packageName).putExtra("control", code), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
        val actions = listOf(action(1, R.drawable.bm_replay_10, "10 saniye geri"),
            if (playing) action(2, R.drawable.bm_pause, "Duraklat") else action(2, R.drawable.bm_play_arrow, "Oynat"),
            action(3, R.drawable.bm_forward_10, "10 saniye ileri"))
        pipActionCount = actions.size
        return PictureInPictureParams.Builder().setAspectRatio(Rational((ratio * 1000).toInt(), 1000)).setActions(actions).build()
    }
    private fun updatePip() {
        if (Build.VERSION.SDK_INT >= 26 && isInPictureInPictureMode) try { setPictureInPictureParams(pipParams()) } catch (_: Exception) { }
    }
    override fun onPictureInPictureModeChanged(inPictureInPictureMode: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(inPictureInPictureMode, newConfig)
        controls(!inPictureInPictureMode)
        layoutVideo()
        if (!inPictureInPictureMode && !isFinishing) applySystemBars()
    }
    private fun snapshot() {
        val position = controller?.currentPosition ?: return
        frames.execute {
            var uri: Uri? = null
            try {
                val bitmap = MediaMetadataRetriever().let { r ->
                    try { r.setDataSource(source); r.getFrameAtTime(position * 1000, MediaMetadataRetriever.OPTION_CLOSEST) }
                    finally { r.release() }
                } ?: throw IllegalStateException("Bu sahne alınamadı")
                uri = contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, "BMusic_${System.currentTimeMillis()}.png")
                    put(MediaStore.MediaColumns.MIME_TYPE, "image/png")
                    if (Build.VERSION.SDK_INT >= 29) { put(MediaStore.MediaColumns.RELATIVE_PATH, "Pictures/BMusic"); put(MediaStore.MediaColumns.IS_PENDING, 1) }
                }) ?: throw IllegalStateException("Fotoğraf kaydedilemedi")
                try { contentResolver.openOutputStream(uri!!)?.use { if (!bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, it)) throw IllegalStateException("Fotoğraf yazılamadı") } ?: throw IllegalStateException("Fotoğraf yazılamadı") }
                finally { bitmap.recycle() }
                if (Build.VERSION.SDK_INT >= 29) contentResolver.update(uri!!, ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) }, null, null)
                handler.post { message("Fotoğraf galeriye kaydedildi") }
            } catch (e: Exception) { uri?.let { contentResolver.delete(it, null, null) }; handler.post { message("Fotoğraf alınamadı: ${e.message}") } }
        }
    }
    private fun shareVideo() {
        try {
            var uri: Uri? = null
            contentResolver.query(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, arrayOf("_id"), "_data = ?", arrayOf(source), null)?.use {
                if (it.moveToFirst()) uri = android.content.ContentUris.withAppendedId(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, it.getLong(0))
            }
            val media = uri ?: throw IllegalStateException("Dosya medya arşivinde bulunamadı")
            val share = Intent(Intent.ACTION_SEND).setType("video/*").putExtra(Intent.EXTRA_STREAM, media).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            share.clipData = android.content.ClipData.newRawUri("Video", media)
            startActivity(Intent.createChooser(share, "Videoyu paylaş"))
        } catch (e: Exception) { message("Paylaşım açılamadı: ${e.message}") }
    }
    private fun clipDialog(reset: Boolean = true) {
        val p = controller ?: return
        val total = p.duration.coerceAtLeast(0)
        if (total <= 0) { message("Önce videonun açılmasını bekleyin"); return }
        if (reset) { clipStart = p.currentPosition.coerceAtMost((total - 1000).coerceAtLeast(0)); clipEnd = (clipStart + 30000).coerceAtMost(total) }
        val content = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding(dp(20), 0, dp(20), 0) }
        val label = TextView(this)
        fun update() { label.text = "Başlangıç ${time(clipStart)} • Bitiş ${time(clipEnd)}\nSeçilen süre ${time(clipEnd - clipStart)}" }
        content.addView(label); update()
        val start = SeekBar(this).apply { max = 10000; progress = (clipStart * 10000 / total).toInt(); contentDescription = "Klip başlangıcı" }
        val end = SeekBar(this).apply { max = 10000; progress = (clipEnd * 10000 / total).toInt(); contentDescription = "Klip bitişi" }
        fun listener(isStart: Boolean) = object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(bar: SeekBar, value: Int, user: Boolean) { if (user) { if (isStart) clipStart = (total * value / 10000).coerceAtMost(clipEnd - 250) else clipEnd = (total * value / 10000).coerceAtLeast(clipStart + 250).coerceAtMost(total); update() } }
            override fun onStartTrackingTouch(bar: SeekBar) {}
            override fun onStopTrackingTouch(bar: SeekBar) {}
        }
        start.setOnSeekBarChangeListener(listener(true)); end.setOnSeekBarChangeListener(listener(false))
        content.addView(TextView(this).apply { text = "Başlangıç" }); content.addView(start)
        content.addView(TextView(this).apply { text = "Bitiş" }); content.addView(end)
        dialog().setTitle("Kısa klip çıkar").setView(content)
            .setNegativeButton("İptal", null).setNeutralButton("Önizle") { _, _ -> p.seekTo(clipStart); clipPreviewEnd = clipEnd; p.play() }
            .setPositiveButton("Kaydet") { _, _ -> export(false, clipStart, clipEnd) }.show()
    }
    private fun export(audioOnly: Boolean, start: Long, end: Long) {
        if (transformer != null || source.isEmpty() || end <= start) { message("Geçerli bir aralık seçin"); return }
        val file = File(cacheDir, "BMusic_${if (audioOnly) "Ses" else "Klip"}_${System.currentTimeMillis()}.${if (audioOnly) "m4a" else "mp4"}")
        output = file
        val progress = ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply { max = 100 }
        exportDialog = dialog().setTitle(if (audioOnly) "Ses kaydediliyor" else "Klip hazırlanıyor")
            .setView(progress).setCancelable(false).setNegativeButton("İptal") { _, _ -> transformer?.cancel(); transformer = null; file.delete(); output = null }.create()
        exportDialog!!.show()
        val item = EditedMediaItem.Builder(MediaItem.Builder().setUri(Uri.fromFile(File(source)))
            .setClippingConfiguration(MediaItem.ClippingConfiguration.Builder().setStartPositionMs(start).setEndPositionMs(end).build()).build())
            .setRemoveVideo(audioOnly).build()
        val builder = Transformer.Builder(this).setAudioMimeType(MimeTypes.AUDIO_AAC)
            .addListener(object : Transformer.Listener {
                override fun onCompleted(composition: Composition, result: ExportResult) {
                    transformer = null; exportDialog?.dismiss(); exportDialog = null
                    saveExport(file, audioOnly)
                }
                override fun onError(composition: Composition, result: ExportResult, exception: ExportException) {
                    transformer = null; exportDialog?.dismiss(); exportDialog = null; file.delete(); output = null
                    message("Dışa aktarma başarısız: ${exception.errorCodeName}")
                }
            })
        if (!audioOnly) builder.setVideoMimeType(MimeTypes.VIDEO_H264)
        try {
            transformer = builder.build(); transformer!!.start(item, file.absolutePath)
            val poll = object : Runnable { override fun run() { val t = transformer ?: return; val holder = ProgressHolder(); if (t.getProgress(holder) == Transformer.PROGRESS_STATE_AVAILABLE) progress.progress = holder.progress; handler.postDelayed(this, 400) } }; handler.post(poll)
        } catch (e: Exception) { transformer = null; exportDialog?.dismiss(); file.delete(); output = null; message("İşlem başlatılamadı: ${e.message}") }
    }
    private fun saveExport(file: File, audio: Boolean) {
        // Copy large outputs away from the UI thread; only publish completed files.
        frames.execute {
            var uri: Uri? = null
            try {
                if (Build.VERSION.SDK_INT >= 29) {
                    val collection = if (audio) MediaStore.Audio.Media.EXTERNAL_CONTENT_URI else MediaStore.Video.Media.EXTERNAL_CONTENT_URI
                    uri = contentResolver.insert(collection, ContentValues().apply {
                        put(MediaStore.MediaColumns.DISPLAY_NAME, file.name)
                        put(MediaStore.MediaColumns.MIME_TYPE, if (audio) "audio/mp4" else "video/mp4")
                        put(MediaStore.MediaColumns.RELATIVE_PATH, if (audio) "Music/BMusic" else "Movies/BMusic")
                        put(MediaStore.MediaColumns.IS_PENDING, 1)
                    }) ?: throw IllegalStateException("Dosya oluşturulamadı")
                    contentResolver.openOutputStream(uri!!)?.use { out -> file.inputStream().use { it.copyTo(out) } } ?: throw IllegalStateException("Dosya yazılamadı")
                    contentResolver.update(uri!!, ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) }, null, null)
                    file.delete()
                } else {
                    // Android 8/9: system document picker, no broad write permission.
                    handler.post {
                        startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE)
                            .setType(if (audio) "audio/mp4" else "video/mp4").putExtra(Intent.EXTRA_TITLE, file.name), 812)
                    }; return@execute
                }
                handler.post { output = null; message("Kaydedildi: ${file.name}") }
            } catch (e: Exception) {
                uri?.let { contentResolver.delete(it, null, null) }
                handler.post { message("Dosya kaydedilemedi: ${e.message}") }
                file.delete(); output = null
            }
        }
    }
    @Deprecated("Document picker")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if(requestCode==815) { if(resultCode==RESULT_OK) { edited = true; finishPlayer() }; return }
        if(requestCode==814) { val action=pendingEdit; pendingEdit=null; if(resultCode==RESULT_OK) try { action?.invoke(); edited = true } catch(e:Exception) { message("İşlem tamamlanamadı: ${e.message}") }; return }
        if(requestCode==813) {
            val uri=data?.data
            if(resultCode==RESULT_OK && uri!=null) {
                try {
                    contentResolver.takePersistableUriPermission(uri,Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    var name=""
                    contentResolver.query(uri,arrayOf(android.provider.OpenableColumns.DISPLAY_NAME),null,null,null)?.use { if(it.moveToFirst()) name=it.getString(0) }
                    val type=when(name.substringAfterLast('.').lowercase()) { "vtt"->MimeTypes.TEXT_VTT; "srt"->MimeTypes.APPLICATION_SUBRIP; "ssa","ass"->MimeTypes.TEXT_SSA; else->throw IllegalArgumentException("SRT, VTT veya ASS altyazı seçin") }
                    val p=controller?:return; val position=p.currentPosition; val playing=p.playWhenReady
                    val subtitle=MediaItem.SubtitleConfiguration.Builder(uri).setMimeType(type).setSelectionFlags(androidx.media3.common.C.SELECTION_FLAG_DEFAULT).build()
                    val item=p.currentMediaItem?.buildUpon()?.setSubtitleConfigurations(listOf(subtitle))?.build()?:return
                    p.setMediaItem(item,position); p.prepare(); p.playWhenReady=playing; message("Altyazı açıldı")
                } catch(e:Exception) { message("Altyazı açılamadı: ${e.message}") }
            }; return
        }
        if (requestCode != 812) return
        val file = output ?: return
        val uri = data?.data
        if (resultCode != RESULT_OK || uri == null) { file.delete(); output = null; return }
        frames.execute {
            try { contentResolver.openOutputStream(uri)?.use { out -> file.inputStream().use { it.copyTo(out) } } ?: throw IllegalStateException("Dosya yazılamadı"); handler.post { message("Kaydedildi: ${file.name}") } }
            catch (e: Exception) { handler.post { message("Kayıt başarısız: ${e.message}") } }
            finally { file.delete(); output = null }
        }
    }
    fun closeForReplacement() {
        replacing = true
        val p = controller
        if (source.isNotEmpty() && p != null) {
            getSharedPreferences("video_positions", MODE_PRIVATE).edit()
                .putLong(source, p.currentPosition).apply()
        }
        setResult(RESULT_OK, resultIntent(p))
        p?.pause()
        finish()
    }
    private fun finishPlayer() {
        if (transformer != null) { dialog().setMessage("Devam eden işlemi iptal edip çıkılsın mı?").setNegativeButton("Devam et", null).setPositiveButton("Çık") { _, _ -> transformer?.cancel(); transformer = null; output?.delete(); finishPlayer() }.show(); return }
        isClosing = true
        val p = controller
        if (source.isNotEmpty() && p != null) {
            val position = if (p.duration - p.currentPosition <= 3000) 0 else p.currentPosition
            getSharedPreferences("video_positions", MODE_PRIVATE).edit().putLong(source, position).apply()
        }
        setResult(RESULT_OK, resultIntent(p).also { if (p != null && p.duration - p.currentPosition <= 3000) { positions[index] = 0; it.putExtra("positions", positions) } })
        p?.pause(); p?.stop(); finish()
    }
    @Deprecated("Back callback") override fun onBackPressed() { if (sheet != null) closeSheet() else if (locked) { locked = false; unlock.visibility = View.GONE; controls(true) } else finishPlayer() }
    override fun onPause() {
        super.onPause()
        if (!replacing && !isInPictureInPictureMode && !listenInBackground) controller?.pause()
    }
    override fun onStop() {
        super.onStop()
        if (!replacing && isInPictureInPictureMode) { controller?.pause() }
    }
    override fun onDestroy() {
        if (active === this) active = null
        try { unregisterReceiver(pipReceiver) } catch (_: Exception) { }
        handler.removeCallbacksAndMessages(null); previewGeneration++; pendingTap = null
        transformer?.cancel(); exportDialog?.dismiss(); output?.delete()
        display.player = null
        future?.let { MediaController.releaseFuture(it) }
        frames.execute { try { retriever?.release() } catch (_: Exception) { }; retriever = null }
        frames.shutdown(); posterWorker.shutdownNow(); posters.clear()
        if (isClosing) stopService(Intent(this, VideoPlaybackService::class.java))
        super.onDestroy()
    }
}

/** Vertical brightness/volume slider used by the reference player (screens 5 and 7). */
class VerticalSlider(context: Context, iconRes: Int, accent: Int, private val onChange: (Float) -> Unit) : View(context) {
    var value = .5f
        set(v) { field = v.coerceIn(0f, 1f); invalidate() }
    private val density = resources.displayMetrics.density
    private val background = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = 0xB008060C.toInt() }
    private val track = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = 0x55FFFFFF }
    private val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = accent }
    private val icon = context.getDrawable(iconRes)!!.mutate().apply { setTint(Color.WHITE) }
    private val area = RectF()
    init { isClickable = true; isFocusable = true }
    private fun trackTop() = 36 * density
    private fun trackBottom() = height - 14 * density
    override fun onDraw(canvas: Canvas) {
        val w = width.toFloat()
        area.set(0f, 0f, w, height.toFloat()); canvas.drawRoundRect(area, w / 2, w / 2, background)
        val size = (20 * density).toInt(); val left = ((w - size) / 2).toInt(); val top = (9 * density).toInt()
        icon.setBounds(left, top, left + size, top + size); icon.draw(canvas)
        val x = w / 2; val half = 2 * density; val t = trackTop(); val b = trackBottom()
        area.set(x - half, t, x + half, b); canvas.drawRoundRect(area, half, half, track)
        val y = b - (b - t) * value
        area.set(x - half, y, x + half, b); canvas.drawRoundRect(area, half, half, fill)
        canvas.drawCircle(x, y, 7 * density, fill)
    }
    @android.annotation.SuppressLint("ClickableViewAccessibility")
    override fun onTouchEvent(event: MotionEvent): Boolean {
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN, MotionEvent.ACTION_MOVE -> {
                parent?.requestDisallowInterceptTouchEvent(true)
                value = 1f - (event.y - trackTop()) / (trackBottom() - trackTop()); onChange(value)
            }
            MotionEvent.ACTION_UP -> performClick()
        }
        return true
    }
    override fun performClick(): Boolean { super.performClick(); return true }
    override fun onInitializeAccessibilityNodeInfo(info: AccessibilityNodeInfo) {
        super.onInitializeAccessibilityNodeInfo(info)
        info.className = SeekBar::class.java.name
        info.addAction(AccessibilityNodeInfo.AccessibilityAction.ACTION_SCROLL_FORWARD)
        info.addAction(AccessibilityNodeInfo.AccessibilityAction.ACTION_SCROLL_BACKWARD)
    }
    override fun performAccessibilityAction(action: Int, arguments: Bundle?): Boolean {
        val step = when (action) { AccessibilityNodeInfo.ACTION_SCROLL_FORWARD -> .1f; AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD -> -.1f; else -> return super.performAccessibilityAction(action, arguments) }
        value += step; onChange(value); return true
    }
}

/** Bottom sheet container that follows a downward drag and closes past a threshold. */
class DragSheet(context: Context, private val onDismiss: () -> Unit) : LinearLayout(context) {
    var scroller: ScrollView? = null
    private val slop = ViewConfiguration.get(context).scaledTouchSlop
    private var downY = 0f
    private var downX = 0f
    private var downTime = 0L
    private var dragging = false
    private fun atTop() = (scroller?.scrollY ?: 0) <= 0
    override fun onInterceptTouchEvent(event: MotionEvent): Boolean {
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> { downY = event.rawY; downX = event.rawX; downTime = event.eventTime; dragging = false }
            MotionEvent.ACTION_MOVE -> {
                val dy = event.rawY - downY
                if (dy > slop && dy > abs(event.rawX - downX) && atTop()) { dragging = true; return true }
            }
        }
        return false
    }
    @SuppressLint("ClickableViewAccessibility")
    override fun onTouchEvent(event: MotionEvent): Boolean {
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> { downY = event.rawY; downTime = event.eventTime; return true }
            MotionEvent.ACTION_MOVE -> { val dy = (event.rawY - downY).coerceAtLeast(0f); if (dy > slop) dragging = true; if (dragging) translationY = dy }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                val dy = event.rawY - downY
                val fast = event.eventTime - downTime < 250 && dy > slop * 3
                if (dragging && (dy > height * .25f || fast)) onDismiss() else animate().translationY(0f).setDuration(160).start()
                dragging = false
            }
        }
        return true
    }
}
