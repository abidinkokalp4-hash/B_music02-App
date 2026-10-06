package com.example.b_music02

import android.app.Activity
import android.app.AlertDialog
import android.annotation.TargetApi
import android.app.PendingIntent
import android.app.PictureInPictureParams
import android.app.RemoteAction
import android.content.BroadcastReceiver
import android.content.Context
import android.content.IntentFilter
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.drawable.Icon
import android.os.SystemClock
import android.view.accessibility.AccessibilityNodeInfo
import androidx.core.content.ContextCompat
import android.content.ComponentName
import android.content.ContentValues
import android.content.Intent
import android.content.pm.ActivityInfo
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.content.res.ColorStateList
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.util.Rational
import android.view.GestureDetector
import android.view.Gravity
import android.view.MotionEvent
import android.view.ScaleGestureDetector
import android.view.View
import android.view.WindowInsets
import android.view.WindowManager
import android.widget.*
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.Player
import androidx.media3.common.PlaybackException
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.session.MediaController
import androidx.media3.session.SessionToken
import androidx.media3.ui.PlayerView
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.transformer.*
import com.google.common.util.concurrent.ListenableFuture
import java.io.File
import java.util.concurrent.Executors
import kotlin.math.abs

/** Local-only player. YouTube stays in its official WebView player. */
@UnstableApi
class VideoActivity : Activity() {
    companion object {
        var active: VideoActivity? = null
            private set
    }
    private lateinit var root: FrameLayout
    private lateinit var display: PlayerView
    private lateinit var panel: LinearLayout
    private lateinit var heading: LinearLayout
    private lateinit var feedback: TextView
    private lateinit var preview: ImageView
    private lateinit var timeline: SeekBar
    private lateinit var clock: TextView
    private lateinit var play: ImageButton
    private lateinit var favoriteButton: ImageButton
    private lateinit var sleepButton: ImageButton
    private lateinit var speedButton: Button
    private lateinit var fullscreenButton: ImageButton
    private lateinit var brightnessSlider: VerticalSlider
    private lateinit var volumeSlider: VerticalSlider
    private var playIcon = 0
    private var sleepDeadline = 0L
    private var sleepMinutes = 0
    private val pipControl = "com.example.b_music02.PIP_CONTROL"
    private val pipReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.getIntExtra("control", 0)) { 1 -> seek(-10000); 2 -> togglePlay(); 3 -> seek(10000) }
            updatePip()
        }
    }
    private lateinit var speechButton: Button
    private lateinit var backgroundButton: Button
    private var controller: MediaController? = null
    private var future: ListenableFuture<MediaController>? = null
    private val handler = Handler(Looper.getMainLooper())
    private val frames = Executors.newSingleThreadExecutor()
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
    private var reportedProgress = false
    private var lastCheckpoint = -1L
    private var isClosing = false
    private var replacing = false
    private var locked = false
    private var zoom = 1f
    private var cover = false
    private lateinit var unlock: ImageButton
    private lateinit var sceneStrip: LinearLayout
    private lateinit var sideTools: LinearLayout
    private var scenesLoaded = false
    private var favorite = false
    private var pendingEdit: (() -> Unit)? = null
    private var gifBusy = false
    private val purple = 0xFFBC62FF.toInt()
    private fun card(radius: Float = 12f, color: Int = 0xFF17141F.toInt()) = GradientDrawable().apply {
        setColor(color); cornerRadius = dp(radius.toInt()).toFloat(); setStroke(dp(1), 0xFF49305E.toInt())
    }
    private fun rotate() { requestedOrientation = if (resources.configuration.orientation == Configuration.ORIENTATION_LANDSCAPE) ActivityInfo.SCREEN_ORIENTATION_PORTRAIT else ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE }
    private fun rateLabel(rate: Float) = "%.2f".format(java.util.Locale.US, rate).trimEnd('0').let { if (it.endsWith(".")) it + "0" else it } + "×"
    private fun speed() { val rates = floatArrayOf(.5f,.75f,1f,1.25f,1.5f,2f); AlertDialog.Builder(this).setTitle("Oynatma hızı").setItems(rates.map { rateLabel(it) }.toTypedArray()) { _, i -> controller?.setPlaybackSpeed(rates[i]); speedButton.text = rateLabel(rates[i]) }.show() }
    private fun toggleFavorite() { favorite = !favorite; updateFavorite(); message(if (favorite) "Favorilere eklendi" else "Favorilerden kaldırıldı") }
    private fun updateFavorite() {
        favoriteButton.setImageResource(if (favorite) R.drawable.bm_favorite else R.drawable.bm_favorite_border)
        favoriteButton.imageTintList = ColorStateList.valueOf(if (favorite) 0xFFFF6FB5.toInt() else Color.WHITE)
        favoriteButton.contentDescription = if (favorite) "Favorilerden çıkar" else "Favorilere ekle"
    }
    private fun togglePlay() { controller?.let { if (it.isPlaying) it.pause() else { if (it.playbackState == Player.STATE_ENDED) it.seekTo(0); it.play() } } }
    private fun sleepDialog() {
        val minutes = intArrayOf(0, 15, 30, 45, 60, 90)
        val left = ((sleepDeadline - SystemClock.elapsedRealtime()) / 60000 + 1).coerceAtLeast(1)
        AlertDialog.Builder(this).setTitle(if (sleepDeadline > 0) "Uyku zamanlayıcısı • $left dk kaldı" else "Uyku zamanlayıcısı")
            .setItems(minutes.map { if (it == 0) "Kapalı" else "$it dakika" }.toTypedArray()) { _, i -> setSleep(minutes[i]) }.show()
    }
    private fun setSleep(minutes: Int) {
        sleepMinutes = minutes
        sleepDeadline = if (minutes > 0) SystemClock.elapsedRealtime() + minutes * 60_000L else 0L
        android.util.Log.i("flutter", "[BMusic feature] sleep=$minutes")
        updateSleep()
        message(if (minutes > 0) "Video $minutes dakika sonra duraklatılacak" else "Uyku zamanlayıcısı kapatıldı")
    }
    private fun updateSleep() {
        val on = sleepDeadline > 0
        sleepButton.imageTintList = ColorStateList.valueOf(if (on) purple else Color.WHITE)
        sleepButton.contentDescription = if (on) "Uyku zamanlayıcısı: $sleepMinutes dk" else "Uyku zamanlayıcısı"
    }
    private val landscape get() = resources.configuration.orientation == Configuration.ORIENTATION_LANDSCAPE
    private fun fullscreen() { requestedOrientation = if (landscape) ActivityInfo.SCREEN_ORIENTATION_PORTRAIT else ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE }

    private val ticker = object : Runnable {
        override fun run() {
            val p = controller
            if (p != null) {
                val duration = p.duration.coerceAtLeast(0)
                if (duration > 0 && !scenesLoaded) { scenesLoaded = true; loadScenes(duration) }
                if (p.isPlaying && p.currentPosition > 1000 && !reportedProgress) {
                    reportedProgress = true
                    android.util.Log.i("flutter", "[B_music02 video] advancing position=${p.currentPosition}ms")
                }
                if (!dragging) timeline.progress = if (duration > 0) (p.currentPosition * 10000 / duration).toInt() else 0
                val label = "${time(p.currentPosition)} / ${time(duration)}"
                if (!dragging && clock.text.toString() != label) clock.text = label
                val icon = if (p.isPlaying) R.drawable.bm_pause else R.drawable.bm_play_arrow
                if (playIcon != icon) { playIcon = icon; play.setImageResource(icon) }
                if (sleepDeadline > 0 && SystemClock.elapsedRealtime() >= sleepDeadline) {
                    sleepDeadline = 0; p.pause(); updateSleep(); updatePip()
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
    private val hide = Runnable { if (controller?.isPlaying == true && !dragging && transformer == null) controls(false) }
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        active = this
        source = intent.getStringExtra("path") ?: ""
        title = intent.getStringExtra("title") ?: "Video"
        favorite = intent.getBooleanExtra("favorite", false)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
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
                        if (source.isNotEmpty() && intent.getStringExtra("path") != null) {
                            setResult(RESULT_OK, Intent().putExtra("fallback", true))
                            isClosing = true; p.pause(); p.stop(); finish()
                        } else { controls(true); message("Video oynatılamadı: ${error.errorCodeName}") }
                    }
                    override fun onIsPlayingChanged(isPlaying: Boolean) { android.util.Log.i("flutter", "[BMusic feature] native-playing=$isPlaying"); updatePip(); if (!isPlaying && !isInPictureInPictureMode) controls(true) }
                })
                if (source.isNotEmpty()) {
                    p.setMediaItem(MediaItem.Builder().setUri(Uri.fromFile(File(source)))
                        .setMediaMetadata(MediaMetadata.Builder().setTitle(title).setArtist("B Music").setArtworkData(assets.open("flutter_assets/assets/images/b_music02_logo.png").use { it.readBytes() }, MediaMetadata.PICTURE_TYPE_FRONT_COVER).build()).build(),
                        maxOf(intent.getLongExtra("position", 0),
                            getSharedPreferences("video_positions", MODE_PRIVATE).getLong(source, 0)))
                    p.prepare(); p.play()
                } else {
                    source = p.currentMediaItem?.localConfiguration?.uri?.path ?: ""
                    title = p.mediaMetadata.title?.toString() ?: "Video"
                }
                handler.post(ticker); scheduleHide()
            } catch (e: Exception) { message("Oynatıcı açılamadı: ${e.message}") }
        }, { command -> handler.post(command) })
    }
    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()
    private fun button(label: String, description: String, action: () -> Unit): Button = Button(this).apply {
        text = label; textSize = 12f; isAllCaps = false; setPadding(dp(2),0,dp(2),0); setTextColor(Color.WHITE); setBackgroundColor(Color.TRANSPARENT)
        contentDescription = description; minWidth = dp(48); minimumWidth = dp(48)
        setOnClickListener { action(); scheduleHide() }
    }
    private fun icon(res: Int, description: String, action: () -> Unit): ImageButton = ImageButton(this).apply {
        setImageResource(res); imageTintList = ColorStateList.valueOf(Color.WHITE); scaleType = ImageView.ScaleType.CENTER
        setBackgroundColor(Color.TRANSPARENT); contentDescription = description; minimumWidth = dp(48); minimumHeight = dp(48)
        setOnClickListener { action(); scheduleHide() }
    }
    private fun labeled(res: Int, label: String, description: String, tint: Int = Color.WHITE, size: Int = 22, action: () -> Unit): Button = button(label, description, action).apply {
        val image = getDrawable(res)!!.mutate(); image.setTint(tint); image.setBounds(0, 0, dp(size), dp(size))
        setCompoundDrawables(null, image, null, null); compoundDrawablePadding = dp(3); textSize = 10f; maxLines = 2
    }
    private fun buildUi() {
        root = FrameLayout(this).apply { setBackgroundColor(Color.BLACK) }
        display = PlayerView(this).apply { useController = false; setShowBuffering(PlayerView.SHOW_BUFFERING_WHEN_PLAYING) }
        root.addView(display, FrameLayout.LayoutParams(-1, -1))
        val gestures = View(this).apply { isClickable = true; elevation = dp(2).toFloat() }
        root.addView(gestures, FrameLayout.LayoutParams(-1, -1))
        heading = LinearLayout(this).apply { elevation = dp(4).toFloat(); gravity = Gravity.CENTER_VERTICAL; setBackgroundColor(0xB0000000.toInt()) }
        heading.addView(icon(R.drawable.bm_arrow_back, "Geri") { finishPlayer() })
        heading.addView(TextView(this).apply { text = title; setTextColor(Color.WHITE); textSize = 12f; maxLines = 1 }, LinearLayout.LayoutParams(0, dp(48), 1f))
        heading.addView(icon(R.drawable.bm_headphones, "Arka planda dinle") { listenInBackground = !listenInBackground; message(if (listenInBackground) "Ekran kapalı dinleme açık" else "Ekran kapalı dinleme kapalı") })
        heading.addView(icon(R.drawable.bm_more_vert, "Video araçları") { showTools() })
        root.addView(heading, FrameLayout.LayoutParams(-1, dp(52), Gravity.TOP))
        panel = LinearLayout(this).apply { elevation = dp(4).toFloat(); orientation = LinearLayout.VERTICAL; setPadding(dp(10), 0, dp(10), 0); setBackgroundColor(0xBE000000.toInt()) }
        clock = TextView(this).apply { setTextColor(Color.WHITE); text = "0:00 / 0:00" }
        timeline = SeekBar(this).apply { max = 10000; contentDescription = "Video süresi"; progressTintList = ColorStateList.valueOf(purple); thumbTintList = ColorStateList.valueOf(purple) }
        panel.addView(timeline, LinearLayout.LayoutParams(-1, dp(32)))
        panel.addView(clock, LinearLayout.LayoutParams(-1, dp(24)))
        sceneStrip = LinearLayout(this).apply { gravity = Gravity.CENTER; setPadding(0,dp(3),0,dp(3)) }
        panel.addView(sceneStrip, LinearLayout.LayoutParams(-1,dp(48)))
        val row = LinearLayout(this).apply { gravity = Gravity.CENTER }
        row.addView(icon(R.drawable.bm_repeat, "Tekrar oynat") { controller?.let { it.repeatMode = if(it.repeatMode==Player.REPEAT_MODE_ONE) Player.REPEAT_MODE_OFF else Player.REPEAT_MODE_ONE }; message("Tekrar modu değiştirildi") })
        row.addView(icon(R.drawable.bm_replay_10, "10 saniye geri") { seek(-10000) })
        play = icon(R.drawable.bm_play_arrow, "Oynat") { togglePlay(); controls(true) }.apply { background = card(32f, Color.BLACK); scaleType = ImageView.ScaleType.FIT_CENTER; setPadding(dp(12), dp(12), dp(12), dp(12)) }
        playIcon = R.drawable.bm_play_arrow
        row.addView(play)
        row.addView(icon(R.drawable.bm_forward_10, "10 saniye ileri") { seek(10000) })
        row.addView(icon(R.drawable.bm_screen_rotation, "Yatay / dikey döndür") { rotate() })
        for (index in 0 until row.childCount) row.getChildAt(index).layoutParams = LinearLayout.LayoutParams(0, dp(58), 1f).apply { setMargins(dp(3),dp(4),dp(3),dp(4)) }
        panel.addView(row, LinearLayout.LayoutParams(-1, dp(68)))
        val bottom = LinearLayout(this).apply { gravity=Gravity.CENTER; background=card(0f,0xFF09080E.toInt()) }
        fun bottomTool(res:Int,label:String,desc:String,action:()->Unit) { bottom.addView(labeled(res,label,desc,action=action),LinearLayout.LayoutParams(0,dp(58),1f)) }
        bottomTool(R.drawable.bm_lock,"Ekran Kilidi","Ekranı kilitle") { lockScreen() }
        bottomTool(R.drawable.bm_picture_in_picture_alt,"Yüzen Video","Yüzen video") { floating() }
        bottomTool(R.drawable.bm_screen_rotation,"Döndürme","Döndürme") { rotate() }
        bottomTool(R.drawable.bm_photo_camera,"Ekran Görüntüsü","Fotoğraf al") { snapshot() }
        bottomTool(R.drawable.bm_more_horiz,"Daha Fazla","Diğer araçlar") { showTools() }
        panel.addView(bottom)
        root.addView(panel, FrameLayout.LayoutParams(-1, -2, Gravity.BOTTOM))
        sideTools=LinearLayout(this).apply { orientation=LinearLayout.VERTICAL; elevation=dp(5).toFloat(); background=card(14f,0xAC08060C.toInt()) }
        // Reference rail order: favorite, sleep timer, cut, speed, PiP, fullscreen.
        favoriteButton = icon(R.drawable.bm_favorite_border, "Favorilere ekle") { toggleFavorite() }
        sleepButton = icon(R.drawable.bm_bedtime, "Uyku zamanlayıcısı") { sleepDialog() }
        speedButton = button("1.0×", "Oynatma hızı") { speed() }.apply { textSize = 11f }
        fullscreenButton = icon(R.drawable.bm_fullscreen, "Tam ekran") { fullscreen() }
        sideTools.addView(favoriteButton)
        sideTools.addView(sleepButton)
        sideTools.addView(icon(R.drawable.bm_content_cut, "Kısa klip çıkar") { clipDialog() })
        sideTools.addView(speedButton)
        sideTools.addView(icon(R.drawable.bm_picture_in_picture_alt, "Yüzen videoyu aç") { floating() })
        sideTools.addView(fullscreenButton)
        for (index in 0 until sideTools.childCount) sideTools.getChildAt(index).layoutParams = LinearLayout.LayoutParams(-1, dp(46))
        updateFavorite()
        root.addView(sideTools,FrameLayout.LayoutParams(dp(50),-2,Gravity.RIGHT or Gravity.CENTER_VERTICAL).apply { rightMargin=dp(8) })
        brightnessSlider = VerticalSlider(this, R.drawable.bm_brightness_6, purple) { level ->
            window.attributes = window.attributes.apply { screenBrightness = level.coerceIn(.02f, 1f) }
            android.util.Log.i("flutter", "[BMusic feature] brightness=${window.attributes.screenBrightness}"); scheduleHide()
        }.apply { contentDescription = "Parlaklık"; elevation = dp(5).toFloat() }
        volumeSlider = VerticalSlider(this, R.drawable.bm_volume_up, purple) { level ->
            controller?.volume = level
            android.util.Log.i("flutter", "[BMusic feature] volume=$level"); scheduleHide()
        }.apply { contentDescription = "Ses"; elevation = dp(5).toFloat() }
        root.addView(brightnessSlider, FrameLayout.LayoutParams(dp(40), dp(150), Gravity.LEFT or Gravity.CENTER_VERTICAL))
        root.addView(volumeSlider, FrameLayout.LayoutParams(dp(40), dp(150), Gravity.RIGHT or Gravity.CENTER_VERTICAL))
        feedback = TextView(this).apply { elevation = dp(8).toFloat(); textSize = 18f; setTextColor(Color.WHITE); setBackgroundColor(0xAF000000.toInt()); gravity = Gravity.CENTER; setPadding(dp(12), dp(8), dp(12), dp(8)); visibility = View.GONE }
        root.addView(feedback, FrameLayout.LayoutParams(-2, -2, Gravity.CENTER))
        preview = ImageView(this).apply { elevation = dp(8).toFloat(); scaleType = ImageView.ScaleType.FIT_CENTER; visibility = View.GONE; setBackgroundColor(Color.BLACK) }
        root.addView(preview, FrameLayout.LayoutParams(dp(180), dp(102), Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL).apply { bottomMargin = dp(145) })
        timeline.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onStartTrackingTouch(bar: SeekBar) { targetPosition = ((controller?.duration ?: 0).coerceAtLeast(0) * bar.progress / 10000); dragging = true; handler.removeCallbacks(hide) }
            override fun onProgressChanged(bar: SeekBar, progress: Int, fromUser: Boolean) {
                if (!fromUser) return
                val p = controller ?: return
                targetPosition = (p.duration.coerceAtLeast(0) * progress / 10000)
                clock.text = "${time(targetPosition)} / ${time(p.duration)}"
                requestFrame(targetPosition)
            }
            override fun onStopTrackingTouch(bar: SeekBar) { controller?.seekTo(targetPosition); dragging = false; previewGeneration++; preview.visibility = View.GONE; scheduleHide() }
        })
        unlock = icon(R.drawable.bm_lock_open, "Kilidi aç") { locked = false; unlock.visibility = View.GONE; controls(true) }.apply { visibility = View.GONE }
        root.addView(unlock, FrameLayout.LayoutParams(dp(56), dp(56), Gravity.TOP or Gravity.RIGHT))
        val scaler = ScaleGestureDetector(this, object : ScaleGestureDetector.SimpleOnScaleGestureListener() {
            override fun onScale(detector: ScaleGestureDetector): Boolean {
                zoom = (zoom * detector.scaleFactor).coerceIn(1f, 5f)
                display.scaleX = zoom; display.scaleY = zoom
                return true
            }
        })
        val detector = GestureDetector(this, object : GestureDetector.SimpleOnGestureListener() {
            override fun onDown(e: MotionEvent): Boolean = true
            override fun onSingleTapConfirmed(e: MotionEvent): Boolean { android.util.Log.i("flutter", "[BMusic feature] tap controls=$visible"); controls(!visible); scheduleHide(); return true }
            override fun onDoubleTap(e: MotionEvent): Boolean { seek(if (e.x < root.width / 2) -10000 else 10000); return true }
            override fun onLongPress(e: MotionEvent) {
                if (gestureMode != 0) return
                controller?.let { previousSpeed = it.playbackParameters.speed; hold = true; it.setPlaybackSpeed(2f); message("2× hız • Bırakınca normal hız"); android.util.Log.i("flutter", "[BMusic feature] hold=${it.playbackParameters.speed}") }
            }
        })
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
                }
                MotionEvent.ACTION_MOVE -> if (p != null && !hold) {
                    val dx = e.x - startX; val dy = e.y - startY
                    if (gestureMode == 0 && (abs(dx) > dp(18) || abs(dy) > dp(18))) {
                        gestureMode = if (abs(dx) > abs(dy)) 1 else if (startX < root.width * .3f) 2 else if (startX > root.width * .7f) 3 else 4
                    }
                    when (gestureMode) {
                        1 -> {
                            dragging = true; handler.removeCallbacks(hide)
                            val windowMs = (p.duration / 20).coerceIn(30000, 180000)
                            targetPosition = (startPosition + (dx / root.width * windowMs).toLong()).coerceIn(0, p.duration.coerceAtLeast(0))
                            val delta = (targetPosition - startPosition) / 1000
                            message("${if (delta >= 0) "+" else ""}$delta sn • ${time(targetPosition)}")
                        }
                        2 -> { val level = (startBrightness - dy / root.height * 1.5f).coerceIn(.02f, 1f); window.attributes = window.attributes.apply { screenBrightness = level }; brightnessSlider.value = level; message("Parlaklık %${(level * 100).toInt()}"); android.util.Log.i("flutter", "[BMusic feature] brightness=${window.attributes.screenBrightness}") }
                        3 -> { val level = (startVolume - dy / root.height * 1.5f).coerceIn(0f, 1f); p.volume = level; volumeSlider.value = level; message("Ses %${(level * 100).toInt()}"); android.util.Log.i("flutter", "[BMusic feature] volume=${p.volume}") }
                    }
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    if (hold) { p?.setPlaybackSpeed(previousSpeed); android.util.Log.i("flutter", "[BMusic feature] release=$previousSpeed"); hold = false; feedback.visibility = View.GONE }
                    if (gestureMode == 1 && e.actionMasked == MotionEvent.ACTION_UP) { p?.seekTo(targetPosition); android.util.Log.i("flutter", "[BMusic feature] seek=$targetPosition") }
                    dragging = false; gestureMode = 0; scheduleHide()
                }
            }
            true
        }
        setContentView(root)
        root.addOnLayoutChangeListener { _, _, _, _, _, _, _, _, _ -> root.post { positionSliders() } }
        layoutVideo()
        if (Build.VERSION.SDK_INT >= 20) root.setOnApplyWindowInsetsListener { v, insets ->
            @Suppress("DEPRECATION") v.setPadding(insets.systemWindowInsetLeft, insets.systemWindowInsetTop, insets.systemWindowInsetRight, insets.systemWindowInsetBottom)
            insets
        }
    }
    private fun controls(show: Boolean) {
        visible = show
        val pip = Build.VERSION.SDK_INT >= 24 && isInPictureInPictureMode
        fun shown(condition: Boolean) = if (show && !pip && condition) View.VISIBLE else View.GONE
        panel.visibility = shown(true); heading.visibility = panel.visibility
        // Portrait (screen 5): side rail + brightness. Landscape (screen 7): brightness left, volume right.
        sideTools.visibility = shown(!landscape)
        brightnessSlider.visibility = shown(true)
        volumeSlider.visibility = shown(landscape)
        if (show) {
            brightnessSlider.value = window.attributes.screenBrightness.takeIf { it >= 0 } ?: .5f
            volumeSlider.value = controller?.volume ?: 1f
        }
    }
    private fun lockScreen() { locked = true; controls(false); unlock.visibility = View.VISIBLE }
    private fun scheduleHide() { handler.removeCallbacks(hide); handler.postDelayed(hide, 8000) }
    private fun message(text: String) { feedback.text = text; feedback.visibility = View.VISIBLE; handler.removeCallbacks(clearFeedback); handler.postDelayed(clearFeedback, 1200) }
    private val clearFeedback = Runnable { feedback.visibility = View.GONE }
    private fun seek(delta: Long) { controller?.let { it.seekTo((it.currentPosition + delta).coerceIn(0, it.duration.coerceAtLeast(0))) }; message(if (delta < 0) "−10 saniye" else "+10 saniye") }
    private fun time(ms: Long): String { val seconds = ms.coerceAtLeast(0) / 1000; return if (seconds >= 3600) "%d:%02d:%02d".format(seconds / 3600, seconds / 60 % 60, seconds % 60) else "%d:%02d".format(seconds / 60, seconds % 60) }
    private fun showSystemBars() {
        window.clearFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN)
        @Suppress("DEPRECATION")
        window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_LAYOUT_STABLE
        @Suppress("DEPRECATION")
        window.navigationBarColor = Color.BLACK
        if (Build.VERSION.SDK_INT >= 30) {
            window.insetsController?.show(WindowInsets.Type.systemBars())
            window.insetsController?.setSystemBarsAppearance(0, android.view.WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS)
        }
        else { @Suppress("DEPRECATION") window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_LAYOUT_STABLE }
    }
    private fun applySystemBars() { if (landscape && !(Build.VERSION.SDK_INT >= 24 && isInPictureInPictureMode)) hideSystemBars() else showSystemBars() }
    private fun hideSystemBars() {
        if (Build.VERSION.SDK_INT >= 30) {
            window.insetsController?.hide(WindowInsets.Type.systemBars())
            window.insetsController?.systemBarsBehavior = android.view.WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_LAYOUT_STABLE or View.SYSTEM_UI_FLAG_FULLSCREEN or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
        }
    }
    override fun onWindowFocusChanged(hasFocus: Boolean) { super.onWindowFocusChanged(hasFocus); if (hasFocus) applySystemBars() }
    private fun requestFrame(position: Long) {
        if (source.isEmpty()) return
        pendingFramePosition = position
        if (frameBusy) return
        frameBusy = true
        val generation = previewGeneration
        frames.execute {
            val bitmap = try {
                MediaMetadataRetriever().let { r ->
                    try { r.setDataSource(source); if (Build.VERSION.SDK_INT >= 27) r.getScaledFrameAtTime(position * 1000, MediaMetadataRetriever.OPTION_CLOSEST, 320, 180) else r.getFrameAtTime(position * 1000, MediaMetadataRetriever.OPTION_CLOSEST_SYNC) }
                    finally { r.release() }
                }
            } catch (_: Exception) { null }
            handler.post {
                frameBusy = false
                if (!isDestroyed && generation == previewGeneration && dragging) {
                    preview.setImageBitmap(bitmap)
                    if (bitmap != null) android.util.Log.i("flutter", "[BMusic feature] preview=$position")
                    preview.visibility = if (bitmap != null) View.VISIBLE else View.GONE
                    val latest = pendingFramePosition
                    if (latest != null && latest != position) requestFrame(latest)
                } else bitmap?.recycle()
            }
        }
    }
    private fun showTools() {
        handler.removeCallbacks(hide)
        val content=LinearLayout(this).apply { orientation=LinearLayout.VERTICAL; setPadding(dp(12),dp(12),dp(12),dp(12)); setBackgroundColor(0xFF08060E.toInt()) }
        val grid=GridLayout(this).apply { columnCount=3 }
        content.addView(grid)
        val scroll=ScrollView(this).apply { addView(content) }
        val dialog=AlertDialog.Builder(this).setTitle("Diğer Özellikler").setView(scroll).setNegativeButton("Kapat",null).create()
        var count=0
        fun tool(icon:Int,label:String,description:String=label,action:()->Unit) {
            val colors=intArrayOf(0xFFE885E9.toInt(),0xFFFFD96C.toInt(),0xFF6DA8FF.toInt(),0xFF79DEAB.toInt(),0xFFBA93FF.toInt(),0xFF68C9EF.toInt())
            val color=colors[count++%colors.size]
            grid.addView(labeled(icon,label,description,color,26) { dialog.dismiss(); action() }.apply { background=card(); setTextColor(Color.WHITE); textSize=11f },GridLayout.LayoutParams().apply { width=0; height=dp(88); columnSpec=GridLayout.spec(GridLayout.UNDEFINED,1f); setMargins(dp(3),dp(3),dp(3),dp(3)) })
        }
        tool(R.drawable.bm_content_cut,"Video Kırpma","Kısa klip çıkar") { clipDialog() }
        tool(R.drawable.bm_gif_box,"GIF Oluşturma") { gifDialog() }
        tool(R.drawable.bm_photo_camera,"Ekran Görüntüsü","Fotoğraf al") { snapshot() }
        tool(R.drawable.bm_view_carousel,"Sahne Önizleme") { scenesDialog() }
        tool(R.drawable.bm_closed_caption,"Altyazı Desteği") { startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE).setType("*/*"),813) }
        tool(R.drawable.bm_speed,"Hız Kontrolü","Oynatma hızı") { speed() }
        tool(R.drawable.bm_info,"Video Bilgileri") { videoInfo() }
        tool(R.drawable.bm_share,"Paylaşma","Videoyu paylaş") { shareVideo() }
        tool(R.drawable.bm_drive_file_move,"Klasöre Taşıma") { editFile(false) }
        tool(R.drawable.bm_favorite,if(favorite) "Favoriden Çıkar" else "Favorilere Ekle") { toggleFavorite() }
        tool(R.drawable.bm_edit,"Yeniden Adlandır") { editFile(true) }
        tool(R.drawable.bm_delete,"Sil") { deleteVideo() }
        tool(R.drawable.bm_music_note,"Sesi Kaydet","Videonun sesini kaydet") { export(true,0,controller?.duration?.coerceAtLeast(0)?:0) }
        tool(R.drawable.bm_picture_in_picture_alt,"Yüzen Video","Yüzen video") { floating() }
        tool(R.drawable.bm_lock,"Ekran Kilidi","Ekranı kilitle") { lockScreen() }
        tool(R.drawable.bm_fit_screen,if(cover) "Ekrana sığdır" else "Ekranı doldur") { cover=!cover; display.resizeMode=if(cover) AspectRatioFrameLayout.RESIZE_MODE_ZOOM else AspectRatioFrameLayout.RESIZE_MODE_FIT }
        tool(R.drawable.bm_repeat,"Tekrar oynat") { controller?.let { it.repeatMode=if(it.repeatMode==Player.REPEAT_MODE_ONE) Player.REPEAT_MODE_OFF else Player.REPEAT_MODE_ONE } }
        tool(R.drawable.bm_zoom_out_map,"Yakınlaştırmayı sıfırla") { zoom=1f; display.scaleX=1f; display.scaleY=1f }
        speechButton=button(if(speech) "Konuşmaları belirginleştir: Açık" else "Konuşmaları belirginleştir: Kapalı","Konuşmaları belirginleştir") {
            if(VideoPlaybackService.active?.applySpeech(!speech)==true) { speech=!speech; speechButton.text=if(speech) "Konuşmaları belirginleştir: Açık" else "Konuşmaları belirginleştir: Kapalı" } else message("Bu cihazda ses efekti desteklenmiyor")
        }; content.addView(speechButton)
        backgroundButton=button(if(listenInBackground) "Ekran kapalı dinleme: Açık" else "Ekran kapalı dinleme: Kapalı","Ekran kapalı dinleme") {
            listenInBackground=!listenInBackground; backgroundButton.text=if(listenInBackground) "Ekran kapalı dinleme: Açık" else "Ekran kapalı dinleme: Kapalı"
        }; content.addView(backgroundButton)
        dialog.setOnDismissListener { scheduleHide() }; dialog.show()
    }
    private fun layoutVideo() {
        val landscape=resources.configuration.orientation==Configuration.ORIENTATION_LANDSCAPE
        display.layoutParams=FrameLayout.LayoutParams(-1,-1).apply { if(!landscape && !isInPictureInPictureMode) { topMargin=dp(52); bottomMargin=dp(230) } }
        val screenHeight=resources.configuration.screenHeightDp
        // Short landscape screens drop the scene strip so the side sliders fit above the controls.
        val compact=landscape && screenHeight<480
        if(::sceneStrip.isInitialized) { sceneStrip.layoutParams.height=dp(if(landscape) 36 else 48); sceneStrip.visibility=if(compact) View.GONE else View.VISIBLE }
        if(::brightnessSlider.isInitialized) {
            positionSliders()
            fullscreenButton.setImageResource(if(landscape) R.drawable.bm_fullscreen_exit else R.drawable.bm_fullscreen)
            fullscreenButton.contentDescription=if(landscape) "Tam ekrandan çık" else "Tam ekran"
            controls(visible)
        }
    }
    /** Centre the sliders in the free space between the header and the bottom controls. */
    private fun positionSliders() {
        if(!::brightnessSlider.isInitialized || root.height==0) return
        val landscape=resources.configuration.orientation==Configuration.ORIENTATION_LANDSCAPE
        val compact=landscape && resources.configuration.screenHeightDp<480
        val top=dp(52); val bottom=if(panel.height>0) panel.height else dp(if(landscape) (if(compact) 182 else 218) else 230)
        val available=root.height-root.paddingTop-root.paddingBottom-top-bottom
        val height=(available-dp(16)).coerceIn(dp(96),dp(180))
        val offset=top+((available-height)/2).coerceAtLeast(0)
        for(slider in listOf(brightnessSlider,volumeSlider)) {
            val params=FrameLayout.LayoutParams(dp(40),height,(if(slider===brightnessSlider) Gravity.LEFT else Gravity.RIGHT) or Gravity.TOP).apply { topMargin=offset; leftMargin=dp(12); rightMargin=dp(12) }
            val old=slider.layoutParams as? FrameLayout.LayoutParams
            if(old==null || old.height!=params.height || old.topMargin!=params.topMargin || old.gravity!=params.gravity) slider.layoutParams=params
        }
    }
    override fun onConfigurationChanged(newConfig:Configuration) { super.onConfigurationChanged(newConfig); layoutVideo(); applySystemBars() }
    private fun loadScenes(duration:Long) {
        if(source.isEmpty()) return
        val path=source
        frames.execute {
            val r=MediaMetadataRetriever()
            try {
                r.setDataSource(path)
                for(i in 0..5) {
                    val at=duration*i/6
                    val frame=if(Build.VERSION.SDK_INT>=27) r.getScaledFrameAtTime(at*1000,MediaMetadataRetriever.OPTION_CLOSEST_SYNC,160,90) else r.getFrameAtTime(at*1000,MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                    handler.post { if(!isDestroyed && frame!=null) sceneStrip.addView(ImageView(this).apply { setImageBitmap(frame); scaleType=ImageView.ScaleType.CENTER_CROP; contentDescription="Sahne ${time(at)}"; setOnClickListener { controller?.seekTo(at); controls(true) } },LinearLayout.LayoutParams(0,-1,1f).apply { setMargins(dp(2),0,dp(2),0) }) }
                }
            } catch(_:Exception) { } finally { r.release() }
        }
    }
    private fun scenesDialog() { controls(true); message("Alttaki sahnelere dokunarak o ana git") }
    private fun videoInfo() {
        val p=controller
        AlertDialog.Builder(this).setTitle("Video Bilgileri").setMessage("$title\n\nSüre: ${time(p?.duration?:0)}\nÇözünürlük: ${p?.videoSize?.width?:0} × ${p?.videoSize?.height?:0}\nBoyut: ${"%.1f".format(File(source).length()/1048576.0)} MB\n\n$source").setPositiveButton("Tamam",null).show()
    }
    private fun mediaUri():Uri? {
        var uri:Uri?=null
        contentResolver.query(MediaStore.Video.Media.EXTERNAL_CONTENT_URI,arrayOf("_id"),"_data = ?",arrayOf(source),null)?.use { if(it.moveToFirst()) uri=android.content.ContentUris.withAppendedId(MediaStore.Video.Media.EXTERNAL_CONTENT_URI,it.getLong(0)) }
        return uri
    }
    private fun editFile(rename:Boolean) {
        val field=EditText(this).apply { setSingleLine(); setText(if(rename) File(source).nameWithoutExtension else "BMusic") }
        AlertDialog.Builder(this).setTitle(if(rename) "Yeniden Adlandır" else "Movies içindeki klasöre taşı").setView(field).setNegativeButton("İptal",null).setPositiveButton("Kaydet") { _,_ ->
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
        try { action() }
        catch(e:SecurityException) {
            pendingEdit=action
            if(Build.VERSION.SDK_INT>=30) startIntentSenderForResult(MediaStore.createWriteRequest(contentResolver,listOf(uri)).intentSender,814,null,0,0,0)
            else if(Build.VERSION.SDK_INT>=29 && e is android.app.RecoverableSecurityException) startIntentSenderForResult(e.userAction.actionIntent.intentSender,814,null,0,0,0)
            else { pendingEdit=null; message("Dosyayı değiştirme izni yok") }
        } catch(e:Exception) { message("Dosya güncellenemedi: ${e.message}") }
    }
    private fun deleteVideo() {
        AlertDialog.Builder(this).setTitle("Video silinsin mi?").setMessage(title).setNegativeButton("İptal",null).setPositiveButton("Sil") { _,_ ->
            val uri=mediaUri() ?: return@setPositiveButton
            if(Build.VERSION.SDK_INT>=30) startIntentSenderForResult(MediaStore.createDeleteRequest(contentResolver,listOf(uri)).intentSender,815,null,0,0,0)
            else runEdit(uri) { contentResolver.delete(uri,null,null); finishPlayer() }
        }.show()
    }
    private fun gifDialog() {
        if(gifBusy) { message("GIF hazırlanıyor"); return }
        // AlertDialog hides setItems() when a message is set, so the hint lives in the title.
        AlertDialog.Builder(this).setTitle("GIF Oluşturma • bu andan itibaren (320 px, 6 kare/sn)").setItems(arrayOf("3 saniye","5 saniye","10 saniye")) { _,which ->
            val p=controller?:return@setItems
            val start=p.currentPosition; val end=(start+longArrayOf(3000,5000,10000)[which]).coerceAtMost(p.duration)
            if(end<=start) return@setItems
            gifBusy=true; val file=File(cacheDir,"BMusic_${System.currentTimeMillis()}.gif"); output=file
            exportDialog=AlertDialog.Builder(this).setTitle("GIF hazırlanıyor").setView(ProgressBar(this)).setCancelable(false).create(); exportDialog?.show()
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
        AlertDialog.Builder(this).setTitle("Kısa klip çıkar").setView(content)
            .setNegativeButton("İptal", null).setNeutralButton("Önizle") { _, _ -> p.seekTo(clipStart); clipPreviewEnd = clipEnd; p.play() }
            .setPositiveButton("Kaydet") { _, _ -> export(false, clipStart, clipEnd) }.show()
    }
    private fun export(audioOnly: Boolean, start: Long, end: Long) {
        if (transformer != null || source.isEmpty() || end <= start) { message("Geçerli bir aralık seçin"); return }
        val file = File(cacheDir, "BMusic_${if (audioOnly) "Ses" else "Klip"}_${System.currentTimeMillis()}.${if (audioOnly) "m4a" else "mp4"}")
        output = file
        val progress = ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply { max = 100 }
        exportDialog = AlertDialog.Builder(this).setTitle(if (audioOnly) "Ses kaydediliyor" else "Klip hazırlanıyor")
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
        if(requestCode==815) { if(resultCode==RESULT_OK) finishPlayer(); return }
        if(requestCode==814) { val action=pendingEdit; pendingEdit=null; if(resultCode==RESULT_OK) try { action?.invoke() } catch(e:Exception) { message("İşlem tamamlanamadı: ${e.message}") }; return }
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
        setResult(RESULT_OK, Intent().putExtra("position", p?.currentPosition ?: 0)
            .putExtra("duration", p?.duration?.coerceAtLeast(0) ?: 0).putExtra("favorite", favorite))
        p?.pause()
        finish()
    }
    private fun finishPlayer() {
        if (transformer != null) { AlertDialog.Builder(this).setMessage("Devam eden işlemi iptal edip çıkılsın mı?").setNegativeButton("Devam et", null).setPositiveButton("Çık") { _, _ -> transformer?.cancel(); transformer = null; output?.delete(); finishPlayer() }.show(); return }
        isClosing = true
        val p = controller
        if (source.isNotEmpty() && p != null) {
            val position = if (p.duration - p.currentPosition <= 3000) 0 else p.currentPosition
            getSharedPreferences("video_positions", MODE_PRIVATE).edit().putLong(source, position).apply()
        }
        setResult(RESULT_OK, Intent().putExtra("position", p?.currentPosition ?: 0).putExtra("duration", p?.duration?.coerceAtLeast(0) ?: 0).putExtra("favorite", favorite))
        p?.pause(); p?.stop(); finish()
    }
    @Deprecated("Back callback") override fun onBackPressed() { if (locked) { locked = false; unlock.visibility = View.GONE; controls(true) } else finishPlayer() }
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
        handler.removeCallbacksAndMessages(null); previewGeneration++
        transformer?.cancel(); exportDialog?.dismiss(); output?.delete()
        display.player = null
        future?.let { MediaController.releaseFuture(it) }
        frames.shutdown()
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
