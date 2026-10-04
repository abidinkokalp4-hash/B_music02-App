package com.example.b_music02

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
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        receiveMedia(intent)
    }
    private var videoFullscreen = false
    override fun onCreate(savedInstanceState: Bundle?) { super.onCreate(savedInstanceState); hideNavigation(); if (savedInstanceState == null) receiveMedia(intent) }
    override fun onWindowFocusChanged(hasFocus: Boolean) { super.onWindowFocusChanged(hasFocus); if (hasFocus) hideNavigation() }
    private fun hideNavigation() {
        if (Build.VERSION.SDK_INT >= 30) {
            window.insetsController?.let {
                it.systemBarsBehavior = WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                if (!videoFullscreen) it.show(WindowInsets.Type.statusBars())
                it.hide(if (videoFullscreen) WindowInsets.Type.systemBars() else WindowInsets.Type.navigationBars())
            }
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or View.SYSTEM_UI_FLAG_LAYOUT_STABLE or (if (videoFullscreen) View.SYSTEM_UI_FLAG_FULLSCREEN else 0)
        }
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        deviceChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "b_music02/device")
        deviceChannel!!.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
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
                        result.success(mapOf("sdk" to Build.VERSION.SDK_INT, "version" to p.versionName, "build" to if (Build.VERSION.SDK_INT >= 28) p.longVersionCode else @Suppress("DEPRECATION") p.versionCode.toLong(), "batteryUnrestricted" to power.isIgnoringBatteryOptimizations(packageName)))
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
                    "exportBackup", "importBackup" -> {
                        if (pending != null) { result.error("busy", "Dosya seçici zaten açık", null) }
                        else {
                            pending = result
                            if (call.method == "exportBackup") {
                                backup = call.arguments as String
                                startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE).setType("application/json").putExtra(Intent.EXTRA_TITLE, "B_music02-yedek.json"), 701)
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
