package com.bmusic.app

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import java.io.File

/** Shares downloaded update APKs (cache/updates/) with the system package installer. */
class UpdateFileProvider : FileProvider()

/** In-app updater support: installer source, unknown-sources permission and APK hand-off. */
object AppUpdate {
    const val PLAY_STORE = "com.android.vending"

    fun installer(context: Context): String? = try {
        if (Build.VERSION.SDK_INT >= 30) context.packageManager.getInstallSourceInfo(context.packageName).installingPackageName
        else @Suppress("DEPRECATION") context.packageManager.getInstallerPackageName(context.packageName)
    } catch (_: Exception) { null }

    /** Google Play installs update through Play only, so the GitHub updater stays off. */
    fun fromPlay(context: Context) = installer(context) == PLAY_STORE

    fun canInstall(context: Context) = Build.VERSION.SDK_INT < 26 || context.packageManager.canRequestPackageInstalls()

    fun updateDir(context: Context) = File(context.cacheDir, "updates").apply { mkdirs() }

    /**
     * Opens the installer for [path]. Returns "permission" when the user first has to allow
     * installs from B Music (the settings page is opened), "installer" when the installer opened.
     */
    fun install(activity: Activity, path: String): String {
        val file = File(path).canonicalFile
        require(file.parentFile == updateDir(activity).canonicalFile && file.isFile) { "Güncelleme dosyası bulunamadı" }
        val info = activity.packageManager.getPackageArchiveInfo(file.path, 0)
        require(info?.packageName == activity.packageName) { "İndirilen dosya B Music değil" }
        if (!canInstall(activity)) {
            activity.startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:${activity.packageName}")))
            return "permission"
        }
        val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.updates", file)
        activity.startActivity(Intent(Intent.ACTION_VIEW).setDataAndType(uri, "application/vnd.android.package-archive")
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK))
        return "installer"
    }
}
