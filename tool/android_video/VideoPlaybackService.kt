package com.bmusic.app

import android.app.PendingIntent
import android.content.Intent
import android.media.audiofx.Equalizer
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.session.DefaultMediaNotificationProvider
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
        // Codec fallback: if the hardware decoder fails (or the format is unsupported) ExoPlayer
        // tries the next decoder, and audio formats Android lacks (AC3, E-AC3, DTS, TrueHD, …)
        // are decoded in software by the bundled FFmpeg extension.
        val renderers = DefaultRenderersFactory(this)
            .setExtensionRendererMode(DefaultRenderersFactory.EXTENSION_RENDERER_MODE_ON)
            .setEnableDecoderFallback(true)
        player = ExoPlayer.Builder(this, renderers).setWakeMode(C.WAKE_MODE_LOCAL).setSeekBackIncrementMs(10000).setSeekForwardIncrementMs(10000).build().apply {
            setAudioAttributes(AudioAttributes.Builder().setUsage(C.USAGE_MEDIA)
                .setContentType(C.AUDIO_CONTENT_TYPE_MOVIE).build(), true)
            setHandleAudioBecomingNoisy(true)
            addListener(object : Player.Listener {
                override fun onAudioSessionIdChanged(audioSessionId: Int) {
                    if (speech) applySpeech(true)
                }
            })
            // Which decoder actually runs (e.g. "ffmpeg…" for AC3/DTS); read by the emulator test.
            addAnalyticsListener(object : androidx.media3.exoplayer.analytics.AnalyticsListener {
                override fun onAudioDecoderInitialized(eventTime: androidx.media3.exoplayer.analytics.AnalyticsListener.EventTime,
                                                       decoderName: String, initializedTimestampMs: Long, initializationDurationMs: Long) {
                    android.util.Log.i("flutter", "[BMusic feature] audio-decoder=$decoderName")
                }
                override fun onVideoDecoderInitialized(eventTime: androidx.media3.exoplayer.analytics.AnalyticsListener.EventTime,
                                                       decoderName: String, initializedTimestampMs: Long, initializationDurationMs: Long) {
                    android.util.Log.i("flutter", "[BMusic feature] video-decoder=$decoderName")
                }
            })
        }
        val reopen = PendingIntent.getActivity(this, 810, Intent(this, VideoActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        session = MediaSession.Builder(this, player).setSessionActivity(reopen).build()
        setMediaNotificationProvider(DefaultMediaNotificationProvider.Builder(this).build().apply { setSmallIcon(R.drawable.ic_stat_bm) })
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
