package com.example.b_music02

import android.app.PendingIntent
import android.content.Intent
import android.media.audiofx.Equalizer
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService

@UnstableApi
class VideoPlaybackService : MediaSessionService() {
    companion object { var active: VideoPlaybackService? = null }
    lateinit var player: ExoPlayer
    private var session: MediaSession? = null
    private var equalizer: Equalizer? = null
    private var speech = false
    override fun onCreate() {
        super.onCreate()
        active = this
        player = ExoPlayer.Builder(this).setWakeMode(C.WAKE_MODE_LOCAL).build().apply {
            setAudioAttributes(AudioAttributes.Builder().setUsage(C.USAGE_MEDIA)
                .setContentType(C.AUDIO_CONTENT_TYPE_MOVIE).build(), true)
            setHandleAudioBecomingNoisy(true)
            addListener(object : Player.Listener {
                override fun onAudioSessionIdChanged(audioSessionId: Int) {
                    if (speech) applySpeech(true)
                }
            })
        }
        val reopen = PendingIntent.getActivity(this, 810, Intent(this, VideoActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        session = MediaSession.Builder(this, player).setSessionActivity(reopen).build()
    }
    fun applySpeech(enabled: Boolean): Boolean {
        equalizer?.release(); equalizer = null
        speech = enabled
        if (!enabled) return true
        return try {
            val eq = Equalizer(0, player.audioSessionId)
            val range = eq.bandLevelRange
            for (i in 0 until eq.numberOfBands.toInt()) {
                val frequency = eq.getCenterFreq(i.toShort()) / 1000
                val gain = when { frequency < 250 -> -300; frequency in 800..4000 -> 400; else -> 0 }
                eq.setBandLevel(i.toShort(), gain.coerceIn(range[0].toInt(), range[1].toInt()).toShort())
            }
            eq.enabled = true; equalizer = eq; true
        } catch (_: RuntimeException) { speech = false; false }
    }
    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession? = session
    override fun onTaskRemoved(rootIntent: Intent?) {
        if (!player.playWhenReady) stopSelf()
    }
    override fun onDestroy() {
        equalizer?.release(); session?.release(); player.release()
        active = null
        super.onDestroy()
    }
}
