package com.example.o_house

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ActivityNotFoundException
import android.content.Intent
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.os.Bundle
import androidx.media3.common.MediaItem
import androidx.annotation.OptIn
import androidx.media3.common.C
import androidx.media3.common.Format
import androidx.media3.common.Metadata
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.container.Mp4OrientationData
import androidx.media3.effect.Presentation
import androidx.media3.muxer.BufferInfo
import androidx.media3.muxer.Mp4Muxer
import androidx.media3.muxer.Muxer
import androidx.media3.muxer.SeekableMuxerOutput
import androidx.media3.transformer.AudioEncoderSettings
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.google.common.collect.ImmutableList
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer
import kotlin.math.roundToInt

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // The channel every push names (android.notification.channelId in
        // o-house-api's fcm.ts). Made here rather than through a Flutter
        // plugin: one channel needs no dependency. Re-creating it each start is
        // a no-op except that it renames it to the phone's current language.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            getSystemService(NotificationManager::class.java).createNotificationChannel(
                NotificationChannel("rounds", getString(R.string.rounds_channel), NotificationManager.IMPORTANCE_HIGH),
            )
        }
    }

    // Force update (F-11, lib/app_release.dart): this build's version, and
    // the download link opened in the browser. Two calls, so no plugin.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "o_house/app").setMethodCallHandler { call, result ->
            when (call.method) {
                "build" -> {
                    val info = packageManager.getPackageInfo(packageName, 0)
                    val code = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        info.longVersionCode
                    } else {
                        @Suppress("DEPRECATION")
                        info.versionCode.toLong()
                    }
                    result.success(mapOf("name" to (info.versionName ?: ""), "code" to code))
                }
                "openUrl" -> {
                    try {
                        startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(call.arguments as String)))
                        result.success(null)
                    } catch (e: ActivityNotFoundException) {
                        result.error("NO_BROWSER", e.message, null)
                    }
                }
                "compressVideo" -> compressVideo(
                    call.argument<String>("input")!!,
                    call.argument<String>("output")!!,
                    call.argument<Int>("videoBitrate")!!,
                    call.argument<Int>("maxMs")!!.toLong(),
                    result,
                )
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Video evidence at most 1 MB (lib/video_shrink.dart picks the bitrate
     * and checks the size). Media3 Transformer, Android's own encoder: 480 p
     * on the short side, H.264 (HEVC from some cameras won't play in every
     * browser the portal runs in), AAC sound at 48 kbps. Only the first
     * [maxMs] are kept: a cleaner whose camera ran past 20 s keeps the clip
     * rather than being told to record it again. Answers the output's size
     * in bytes. The listener fires on this (main) thread.
     */
    @OptIn(UnstableApi::class) // Transformer's encoder settings are marked unstable
    private fun compressVideo(input: String, output: String, videoBitrate: Int, maxMs: Long, result: MethodChannel.Result) {
        val height = try {
            shrunkHeight(input)
        } catch (e: Exception) {
            result.error("VIDEO_UNREADABLE", e.message, null)
            return
        }
        val clip = MediaItem.Builder()
            .setUri(Uri.fromFile(File(input)))
            .setClippingConfiguration(MediaItem.ClippingConfiguration.Builder().setEndPositionMs(maxMs).build())
            .build()
        val item = EditedMediaItem.Builder(clip)
            .setEffects(Effects(listOf(), listOf(Presentation.createForHeight(height))))
            .build()
        val encoders = DefaultEncoderFactory.Builder(this)
            .setRequestedVideoEncoderSettings(VideoEncoderSettings.Builder().setBitrate(videoBitrate).build())
            .setRequestedAudioEncoderSettings(AudioEncoderSettings.Builder().setBitrate(48_000).build())
            .build()
        Transformer.Builder(this)
            .setVideoMimeType(MimeTypes.VIDEO_H264)
            .setAudioMimeType(MimeTypes.AUDIO_AAC)
            .setEncoderFactory(encoders)
            .setMuxerFactory(CompactMp4Muxer.Factory())
            .addListener(object : Transformer.Listener {
                override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                    result.success(File(output).length())
                }

                override fun onError(composition: Composition, exportResult: ExportResult, exportException: ExportException) {
                    result.error("VIDEO_COMPRESS_FAILED", exportException.message, null)
                }
            })
            .build()
            .start(item, output)
    }

    /**
     * The output height that makes the short side at most 480, as the clip
     * is shown (a portrait clip is stored landscape with a rotation). Even,
     * as encoders want; never upscaled. Presentation keeps the aspect ratio.
     */
    private fun shrunkHeight(input: String): Int {
        val r = MediaMetadataRetriever()
        try {
            r.setDataSource(input)
            val w = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)!!.toInt()
            val h = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)!!.toInt()
            val rotation = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toInt() ?: 0
            val shownHeight = if (rotation == 90 || rotation == 270) w else h
            val scale = minOf(1.0, 480.0 / minOf(w, h))
            return (shownHeight * scale / 2).roundToInt() * 2
        } finally {
            r.release()
        }
    }
}

/**
 * Transformer's own MP4 writer (InAppMp4Muxer) reserves 400,000 bytes at the
 * start of every file so it can stream. A 1 MB clip can't spare that: on the
 * OPPO test (19 Oct) 57% of a 0.65 MB clip was that empty box. This writes
 * the index at the end instead, and keeps what InAppMp4Muxer adds that we
 * need: the rotation, or a portrait clip plays sideways. The camera's other
 * metadata (capture fps, vendor tags) isn't evidence and is dropped.
 */
@OptIn(UnstableApi::class)
private class CompactMp4Muxer(path: String) : Muxer {
    private val muxer = Mp4Muxer.Builder(SeekableMuxerOutput.of(FileOutputStream(path)))
        .setAttemptStreamableOutputEnabled(false)
        .build()

    override fun addTrack(format: Format): Int {
        val id = muxer.addTrack(format)
        if (MimeTypes.isVideo(format.sampleMimeType)) muxer.addMetadataEntry(Mp4OrientationData(format.rotationDegrees))
        return id
    }

    override fun writeSampleData(trackId: Int, data: ByteBuffer, info: BufferInfo) = muxer.writeSampleData(trackId, data, info)

    override fun addMetadataEntry(entry: Metadata.Entry) {}

    override fun close() = muxer.close()

    class Factory : Muxer.Factory {
        override fun create(path: String): Muxer = CompactMp4Muxer(path)

        override fun getSupportedSampleMimeTypes(trackType: Int): ImmutableList<String> = when (trackType) {
            C.TRACK_TYPE_VIDEO -> Mp4Muxer.SUPPORTED_VIDEO_SAMPLE_MIME_TYPES
            C.TRACK_TYPE_AUDIO -> Mp4Muxer.SUPPORTED_AUDIO_SAMPLE_MIME_TYPES
            else -> ImmutableList.of()
        }
    }
}
