package com.bmusic.app

import android.app.Activity
import android.content.Intent
import android.content.ComponentName
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private var pending: MethodChannel.Result? = null
    private var backup: String? = null
    private var mediaCopy: String? = null
    private var deviceChannel: MethodChannel? = null
    private var incoming: Map<String, String>? = null
    private var tappedAnnouncement: String? = null
    private fun receiveAnnouncement(intent: Intent?) {
        val id = intent?.getStringExtra(Announcements.EXTRA) ?: return
        val source = intent.getStringExtra(Announcements.EXTRA_SOURCE) ?: "github"
        intent.removeExtra(Announcements.EXTRA); intent.removeExtra(Announcements.EXTRA_SOURCE)
        tappedAnnouncement = id
        android.util.Log.i("flutter", "[BMusic feature] announcement-opened id=$id source=$source")
        Analytics.notificationOpen(this, id, source)
        deviceChannel?.invokeMethod("announcementTapped", id)
    }
    private val worker = java.util.concurrent.Executors.newSingleThreadExecutor()
    private fun receiveMedia(intent: Intent?) {
        if (intent?.action != Intent.ACTION_VIEW) return
        val uri = intent.data ?: return
        if (uri.scheme != "content" && uri.scheme != "file") return
        var title = uri.lastPathSegment ?: "Medya"
        if (uri.scheme == "content") try {
            contentResolver.query(uri, arrayOf(android.provider.OpenableColumns.DISPLAY_NAME), null, null, null)?.use {
                if (it.moveToFirst()) title = it.getString(0)
            }
            if ((intent.flags and Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION) != 0)
                contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        } catch (_: Exception) { }
        incoming = mapOf("uri" to uri.toString(), "title" to title,
            "mime" to (intent.type ?: contentResolver.getType(uri) ?: ""))
        deviceChannel?.invokeMethod("mediaAvailable", null)
    }
    // Media URIs belong to receiveMedia; never send them to Flutter named routes.
    override fun shouldHandleDeeplinking(): Boolean = false
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(if (intent.action == Intent.ACTION_VIEW) Intent(intent).setData(null) else intent)
        setIntent(intent)
        receiveMedia(intent)
        receiveAnnouncement(intent)
    }
    private var videoFullscreen = false
    private val videoResults = mutableMapOf<Int, MethodChannel.Result>()
    private var nextVideoRequest = 811
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState); hideNavigation()
        if (savedInstanceState == null) { receiveMedia(intent); receiveAnnouncement(intent) }
        try { Announcements.schedule(this) } catch (e: Exception) { android.util.Log.w("flutter", "announcement schedule failed: ${e.message}") }
        try { Announcements.ensureChannel(this); Push.sync(this) } catch (e: Throwable) { android.util.Log.w("flutter", "push setup failed: ${e.message}") }
    }
    override fun onDestroy() {
        Announcements.listener = null
        super.onDestroy()
    }
    override fun onWindowFocusChanged(hasFocus: Boolean) { super.onWindowFocusChanged(hasFocus); if (hasFocus) hideNavigation() }
    private fun hideNavigation() {
        // Dark navigation bar with light buttons on every Flutter screen.
        window.navigationBarColor = 0xFF030305.toInt()
        if (Build.VERSION.SDK_INT >= 28) window.navigationBarDividerColor = 0xFF030305.toInt()
        if (Build.VERSION.SDK_INT >= 30) {
            window.insetsController?.setSystemBarsAppearance(0, WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS)
            window.insetsController?.show(WindowInsets.Type.systemBars())
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_LAYOUT_STABLE
        }
    }
    private fun alarmState(): Map<String, Any> {
        val notifications = androidx.core.app.NotificationManagerCompat.from(this).areNotificationsEnabled()
        val fullScreen = Build.VERSION.SDK_INT < 34 || getSystemService(android.app.NotificationManager::class.java).canUseFullScreenIntent()
        return mapOf("exact" to AlarmScheduler.canExact(this), "notifications" to notifications, "fullScreen" to fullScreen)
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        deviceChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "b_music02/device")
        Announcements.listener = { runOnUiThread { deviceChannel?.invokeMethod("announcementsChanged", null) } }
        deviceChannel!!.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "announcementsCheck" -> worker.execute {
                        val state = try { Announcements.check(applicationContext) } catch (e: Exception) { Announcements.state(applicationContext) }
                        runOnUiThread { result.success(state) }
                    }
                    "announcementsState" -> result.success(Announcements.state(this))
                    "announcementsEnable" -> { Announcements.setEnabled(this, call.arguments as? Boolean ?: true); result.success(null) }
                    "announcementTap" -> { result.success(tappedAnnouncement); tappedAnnouncement = null }
                    "announcementsPushed" -> {
                        // A push whose notification Android showed itself (FCM notification payload, e.g. sent
                        // from the Firebase console) and which the user tapped: remember it, never re-notify.
                        val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
                        val data = args.entries.associate { "${it.key}" to it.value?.toString() }
                        val item = AnnouncementLogic.fromPush(data, (args["sentTime"] as? Number)?.toLong() ?: 0L, data["messageId"])
                        if (item != null) Announcements.receivePush(applicationContext, item, notify = false)
                        result.success(item?.id)
                    }
                    "videoSizes" -> {
                        Thread {
                            try {
                                val sizes = mutableMapOf<String, Long>()
                                contentResolver.query(android.provider.MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
                                    arrayOf("_id", "_size"), null, null, null)?.use { cursor ->
                                    while (cursor.moveToNext()) sizes[cursor.getLong(0).toString()] = cursor.getLong(1)
                                }
                                runOnUiThread { result.success(sizes) }
                            } catch (e: Exception) { runOnUiThread { result.error("metadata", e.message, null) } }
                        }.start()
                    }
                    "openVideo" -> {
                        val previous = VideoActivity.active
                        if (videoResults.isNotEmpty() && !(Build.VERSION.SDK_INT >= 26 &&
                                previous?.isInPictureInPictureMode == true)) {
                            result.error("busy", "Video zaten açık", null)
                        } else {
                            // Finish the pinned window without stopping the shared playback
                            // service. Its original result must not complete the new request.
                            if (previous != null && videoResults.isNotEmpty()) previous.closeForReplacement()
                            val values = call.arguments as Map<*, *>
                            val request = nextVideoRequest++
                            videoResults[request] = result
                            try {
                                val launch = Intent(this, VideoActivity::class.java)
                                    .putExtra("path", values["path"] as String)
                                    .putExtra("title", values["title"] as String)
                                    .putExtra("favorite", values["favorite"] as? Boolean ?: false)
                                    .putExtra("position", (values["position"] as Number).toLong())
                                // Reels: the list the video was tapped in, for vertical swiping.
                                val playlist = (values["playlist"] as? List<*>)?.mapNotNull { it as? Map<*, *> }
                                if (playlist != null && playlist.size > 1) {
                                    launch.putStringArrayListExtra("ids", ArrayList(playlist.map { it["id"].toString() }))
                                        .putStringArrayListExtra("titles", ArrayList(playlist.map { it["title"]?.toString() ?: "Video" }))
                                        .putExtra("favorites", playlist.map { it["favorite"] == true }.toBooleanArray())
                                        .putExtra("positions", playlist.map { (it["position"] as? Number)?.toLong() ?: 0L }.toLongArray())
                                        .putExtra("index", (values["index"] as? Number)?.toInt() ?: 0)
                                }
                                startActivityForResult(launch, request)
                            } catch (e: Exception) { videoResults.remove(request); throw e }
                        }
                    }
                    "isEmulator" -> result.success(Build.FINGERPRINT.startsWith("generic") ||
                        Build.FINGERPRINT.startsWith("unknown") || Build.MODEL.contains("google_sdk") ||
                        Build.MODEL.contains("Emulator") || Build.MODEL.contains("Android SDK built for") ||
                        Build.HARDWARE.contains("goldfish") || Build.HARDWARE.contains("ranchu"))
                    "takeMedia" -> { result.success(incoming); incoming = null }
                    "shareUri" -> {
                        val args = call.arguments as Map<*, *>
                        val uri = Uri.parse(args["uri"] as String)
                        val share = Intent(Intent.ACTION_SEND).setType(contentResolver.getType(uri) ?: "video/*")
                            .putExtra(Intent.EXTRA_STREAM, uri).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        share.clipData = android.content.ClipData.newRawUri("Video", uri)
                        startActivity(Intent.createChooser(share, "Videoyu paylaş"))
                        result.success(null)
                    }
                    "pickSubtitle", "saveMediaCopy" -> {
                        if (pending != null) result.error("busy", "Dosya seçici zaten açık", null)
                        else {
                            pending = result
                            if (call.method == "pickSubtitle") {
                                startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE)
                                    .setType("*/*").addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION), 703)
                            } else {
                                val args = call.arguments as Map<*, *>
                                mediaCopy = args["path"] as String
                                startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE)
                                    .setType("audio/*").putExtra(Intent.EXTRA_TITLE, args["title"] as String), 704)
                            }
                        }
                    }
                    "saveFrame" -> {
                        val bytes = call.arguments as ByteArray
                        worker.execute {
                            var uri: Uri? = null
                            try {
                                val values = android.content.ContentValues().apply {
                                    put(android.provider.MediaStore.Images.Media.DISPLAY_NAME, "BMusic_" + System.currentTimeMillis() + ".png")
                                    put(android.provider.MediaStore.Images.Media.MIME_TYPE, "image/png")
                                    if (Build.VERSION.SDK_INT >= 29) {
                                        put(android.provider.MediaStore.Images.Media.RELATIVE_PATH, "Pictures/BMusic")
                                        put(android.provider.MediaStore.Images.Media.IS_PENDING, 1)
                                    }
                                }
                                uri = contentResolver.insert(android.provider.MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
                                    ?: throw IllegalStateException("Galeriye yazılamadı")
                                contentResolver.openOutputStream(uri!!)?.use { it.write(bytes) }
                                    ?: throw IllegalStateException("Fotoğraf kaydedilemedi")
                                if (Build.VERSION.SDK_INT >= 29) contentResolver.update(uri!!, android.content.ContentValues().apply {
                                    put(android.provider.MediaStore.Images.Media.IS_PENDING, 0)
                                }, null, null)
                                runOnUiThread { result.success(null) }
                            } catch (e: Exception) {
                                uri?.let { contentResolver.delete(it, null, null) }
                                runOnUiThread { result.error("frame", e.message, null) }
                            }
                        }
                    }
                    "videoFullscreen" -> {
                        videoFullscreen = call.arguments == true
                        if (videoFullscreen) window.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        else window.clearFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        hideNavigation(); result.success(null)
                    }
                    "immersive" -> { hideNavigation(); result.success(null) }
                    "brightness" -> result.success(window.attributes.screenBrightness.toDouble())
                    "setBrightness" -> {
                        val level = (call.arguments as? Number)?.toFloat() ?: -1f
                        window.attributes = window.attributes.apply { screenBrightness = if (level < 0) -1f else level.coerceIn(.02f, 1f) }
                        android.util.Log.i("flutter", "[BMusic feature] flutter-brightness=${window.attributes.screenBrightness}")
                        result.success(null)
                    }
                    "trimVideo" -> {
                        val args = call.arguments as Map<*, *>
                        VideoTrimmer.trim(this, args["path"] as String, (args["start"] as Number).toLong(), (args["end"] as Number).toLong()) { name, error ->
                            if (name != null) result.success(name) else result.error("trim", error, null)
                        }
                    }
                    "updateWidget" -> {
                        val values = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                        MusicWidgetProvider.save(this, values)
                        result.success(null)
                    }
                    "pinWidget" -> {
                        val manager = android.appwidget.AppWidgetManager.getInstance(this)
                        result.success(Build.VERSION.SDK_INT >= 26 &&
                            manager.isRequestPinAppWidgetSupported &&
                            manager.requestPinAppWidget(ComponentName(this, MusicWidgetProvider::class.java), null, null))
                    }
                    "info" -> {
                        val p = packageManager.getPackageInfo(packageName, 0)
                        val power = getSystemService(POWER_SERVICE) as PowerManager
                        result.success(mapOf("sdk" to Build.VERSION.SDK_INT, "version" to p.versionName, "build" to if (Build.VERSION.SDK_INT >= 28) p.longVersionCode else @Suppress("DEPRECATION") p.versionCode.toLong(), "model" to "${Build.MANUFACTURER} ${Build.MODEL}".trim(), "batteryUnrestricted" to power.isIgnoringBatteryOptimizations(packageName)))
                    }
                    "icon" -> {
                        val selected = call.arguments as? String ?: "Purple"
                        val colors = listOf("Purple", "Blue", "Pink")
                        require(selected in colors)
                        packageManager.setComponentEnabledSetting(ComponentName(this, "$packageName.Icon$selected"), PackageManager.COMPONENT_ENABLED_STATE_ENABLED, PackageManager.DONT_KILL_APP)
                        colors.filter { it != selected }.forEach { name ->
                            packageManager.setComponentEnabledSetting(ComponentName(this, "$packageName.Icon$name"), PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP)
                        }
                        result.success(null)
                    }
                    "settings" -> {
                        val action = when(call.arguments as? String) {
                            "notification", "lock" -> Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                            "battery" -> Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                            else -> Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
                        }
                        startActivity(action); result.success(null)
                    }
                    "alarmsGet" -> result.success(AlarmScheduler.raw(this))
                    "alarmsSave" -> { AlarmScheduler.save(this, call.arguments as String); result.success(alarmState()) }
                    "alarmState" -> result.success(alarmState())
                    "alarmPermission" -> {
                        when (call.arguments as? String) {
                            "exact" -> if (Build.VERSION.SDK_INT >= 31) startActivity(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:$packageName")))
                            "fullScreen" -> if (Build.VERSION.SDK_INT >= 34) startActivity(Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, Uri.parse("package:$packageName")))
                            else -> startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName))
                        }
                        result.success(null)
                    }
                    "updateInfo" -> result.success(mapOf("installer" to AppUpdate.installer(this), "fromPlay" to AppUpdate.fromPlay(this),
                        "canInstall" to AppUpdate.canInstall(this), "dir" to AppUpdate.updateDir(this).absolutePath))
                    "installUpdate" -> result.success(AppUpdate.install(this, call.arguments as String))
                    "exportBackup", "importBackup" -> {
                        if (pending != null) { result.error("busy", "Dosya seçici zaten açık", null) }
                        else {
                            pending = result
                            if (call.method == "exportBackup") {
                                backup = call.arguments as String
                                startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE).setType("application/json").putExtra(Intent.EXTRA_TITLE, "BMusic-yedek.json"), 701)
                            } else startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE).setType("application/json"), 702)
                        }
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) { pending = null; result.error("device", e.message, null) }
        }
    }
    @Deprecated("Activity document callback")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode >= 811) {
            val reply = mutableMapOf<String, Any?>("fallback" to (data?.getBooleanExtra("fallback", false) ?: false), "position" to (data?.getLongExtra("position", 0) ?: 0),
                "favorite" to data?.getBooleanExtra("favorite", false),
                "duration" to (data?.getLongExtra("duration", 0) ?: 0),
                "index" to (data?.getIntExtra("index", 0) ?: 0),
                "edited" to (data?.getBooleanExtra("edited", false) ?: false))
            data?.getBooleanArrayExtra("visited")?.let { reply["visited"] = it.toList() }
            data?.getBooleanArrayExtra("favorites")?.let { reply["favorites"] = it.toList() }
            data?.getLongArrayExtra("positions")?.let { reply["positions"] = it.toList() }
            data?.getLongArrayExtra("durations")?.let { reply["durations"] = it.toList() }
            videoResults.remove(requestCode)?.success(reply)
            return
        }
        if (requestCode !in 701..704) return
        val result = pending ?: return
        pending = null
        try {
            val uri = data?.data
            if (resultCode != Activity.RESULT_OK || uri == null) result.success(null)
            else if (requestCode == 703) {
                worker.execute {
                    var target: java.io.File? = null
                    try {
                        var name = uri.lastPathSegment ?: "subtitle.srt"
                        contentResolver.query(uri, arrayOf(android.provider.OpenableColumns.DISPLAY_NAME), null, null, null)?.use {
                            if (it.moveToFirst()) name = it.getString(0)
                        }
                        val extension = name.substringAfterLast('.', "").lowercase()
                        require(extension in listOf("srt", "vtt", "ass", "ssa", "sub")) { "Altyazı dosyası seçin" }
                        target = java.io.File.createTempFile("BMusic_subtitle_", "." + extension, cacheDir)
                        contentResolver.openInputStream(uri)?.use { input ->
                            target!!.outputStream().use { output ->
                                val buffer = ByteArray(8192)
                                var total = 0L
                                while (true) {
                                    val count = input.read(buffer)
                                    if (count < 0) break
                                    total += count
                                    require(total <= 8L * 1024 * 1024) { "Altyazı dosyası çok büyük" }
                                    output.write(buffer, 0, count)
                                }
                            }
                        } ?: throw IllegalStateException("Altyazı okunamadı")
                        val path = target!!.absolutePath
                        runOnUiThread { result.success(path) }
                    } catch (e: Exception) {
                        target?.delete()
                        runOnUiThread { result.error("subtitle", e.message, null) }
                    }
                }
            } else if (requestCode == 704) {
                val path = mediaCopy ?: throw IllegalStateException("Kaynak yok")
                mediaCopy = null
                worker.execute {
                    try {
                        contentResolver.openOutputStream(uri, "wt")?.use { output -> java.io.File(path).inputStream().use { it.copyTo(output) } }
                            ?: throw IllegalStateException("Dosya yazılamadı")
                        runOnUiThread { result.success(true) }
                    } catch (e: Exception) { runOnUiThread { result.error("save", e.message, null) } }
                }
            } else if (requestCode == 701) {
                contentResolver.openOutputStream(uri)?.use { it.write((backup ?: "{}").toByteArray()) } ?: throw IllegalStateException("Dosya açılamadı")
                result.success(null)
            } else {
                val text = contentResolver.openInputStream(uri)?.bufferedReader()?.use { it.readText() }
                result.success(text)
            }
        } catch (e: Exception) { result.error("file", e.message, null) }
        backup = null
    }
}
