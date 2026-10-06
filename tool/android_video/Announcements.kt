package com.example.b_music02

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.TimeUnit

/** One entry of announcements.json. */
data class Announcement(val id: String, val title: String, val body: String, val url: String?, val createdAt: Long?)

/** Pure parsing and "what is new" rules, unit-tested on the JVM. */
object AnnouncementLogic {
    const val MAX_PER_CHECK = 3

    fun parse(text: String): List<Announcement> {
        val root = try { JSONObject(text) } catch (_: Exception) { return emptyList() }
        val items = root.optJSONArray("announcements") ?: return emptyList()
        val result = mutableListOf<Announcement>()
        val ids = mutableSetOf<String>()
        for (i in 0 until items.length()) {
            val item = items.optJSONObject(i) ?: continue
            val id = item.optString("id").trim()
            val title = item.optString("title").trim()
            if (id.isEmpty() || title.isEmpty() || !ids.add(id)) continue
            val url = item.optString("url").trim().takeIf { it.startsWith("https://") }
            result += Announcement(id, title.take(120), item.optString("body").trim().take(1000), url, time(item.optString("createdAt")))
        }
        return result.sortedByDescending { it.createdAt ?: Long.MIN_VALUE }
    }

    private val iso = Regex("""(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2})(?::(\d{2})(?:\.\d+)?)?)?\s*(Z|[+-]\d{2}:?\d{2})?""")

    /** ISO-8601 date or date-time to epoch ms (java.time needs API 26; minSdk is 24). */
    fun time(value: String?): Long? {
        val m = iso.matchEntire(value?.trim() ?: return null) ?: return null
        val g = m.groupValues
        val calendar = java.util.Calendar.getInstance(java.util.TimeZone.getTimeZone("UTC")).apply {
            clear(); isLenient = false
            set(g[1].toInt(), g[2].toInt() - 1, g[3].toInt(), g[4].ifEmpty { "0" }.toInt(), g[5].ifEmpty { "0" }.toInt(), g[6].ifEmpty { "0" }.toInt())
        }
        val base = try { calendar.timeInMillis } catch (_: IllegalArgumentException) { return null }
        val zone = g[7]
        if (zone.isEmpty() || zone == "Z") return base
        val digits = zone.substring(1).replace(":", "")
        val offset = (digits.substring(0, 2).toInt() * 60 + digits.substring(2).toInt()) * 60000L
        return if (zone[0] == '+') base - offset else base + offset
    }

    /**
     * Returns (toNotify, toMarkSeen). [since] is when this install first checked:
     * older announcements (or undated ones seen on the very first check) are
     * marked seen silently so a fresh install is not flooded.
     */
    fun select(items: List<Announcement>, seen: Set<String>, since: Long, firstCheck: Boolean): Pair<List<Announcement>, Set<String>> {
        val unseen = items.filter { it.id !in seen }
        val fresh = unseen.filter { val t = it.createdAt; if (t == null) !firstCheck else t >= since }
        val notify = fresh.sortedBy { it.createdAt ?: Long.MAX_VALUE }.takeLast(MAX_PER_CHECK)
        return notify to unseen.map { it.id }.toSet()
    }
}

/** Fetch + seen state + notification posting, shared by start/resume checks and the periodic worker. */
object Announcements {
    const val SOURCE = "https://raw.githubusercontent.com/abidinkokalp4-hash/B_music02-App/main/announcements.json"
    const val CHANNEL = "announcements"
    const val EXTRA = "bmusic_announcement"
    private const val WORK = "bmusic-announcements"
    private val lock = Any()

    fun prefs(context: Context) = context.getSharedPreferences("bmusic_announcements", Context.MODE_PRIVATE)
    fun enabled(context: Context) = prefs(context).getBoolean("enabled", true)

    fun setEnabled(context: Context, value: Boolean) {
        prefs(context).edit().putBoolean("enabled", value).apply()
        schedule(context)
    }

    fun schedule(context: Context) {
        val work = WorkManager.getInstance(context.applicationContext)
        if (!enabled(context)) { work.cancelUniqueWork(WORK); return }
        val request = PeriodicWorkRequestBuilder<AnnouncementWorker>(4, TimeUnit.HOURS, 1, TimeUnit.HOURS)
            .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
            .build()
        work.enqueueUniquePeriodicWork(WORK, ExistingPeriodicWorkPolicy.KEEP, request)
    }

    private fun fetch(context: Context): String? {
        // Only a rooted test device can set debug_url (app-private preferences).
        val override = prefs(context).getString("debug_url", null)
        val source = override ?: SOURCE
        return try {
            val url = if (source.startsWith("file:")) URL(source) else URL(source + (if ('?' in source) "&" else "?") + "t=" + System.currentTimeMillis() / 60000)
            val connection = url.openConnection()
            connection.connectTimeout = 10000; connection.readTimeout = 10000
            connection.setRequestProperty("Cache-Control", "no-cache")
            if (connection is HttpURLConnection && connection.responseCode != 200) { connection.disconnect(); return null }
            connection.getInputStream().use { it.readBytes().toString(Charsets.UTF_8) }.takeIf { it.length < 512 * 1024 }
        } catch (_: Exception) { null }
    }

    /** Fetches, posts notifications for new entries and returns the cached state for the app. */
    fun check(context: Context): Map<String, Any?> = synchronized(lock) {
        val store = prefs(context)
        val firstCheck = !store.contains("since")
        if (firstCheck) store.edit().putLong("since", System.currentTimeMillis()).commit()
        val text = fetch(context)
        if (text != null) {
            val items = AnnouncementLogic.parse(text)
            val seen = store.getStringSet("seen", emptySet())!!.toSet()
            val (notify, mark) = AnnouncementLogic.select(items, seen, store.getLong("since", 0), firstCheck)
            val canPost = enabled(context) && allowed(context)
            if (canPost) notify.forEach { post(context, it) }
            android.util.Log.i("flutter", "[BMusic feature] announcements total=${items.size} new=${notify.size} posted=${if (canPost) notify.size else 0}")
            store.edit().putString("cache", text).putStringSet("seen", (seen + mark).toList().takeLast(500).toSet()).commit()
        }
        state(context)
    }

    fun state(context: Context): Map<String, Any?> {
        val store = prefs(context)
        return mapOf("json" to store.getString("cache", null), "seen" to store.getStringSet("seen", emptySet())!!.toList(),
            "enabled" to enabled(context), "allowed" to allowed(context))
    }

    fun allowed(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= 33 && context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return false
        return NotificationManagerCompat.from(context).areNotificationsEnabled()
    }

    private fun post(context: Context, item: Announcement) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26 && manager.getNotificationChannel(CHANNEL) == null)
            manager.createNotificationChannel(NotificationChannel(CHANNEL, "Duyurular", NotificationManager.IMPORTANCE_DEFAULT).apply { description = "B Music duyuruları" })
        val open = Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP).putExtra(EXTRA, item.id)
        val tap = PendingIntent.getActivity(context, item.id.hashCode(), open, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val notification = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_music)
            .setContentTitle(item.title)
            .setContentText(item.body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(item.body))
            .setContentIntent(tap).setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .build()
        try {
            NotificationManagerCompat.from(context).notify("announcement", item.id.hashCode(), notification)
            android.util.Log.i("flutter", "[BMusic feature] announcement-posted id=${item.id}")
        } catch (_: SecurityException) { }
    }
}

class AnnouncementWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    override fun doWork(): Result {
        if (Announcements.enabled(applicationContext)) Announcements.check(applicationContext)
        return Result.success()
    }
}
