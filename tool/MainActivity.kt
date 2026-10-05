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
    private var videoFullscreen = false
    private var videoResult: MethodChannel.Result? = null
    override fun onCreate(savedInstanceState: Bundle?) { super.onCreate(savedInstanceState); hideNavigation() }
    override fun onWindowFocusChanged(hasFocus: Boolean) { super.onWindowFocusChanged(hasFocus); if (hasFocus) hideNavigation() }
    private fun hideNavigation() {
        if (Build.VERSION.SDK_INT >= 30) {
            window.insetsController?.show(WindowInsets.Type.systemBars())
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_LAYOUT_STABLE
        }
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "b_music02/device").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
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
                        if (videoResult != null) result.error("busy", "Video zaten açık", null)
                        else {
                            val values = call.arguments as Map<*, *>
                            videoResult = result
                            try {
                                startActivityForResult(Intent(this, VideoActivity::class.java)
                                    .putExtra("path", values["path"] as String)
                                    .putExtra("title", values["title"] as String)
                                    .putExtra("position", (values["position"] as Number).toLong()), 811)
                            } catch (e: Exception) { videoResult = null; throw e }
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
                        result.success(mapOf("version" to p.versionName, "build" to if (Build.VERSION.SDK_INT >= 28) p.longVersionCode else @Suppress("DEPRECATION") p.versionCode.toLong(), "batteryUnrestricted" to power.isIgnoringBatteryOptimizations(packageName)))
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
        if (requestCode == 811) {
            videoResult?.success(mapOf("position" to (data?.getLongExtra("position", 0) ?: 0),
                "duration" to (data?.getLongExtra("duration", 0) ?: 0)))
            videoResult = null
            return
        }
        if (requestCode != 701 && requestCode != 702) return
        val result = pending ?: return
        pending = null
        try {
            val uri = data?.data
            if (resultCode != Activity.RESULT_OK || uri == null) result.success(null)
            else if (requestCode == 701) {
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
