package com.example.b_music02

import android.app.Activity
import android.app.AlertDialog
import android.app.PictureInPictureParams
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
    private lateinit var play: Button
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
    private lateinit var unlock: Button
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
    private fun speed() { val rates = floatArrayOf(.5f,.75f,1f,1.25f,1.5f,2f); AlertDialog.Builder(this).setTitle("Oynatma hızı").setItems(rates.map { "$it×" }.toTypedArray()) { _, i -> controller?.setPlaybackSpeed(rates[i]) }.show() }
    private fun toggleFavorite() { favorite = !favorite; message(if (favorite) "Favorilere eklendi" else "Favorilerden kaldırıldı") }

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
                val playLabel = if (p.isPlaying) "Ⅱ" else "▶"
                if (play.text.toString() != playLabel) play.text = playLabel
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
        showSystemBars()
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
                    override fun onIsPlayingChanged(isPlaying: Boolean) { android.util.Log.i("flutter", "[BMusic feature] native-playing=$isPlaying"); if (!isPlaying) controls(true) }
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
    private fun buildUi() {
        root = FrameLayout(this).apply { setBackgroundColor(Color.BLACK) }
        display = PlayerView(this).apply { useController = false; setShowBuffering(PlayerView.SHOW_BUFFERING_WHEN_PLAYING) }
        root.addView(display, FrameLayout.LayoutParams(-1, -1))
        val gestures = View(this).apply { isClickable = true; elevation = dp(2).toFloat() }
        root.addView(gestures, FrameLayout.LayoutParams(-1, -1))
        heading = LinearLayout(this).apply { elevation = dp(4).toFloat(); gravity = Gravity.CENTER_VERTICAL; setBackgroundColor(0xB0000000.toInt()) }
        heading.addView(button("‹", "Geri") { finishPlayer() })
        heading.addView(TextView(this).apply { text = title; setTextColor(Color.WHITE); textSize = 12f; maxLines = 1 }, LinearLayout.LayoutParams(0, dp(48), 1f))
        heading.addView(button("♫", "Arka planda dinle") { listenInBackground = !listenInBackground; message(if (listenInBackground) "Ekran kapalı dinleme açık" else "Ekran kapalı dinleme kapalı") })
        heading.addView(button("⋮", "Video araçları") { showTools() })
        root.addView(heading, FrameLayout.LayoutParams(-1, dp(52), Gravity.TOP))
        panel = LinearLayout(this).apply { elevation = dp(4).toFloat(); orientation = LinearLayout.VERTICAL; setPadding(dp(10), 0, dp(10), 0); setBackgroundColor(0xBE000000.toInt()) }
        clock = TextView(this).apply { setTextColor(Color.WHITE); text = "0:00 / 0:00" }
        timeline = SeekBar(this).apply { max = 10000; contentDescription = "Video süresi"; progressTintList = ColorStateList.valueOf(purple); thumbTintList = ColorStateList.valueOf(purple) }
        panel.addView(timeline, LinearLayout.LayoutParams(-1, dp(32)))
        panel.addView(clock, LinearLayout.LayoutParams(-1, dp(24)))
        sceneStrip = LinearLayout(this).apply { gravity = Gravity.CENTER; setPadding(0,dp(3),0,dp(3)) }
        panel.addView(sceneStrip, LinearLayout.LayoutParams(-1,dp(48)))
        val row = LinearLayout(this).apply { gravity = Gravity.CENTER }
        row.addView(button("↺", "Tekrar oynat") { controller?.let { it.repeatMode = if(it.repeatMode==Player.REPEAT_MODE_ONE) Player.REPEAT_MODE_OFF else Player.REPEAT_MODE_ONE }; message("Tekrar modu değiştirildi") })
        row.addView(button("↶10", "10 saniye geri") { seek(-10000) })
        play = button("▶", "Oynat") { controller?.let { if (it.isPlaying) it.pause() else { if (it.playbackState == Player.STATE_ENDED) it.seekTo(0); it.play() } }; controls(true) }.apply { textSize=30f; background=card(32,Color.BLACK) }
        row.addView(play)
        row.addView(button("10↷", "10 saniye ileri") { seek(10000) })
        row.addView(button("⛶", "Yatay / dikey döndür") { rotate() })
        for (index in 0 until row.childCount) row.getChildAt(index).layoutParams = LinearLayout.LayoutParams(0, dp(58), 1f).apply { setMargins(dp(3),dp(4),dp(3),dp(4)) }
        panel.addView(row, LinearLayout.LayoutParams(-1, dp(68)))
        val bottom = LinearLayout(this).apply { gravity=Gravity.CENTER; background=card(0,0xFF09080E.toInt()) }
        fun bottomTool(label:String,desc:String,action:()->Unit) { bottom.addView(button(label,desc,action),LinearLayout.LayoutParams(0,dp(58),1f)) }
        bottomTool("♙\nEkran Kilidi","Ekranı kilitle") { locked=true; controls(false); unlock.visibility=View.VISIBLE }
        bottomTool("▣\nYüzen Video","Yüzen video") { floating() }
        bottomTool("↻\nDöndürme","Döndürme") { rotate() }
        bottomTool("▧\nEkran Görüntüsü","Fotoğraf al") { snapshot() }
        bottomTool("•••\nDaha Fazla","Diğer araçlar") { showTools() }
        panel.addView(bottom)
        root.addView(panel, FrameLayout.LayoutParams(-1, -2, Gravity.BOTTOM))
        sideTools=LinearLayout(this).apply { orientation=LinearLayout.VERTICAL; elevation=dp(5).toFloat(); background=card(14,0xAC08060C.toInt()) }
        sideTools.addView(button("♡","Favorilere ekle") { toggleFavorite() })
        sideTools.addView(button("✂","Kısa klip çıkar") { clipDialog() })
        sideTools.addView(button("1.0×","Oynatma hızı") { speed() })
        sideTools.addView(button("◉","Sesi aç / kapat") { controller?.let { it.volume=if(it.volume>0) 0f else 1f } })
        root.addView(sideTools,FrameLayout.LayoutParams(dp(50),-2,Gravity.RIGHT or Gravity.CENTER_VERTICAL).apply { rightMargin=dp(8) })
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
        unlock = button("🔒", "Kilidi aç") { locked = false; unlock.visibility = View.GONE; controls(true) }.apply { visibility = View.GONE }
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
                        2 -> { val level = (startBrightness - dy / root.height * 1.5f).coerceIn(.02f, 1f); window.attributes = window.attributes.apply { screenBrightness = level }; message("Parlaklık %${(level * 100).toInt()}"); android.util.Log.i("flutter", "[BMusic feature] brightness=${window.attributes.screenBrightness}") }
                        3 -> { val level = (startVolume - dy / root.height * 1.5f).coerceIn(0f, 1f); p.volume = level; message("Ses %${(level * 100).toInt()}"); android.util.Log.i("flutter", "[BMusic feature] volume=${p.volume}") }
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
        layoutVideo()
        if (Build.VERSION.SDK_INT >= 20) root.setOnApplyWindowInsetsListener { v, insets ->
            @Suppress("DEPRECATION") v.setPadding(insets.systemWindowInsetLeft, insets.systemWindowInsetTop, insets.systemWindowInsetRight, insets.systemWindowInsetBottom)
            insets
        }
    }
    private fun controls(show: Boolean) { visible = show; panel.visibility = if (show) View.VISIBLE else View.GONE; heading.visibility = panel.visibility; sideTools.visibility=panel.visibility }
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
    override fun onWindowFocusChanged(hasFocus: Boolean) { super.onWindowFocusChanged(hasFocus); if (hasFocus) showSystemBars() }
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
        fun tool(icon:String,label:String,description:String=label,action:()->Unit) {
            val colors=intArrayOf(0xFFE885E9.toInt(),0xFFFFD96C.toInt(),0xFF6DA8FF.toInt(),0xFF79DEAB.toInt(),0xFFBA93FF.toInt(),0xFF68C9EF.toInt())
            grid.addView(button("$icon\n$label",description) { dialog.dismiss(); action() }.apply { background=card(); setTextColor(colors[count++%colors.size]); textSize=11f },GridLayout.LayoutParams().apply { width=0; height=dp(88); columnSpec=GridLayout.spec(GridLayout.UNDEFINED,1f); setMargins(dp(3),dp(3),dp(3),dp(3)) })
        }
        tool("✂","Video Kırpma","Kısa klip çıkar") { clipDialog() }
        tool("▣","GIF Oluşturma") { gifDialog() }
        tool("▧","Ekran Görüntüsü","Fotoğraf al") { snapshot() }
        tool("◈","Sahne Önizleme") { scenesDialog() }
        tool("CC","Altyazı Desteği") { startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE).setType("*/*"),813) }
        tool("2×","Hız Kontrolü","Oynatma hızı") { speed() }
        tool("ⓘ","Video Bilgileri") { videoInfo() }
        tool("↗","Paylaşma","Videoyu paylaş") { shareVideo() }
        tool("▰","Klasöre Taşıma") { editFile(false) }
        tool("♥",if(favorite) "Favoriden Çıkar" else "Favorilere Ekle") { toggleFavorite() }
        tool("✎","Yeniden Adlandır") { editFile(true) }
        tool("×","Sil") { deleteVideo() }
        tool("♫","Sesi Kaydet","Videonun sesini kaydet") { export(true,0,controller?.duration?.coerceAtLeast(0)?:0) }
        tool("▣","Yüzen Video","Yüzen video") { floating() }
        tool("♙","Ekran Kilidi","Ekranı kilitle") { locked=true; controls(false); unlock.visibility=View.VISIBLE }
        tool("⛶",if(cover) "Ekrana sığdır" else "Ekranı doldur") { cover=!cover; display.resizeMode=if(cover) AspectRatioFrameLayout.RESIZE_MODE_ZOOM else AspectRatioFrameLayout.RESIZE_MODE_FIT }
        tool("↺","Tekrar oynat") { controller?.let { it.repeatMode=if(it.repeatMode==Player.REPEAT_MODE_ONE) Player.REPEAT_MODE_OFF else Player.REPEAT_MODE_ONE } }
        tool("⌕","Yakınlaştırmayı sıfırla") { zoom=1f; display.scaleX=1f; display.scaleY=1f }
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
        if(::sceneStrip.isInitialized) sceneStrip.layoutParams.height=dp(if(landscape) 36 else 48)
    }
    override fun onConfigurationChanged(newConfig:Configuration) { super.onConfigurationChanged(newConfig); layoutVideo() }
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
        AlertDialog.Builder(this).setTitle("GIF Oluşturma").setMessage("Bulunduğun andan itibaren kaç saniye kaydedilsin? (320 px, 6 kare/sn)").setItems(arrayOf("3 saniye","5 saniye","10 saniye")) { _,which ->
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
            val size = controller?.videoSize
            val ratio = if (size != null && size.width > 0 && size.height > 0) (size.width.toFloat() / size.height).coerceIn(.42f, 2.38f) else 16f / 9
            val ok = enterPictureInPictureMode(PictureInPictureParams.Builder().setAspectRatio(Rational((ratio * 1000).toInt(), 1000)).build())
            if (!ok) { controls(true); message("Yüzen video iznini telefon ayarlarından açın") }
        } catch (_: Exception) { controls(true); message("Yüzen video iznini telefon ayarlarından açın") }
    }
    override fun onPictureInPictureModeChanged(inPictureInPictureMode: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(inPictureInPictureMode, newConfig)
        controls(!inPictureInPictureMode)
        layoutVideo()
        if (!inPictureInPictureMode && !isFinishing) showSystemBars()
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
        handler.removeCallbacksAndMessages(null); previewGeneration++
        transformer?.cancel(); exportDialog?.dismiss(); output?.delete()
        display.player = null
        future?.let { MediaController.releaseFuture(it) }
        frames.shutdown()
        if (isClosing) stopService(Intent(this, VideoPlaybackService::class.java))
        super.onDestroy()
    }
}
