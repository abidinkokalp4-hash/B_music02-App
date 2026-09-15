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
    override fun onCreate(savedInstanceState: Bundle?) { super.onCreate(savedInstanceState); hideNavigation() }
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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "b_music02/device").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "videoFullscreen" -> {
                        videoFullscreen = call.arguments == true
                        if (videoFullscreen) window.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        else window.clearFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        hideNavigation(); result.success(null)
                    }
                    "immersive" -> { hideNavigation(); result.success(null) }
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
