package com.bmusic.app

import android.app.Activity
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.view.Gravity
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.Calendar
import java.util.TimeZone

/** One alarm as stored by the Flutter "Alarm" screen. Days use 1 = Monday … 7 = Sunday. */
data class AlarmSpec(val id: Int, val hour: Int, val minute: Int, val days: Set<Int>, val enabled: Boolean,
                     val songPath: String, val songTitle: String, val label: String) {
    companion object {
        fun parse(o: JSONObject): AlarmSpec {
            val days = o.optJSONArray("days")?.let { a -> (0 until a.length()).map { a.optInt(it) }.filter { it in 1..7 }.toSet() } ?: emptySet()
            return AlarmSpec(o.optInt("id"), o.optInt("hour").coerceIn(0, 23), o.optInt("minute").coerceIn(0, 59), days,
                o.optBoolean("enabled", true), o.optString("songPath"), o.optString("songTitle"), o.optString("label"))
        }
        fun parseAll(json: String?): List<AlarmSpec> = try {
            val array = JSONArray(json ?: "[]"); (0 until array.length()).mapNotNull { array.optJSONObject(it)?.let(::parse) }
        } catch (_: Exception) { emptyList() }
    }
}

/** Pure scheduling maths (unit tested). */
object AlarmLogic {
    /** Monday = 1 … Sunday = 7 for a [Calendar.DAY_OF_WEEK] value. */
    fun isoDay(calendarDay: Int) = if (calendarDay == Calendar.SUNDAY) 7 else calendarDay - 1

    /** Next time ≥ now+1 s the alarm rings; an empty day set means "once" (today or tomorrow). */
    fun nextTrigger(now: Long, hour: Int, minute: Int, days: Set<Int>, zone: TimeZone = TimeZone.getDefault()): Long {
        val c = Calendar.getInstance(zone).apply { timeInMillis = now; set(Calendar.HOUR_OF_DAY, hour); set(Calendar.MINUTE, minute); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0) }
        for (i in 0..7) {
            if (c.timeInMillis > now + 999 && (days.isEmpty() || isoDay(c.get(Calendar.DAY_OF_WEEK)) in days)) return c.timeInMillis
            c.add(Calendar.DAY_OF_MONTH, 1); c.set(Calendar.HOUR_OF_DAY, hour); c.set(Calendar.MINUTE, minute)
        }
        return c.timeInMillis
    }
}

object AlarmScheduler {
    const val ACTION_FIRE = "com.bmusic.app.ALARM_FIRE"
    const val EXTRA_ID = "alarm_id"
    const val EXTRA_SNOOZE = "alarm_snooze"
    const val SNOOZE_MINUTES = 10
    private const val PREFS = "bm_alarms"

    fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    fun load(context: Context): List<AlarmSpec> = AlarmSpec.parseAll(prefs(context).getString("alarms", "[]"))
    fun raw(context: Context): String = prefs(context).getString("alarms", "[]") ?: "[]"
    fun save(context: Context, json: String) {
        JSONArray(json) // validate
        prefs(context).edit().putString("alarms", json).apply()
        scheduleAll(context)
    }
    fun find(context: Context, id: Int) = load(context).firstOrNull { it.id == id }

    fun canExact(context: Context): Boolean {
        val manager = context.getSystemService(AlarmManager::class.java) ?: return false
        return Build.VERSION.SDK_INT < 31 || manager.canScheduleExactAlarms()
    }
    private fun pending(context: Context, id: Int, snooze: Boolean): PendingIntent =
        PendingIntent.getBroadcast(context, id * 2 + if (snooze) 1 else 0,
            Intent(context, AlarmReceiver::class.java).setAction(ACTION_FIRE).putExtra(EXTRA_ID, id).putExtra(EXTRA_SNOOZE, snooze),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    private fun showIntent(context: Context): PendingIntent = PendingIntent.getActivity(context, 9100,
        Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

    private fun set(context: Context, at: Long, operation: PendingIntent) {
        val manager = context.getSystemService(AlarmManager::class.java) ?: return
        try {
            if (canExact(context)) manager.setAlarmClock(AlarmManager.AlarmClockInfo(at, showIntent(context)), operation)
            else manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, operation)
        } catch (_: SecurityException) { manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, operation) }
    }

    /** (Re)arms every enabled alarm and pending snooze; called on save, boot, update and time changes. */
    fun scheduleAll(context: Context) {
        val manager = context.getSystemService(AlarmManager::class.java) ?: return
        val now = System.currentTimeMillis()
        val known = prefs(context).getStringSet("armed", emptySet())!!.mapNotNull { it.toIntOrNull() }.toMutableSet()
        val alarms = load(context)
        for (id in known - alarms.map { it.id }.toSet()) { manager.cancel(pending(context, id, false)); manager.cancel(pending(context, id, true)) }
        for (alarm in alarms) {
            if (alarm.enabled) set(context, AlarmLogic.nextTrigger(now, alarm.hour, alarm.minute, alarm.days), pending(context, alarm.id, false))
            else manager.cancel(pending(context, alarm.id, false))
            val snoozeAt = prefs(context).getLong("snooze_${alarm.id}", 0)
            if (snoozeAt > now) set(context, snoozeAt, pending(context, alarm.id, true))
            else { manager.cancel(pending(context, alarm.id, true)); prefs(context).edit().remove("snooze_${alarm.id}").apply() }
        }
        prefs(context).edit().putStringSet("armed", alarms.map { it.id.toString() }.toSet()).apply()
        android.util.Log.i("flutter", "[BMusic feature] alarms-scheduled=${alarms.count { it.enabled }} exact=${canExact(context)}")
    }
    /** After ringing: a one-time alarm switches itself off, a repeating one is armed for its next day. */
    fun afterRing(context: Context, id: Int) {
        val json = try { JSONArray(raw(context)) } catch (_: Exception) { JSONArray() }
        for (i in 0 until json.length()) {
            val o = json.optJSONObject(i) ?: continue
            if (o.optInt("id") == id && (o.optJSONArray("days")?.length() ?: 0) == 0) o.put("enabled", false)
        }
        prefs(context).edit().putString("alarms", json.toString()).apply()
        scheduleAll(context)
    }
    fun snooze(context: Context, id: Int) {
        val at = System.currentTimeMillis() + SNOOZE_MINUTES * 60_000L
        prefs(context).edit().putLong("snooze_$id", at).apply()
        set(context, at, pending(context, id, true))
    }
}

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != AlarmScheduler.ACTION_FIRE) return
        val id = intent.getIntExtra(AlarmScheduler.EXTRA_ID, -1)
        if (intent.getBooleanExtra(AlarmScheduler.EXTRA_SNOOZE, false)) AlarmScheduler.prefs(context).edit().remove("snooze_$id").apply()
        else AlarmScheduler.afterRing(context, id)
        android.util.Log.i("flutter", "[BMusic feature] alarm-fired id=$id")
        val start = Intent(context, AlarmService::class.java).setAction(AlarmService.ACTION_START).putExtra(AlarmScheduler.EXTRA_ID, id)
        try { if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(start) else context.startService(start) }
        catch (e: Exception) { android.util.Log.w("flutter", "alarm service start failed: ${e.message}") }
    }
}

class AlarmBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        try { AlarmScheduler.scheduleAll(context) } catch (e: Exception) { android.util.Log.w("flutter", "alarm reschedule failed: ${e.message}") }
    }
}

/** Plays the chosen song (or the system alarm sound) in a loop until stopped or snoozed. */
class AlarmService : Service() {
    companion object {
        const val ACTION_START = "com.bmusic.app.ALARM_START"
        const val ACTION_STOP = "com.bmusic.app.ALARM_STOP"
        const val ACTION_SNOOZE = "com.bmusic.app.ALARM_SNOOZE"
        const val CHANNEL = "bmusic_alarm"
        private const val NOTIFICATION_ID = 4711
        private const val TIMEOUT_MS = 10 * 60_000L
        var ringing: AlarmSpec? = null
            private set
    }
    private var player: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var currentId = -1
    private val handler = Handler(Looper.getMainLooper())
    private val timeout = Runnable { stopRinging() }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> { stopRinging(); return START_NOT_STICKY }
            ACTION_SNOOZE -> { if (currentId >= 0) AlarmScheduler.snooze(this, currentId); android.util.Log.i("flutter", "[BMusic feature] alarm-snoozed id=$currentId"); stopRinging(); return START_NOT_STICKY }
        }
        val id = intent?.getIntExtra(AlarmScheduler.EXTRA_ID, -1) ?: -1
        val alarm = AlarmScheduler.find(this, id) ?: AlarmSpec(id, 0, 0, emptySet(), true, "", "", "")
        currentId = id; ringing = alarm
        val notification = buildNotification(alarm)
        if (Build.VERSION.SDK_INT >= 29) startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        else startForeground(NOTIFICATION_ID, notification)
        startSound(alarm)
        handler.removeCallbacks(timeout); handler.postDelayed(timeout, TIMEOUT_MS)
        android.util.Log.i("flutter", "[BMusic feature] alarm-ringing id=$id song=${alarm.songTitle}")
        return START_NOT_STICKY
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < 26) return
        val manager = getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(CHANNEL) != null) return
        manager.createNotificationChannel(NotificationChannel(CHANNEL, "Alarm", NotificationManager.IMPORTANCE_HIGH).apply {
            description = "B Music alarmları"; setSound(null, null); enableVibration(false); lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        })
    }
    private fun action(name: String, request: Int) = PendingIntent.getService(this, request,
        Intent(this, AlarmService::class.java).setAction(name), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

    private fun buildNotification(alarm: AlarmSpec): Notification {
        ensureChannel()
        val full = PendingIntent.getActivity(this, 9200, Intent(this, AlarmActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_USER_ACTION), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val text = listOf(alarm.label, alarm.songTitle).filter { it.isNotBlank() }.joinToString(" • ").ifEmpty { "Alarm çalıyor" }
        return Brand.apply(NotificationCompat.Builder(this, CHANNEL), this)
            .setContentTitle("Alarm %02d:%02d".format(alarm.hour, alarm.minute))
            .setContentText(text)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true).setAutoCancel(false)
            .setFullScreenIntent(full, true)
            .setContentIntent(full)
            .addAction(0, "Ertele", action(ACTION_SNOOZE, 9201))
            .addAction(0, "Durdur", action(ACTION_STOP, 9202))
            .build()
    }

    private fun startSound(alarm: AlarmSpec) {
        stopSound()
        val attributes = AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build()
        fun create(configure: MediaPlayer.() -> Unit): MediaPlayer? = try {
            MediaPlayer().apply { setAudioAttributes(attributes); configure(); isLooping = true; prepare(); start() }
        } catch (e: Exception) { android.util.Log.w("flutter", "alarm sound failed: ${e.message}"); null }
        player = if (alarm.songPath.isNotBlank() && File(alarm.songPath).canRead()) create { setDataSource(alarm.songPath) } else null
        if (player == null) {
            val fallback = RingtoneManager.getActualDefaultRingtoneUri(this, RingtoneManager.TYPE_ALARM) ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            if (fallback != null) player = create { setDataSource(this@AlarmService, fallback) }
        }
        vibrator = (getSystemService(VIBRATOR_SERVICE) as? Vibrator)?.also { v ->
            val pattern = longArrayOf(0, 600, 800)
            if (Build.VERSION.SDK_INT >= 26) v.vibrate(VibrationEffect.createWaveform(pattern, 0)) else @Suppress("DEPRECATION") v.vibrate(pattern, 0)
        }
    }
    private fun stopSound() {
        try { player?.stop() } catch (_: Exception) { }
        player?.release(); player = null
        vibrator?.cancel(); vibrator = null
    }
    private fun stopRinging() {
        handler.removeCallbacks(timeout)
        stopSound(); ringing = null; currentId = -1
        AlarmActivity.current?.finish()
        if (Build.VERSION.SDK_INT >= 24) stopForeground(STOP_FOREGROUND_REMOVE) else @Suppress("DEPRECATION") stopForeground(true)
        stopSelf()
    }
    override fun onDestroy() { handler.removeCallbacks(timeout); stopSound(); ringing = null; super.onDestroy() }
}

/** Full-screen ringing screen over the lock screen: big clock, Ertele and Durdur. */
class AlarmActivity : Activity() {
    companion object { var current: AlarmActivity? = null }
    private val handler = Handler(Looper.getMainLooper())
    private lateinit var clock: TextView
    private val tick = object : Runnable {
        override fun run() { val c = Calendar.getInstance(); clock.text = "%02d:%02d".format(c.get(Calendar.HOUR_OF_DAY), c.get(Calendar.MINUTE)); handler.postDelayed(this, 1000) }
    }
    private fun dp(v: Int) = (v * resources.displayMetrics.density).toInt()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        current = this
        if (Build.VERSION.SDK_INT >= 27) { setShowWhenLocked(true); setTurnScreenOn(true) }
        @Suppress("DEPRECATION")
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)
        window.statusBarColor = Color.BLACK; window.navigationBarColor = Color.BLACK
        val alarm = AlarmService.ringing
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL; gravity = Gravity.CENTER; setPadding(dp(28), dp(48), dp(28), dp(48))
            background = GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM, intArrayOf(0xFF2A1240.toInt(), 0xFF030305.toInt()))
        }
        root.addView(TextView(this).apply { text = "ALARM"; setTextColor(0xFFCDA4FF.toInt()); textSize = 14f; letterSpacing = .3f; typeface = Typeface.DEFAULT_BOLD; gravity = Gravity.CENTER })
        clock = TextView(this).apply { setTextColor(Color.WHITE); textSize = 76f; typeface = Typeface.create("sans-serif-light", Typeface.NORMAL); gravity = Gravity.CENTER }
        root.addView(clock)
        val subtitle = listOf(alarm?.label ?: "", alarm?.songTitle ?: "").filter { it.isNotBlank() }.joinToString("\n").ifEmpty { "B Music" }
        root.addView(TextView(this).apply { text = subtitle; setTextColor(0xCCFFFFFF.toInt()); textSize = 17f; gravity = Gravity.CENTER; setPadding(0, dp(8), 0, dp(56)) })
        fun button(label: String, filled: Boolean, onClick: () -> Unit) = Button(this).apply {
            text = label; isAllCaps = false; textSize = 18f; setTextColor(Color.WHITE)
            background = GradientDrawable().apply { cornerRadius = dp(32).toFloat(); if (filled) setColor(0xFFA53CFF.toInt()) else { setColor(0x22FFFFFF); setStroke(dp(1), 0x66FFFFFF) } }
            contentDescription = label; setOnClickListener { onClick() }
        }
        root.addView(button("Ertele (${AlarmScheduler.SNOOZE_MINUTES} dk)", false) { send(AlarmService.ACTION_SNOOZE) }, LinearLayout.LayoutParams(-1, dp(60)).apply { bottomMargin = dp(16) })
        root.addView(button("Durdur", true) { send(AlarmService.ACTION_STOP) }, LinearLayout.LayoutParams(-1, dp(60)))
        setContentView(root)
        handler.post(tick)
        if (alarm == null) finish()
    }
    private fun send(action: String) { startService(Intent(this, AlarmService::class.java).setAction(action)); finish() }
    @Deprecated("Back") override fun onBackPressed() { /* must choose Ertele or Durdur */ }
    override fun onDestroy() { handler.removeCallbacksAndMessages(null); if (current === this) current = null; super.onDestroy() }
}
