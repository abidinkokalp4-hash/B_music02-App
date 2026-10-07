package com.bmusic.app

import android.content.Context
import android.os.Bundle
import com.google.firebase.analytics.FirebaseAnalytics

/** Firebase Analytics events sent from native code (free Spark plan, no extra setup). */
object Analytics {
    /** A tapped B Music notification: [source] is "github" (announcements.json) or "fcm" (push). */
    fun notificationOpen(context: Context, id: String, source: String) {
        try {
            FirebaseAnalytics.getInstance(context).logEvent("notification_open", Bundle().apply {
                putString("id", id.take(100)); putString("source", source)
            })
        } catch (e: Throwable) { android.util.Log.w("flutter", "analytics failed: ${e.message}") }
    }
}
