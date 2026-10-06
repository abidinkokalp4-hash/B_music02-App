package com.example.b_music02

import android.content.Context
import com.google.firebase.FirebaseApp
import com.google.firebase.messaging.FirebaseMessaging
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

/**
 * Instant announcements through Firebase Cloud Messaging (topic "all").
 *
 * The Firebase app is created at process start by FirebaseInitProvider from the
 * google_app_id/google_api_key/... string resources that tool/configure_android.py
 * generates from lib/firebase_options.dart, so a push can wake a stopped app.
 * Every call is guarded: without Google Play services (CI emulator, de-Googled
 * phones) or without a configured project the app works and the
 * announcements.json poll stays the delivery path.
 */
object Push {
    const val TOPIC = "all"
    /** Last known state for the in-app diagnostics: unconfigured / subscribed / unsubscribed / error. */
    @Volatile var status: String = "unknown"

    private fun log(message: String) = android.util.Log.i("flutter", "[BMusic feature] $message")

    fun configured(context: Context): Boolean =
        try { FirebaseApp.getApps(context).isNotEmpty() } catch (_: Throwable) { false }

    /** Subscribe to (or, with "Duyuru bildirimleri" off, leave) the broadcast topic. */
    fun sync(context: Context) {
        log("push-sync enabled=${Announcements.enabled(context)}")
        if (!configured(context)) { status = "unconfigured"; log("push-topic skipped: firebase not configured"); return }
        val enabled = Announcements.enabled(context)
        try {
            val messaging = FirebaseMessaging.getInstance()
            val task = if (enabled) messaging.subscribeToTopic(TOPIC) else messaging.unsubscribeFromTopic(TOPIC)
            task.addOnCompleteListener {
                status = if (!it.isSuccessful) "error" else if (enabled) "subscribed" else "unsubscribed"
                log("push-topic ${if (enabled) "subscribe" else "unsubscribe"} ok=${it.isSuccessful}" +
                    (it.exception?.let { e -> " error=${e.javaClass.simpleName}: ${e.message}" } ?: ""))
            }
        } catch (e: Throwable) {
            status = "error"
            log("push-topic unavailable: ${e.javaClass.simpleName}: ${e.message}")
        }
    }
}

/** Receives FCM messages in the foreground, background and after the app was swiped away. */
class PushMessagingService : FirebaseMessagingService() {
    override fun onMessageReceived(message: RemoteMessage) {
        val data = HashMap<String, String?>(message.data)
        val notification = message.notification
        if (notification != null) {
            if (data["title"].isNullOrBlank()) data["title"] = notification.title
            if (data["body"].isNullOrBlank()) data["body"] = notification.body
        }
        val item = AnnouncementLogic.fromPush(data, message.sentTime, message.messageId)
        if (item == null) {
            android.util.Log.i("flutter", "[BMusic feature] push-ignored (no title/id)")
            return
        }
        Announcements.receivePush(applicationContext, item)
    }

    override fun onNewToken(token: String) {
        android.util.Log.i("flutter", "[BMusic feature] push-token-refreshed")
        Push.sync(applicationContext)
    }
}
