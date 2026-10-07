package com.bmusic.app

import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.transformer.Composition
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.Transformer
import java.io.File
import java.util.concurrent.Executors

/** Cuts start..end of a local video into Movies/BMusic (used by the Flutter player's Kes button). */
@UnstableApi
object VideoTrimmer {
    private val worker = Executors.newSingleThreadExecutor()
    private var busy = false

    fun trim(context: Context, path: String, start: Long, end: Long, done: (String?, String?) -> Unit) {
        val main = Handler(Looper.getMainLooper())
        if (busy) { done(null, "Başka bir kesme işlemi sürüyor"); return }
        if (end <= start) { done(null, "Geçerli bir aralık seçin"); return }
        if (Build.VERSION.SDK_INT < 29) { done(null, "Video kesme Android 10 ve üzerinde kullanılabilir"); return }
        busy = true
        val file = File(context.cacheDir, "BMusic_Klip_${System.currentTimeMillis()}.mp4")
        val source = if (path.startsWith("content:") || path.startsWith("file:")) Uri.parse(path) else Uri.fromFile(File(path))
        val item = EditedMediaItem.Builder(MediaItem.Builder().setUri(source)
            .setClippingConfiguration(MediaItem.ClippingConfiguration.Builder().setStartPositionMs(start).setEndPositionMs(end).build()).build()).build()
        main.post {
            try {
                Transformer.Builder(context).setVideoMimeType(MimeTypes.VIDEO_H264).setAudioMimeType(MimeTypes.AUDIO_AAC)
                    .addListener(object : Transformer.Listener {
                        override fun onCompleted(composition: Composition, result: ExportResult) {
                            worker.execute {
                                var uri: Uri? = null
                                try {
                                    val resolver = context.contentResolver
                                    uri = resolver.insert(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, ContentValues().apply {
                                        put(MediaStore.MediaColumns.DISPLAY_NAME, file.name)
                                        put(MediaStore.MediaColumns.MIME_TYPE, "video/mp4")
                                        put(MediaStore.MediaColumns.RELATIVE_PATH, "Movies/BMusic")
                                        put(MediaStore.MediaColumns.IS_PENDING, 1)
                                    }) ?: throw IllegalStateException("Dosya oluşturulamadı")
                                    resolver.openOutputStream(uri!!)?.use { out -> file.inputStream().use { it.copyTo(out) } } ?: throw IllegalStateException("Dosya yazılamadı")
                                    resolver.update(uri!!, ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) }, null, null)
                                    android.util.Log.i("flutter", "[BMusic feature] trimmed=${file.name}")
                                    main.post { busy = false; done(file.name, null) }
                                } catch (e: Exception) {
                                    uri?.let { context.contentResolver.delete(it, null, null) }
                                    main.post { busy = false; done(null, e.message ?: "Kaydedilemedi") }
                                } finally { file.delete() }
                            }
                        }
                        override fun onError(composition: Composition, result: ExportResult, exception: ExportException) {
                            file.delete(); busy = false
                            done(null, "Bu video biçimi bu cihazda kesilemiyor (${exception.errorCodeName})")
                        }
                    }).build().start(item, file.absolutePath)
            } catch (e: Exception) { file.delete(); busy = false; done(null, e.message ?: "Kesme başlatılamadı") }
        }
    }
}
