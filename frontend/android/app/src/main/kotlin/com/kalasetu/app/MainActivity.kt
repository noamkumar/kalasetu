package com.kalasetu.app

import android.media.AudioAttributes
import android.media.MediaDataSource
import android.media.MediaPlayer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.kalasetu.app/audio_player"
    private var mediaPlayer: MediaPlayer? = null
    private var methodChannel: MethodChannel? = null
    private var activeDataSource: MediaDataSource? = null

    private fun getOrCreatePlayer(): MediaPlayer {
        var player = mediaPlayer
        if (player == null) {
            player = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .setUsage(AudioAttributes.USAGE_ASSISTANCE_ACCESSIBILITY)
                        .build()
                )
            }
            mediaPlayer = player
        }
        return player
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Pre-warm the player at startup so the first playback is instantaneous
        getOrCreatePlayer()

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "playFile" -> {
                    val filePath = call.argument<String>("path")
                    if (filePath == null || !File(filePath).exists()) {
                        result.error("FILE_NOT_FOUND", "Audio file does not exist", null)
                        return@setMethodCallHandler
                    }
                    try {
                        stopPlaying()
                        val player = getOrCreatePlayer()
                        player.setDataSource(filePath)
                        player.setOnCompletionListener {
                            stopPlaying()
                            methodChannel?.invokeMethod("onComplete", null)
                        }
                        player.setOnErrorListener { _, _, _ ->
                            stopPlaying()
                            methodChannel?.invokeMethod("onError", null)
                            true
                        }
                        player.prepare()
                        player.start()
                        result.success(true)
                    } catch (e: Exception) {
                        stopPlaying()
                        result.error("PLAY_ERROR", e.message, null)
                    }
                }
                "playBytes" -> {
                    val audioBytes = call.argument<ByteArray>("bytes")
                    if (audioBytes == null || audioBytes.isEmpty()) {
                        result.error("EMPTY_BYTES", "Audio bytes are empty", null)
                        return@setMethodCallHandler
                    }
                    try {
                        stopPlaying()
                        val player = getOrCreatePlayer()
                        val dataSource = object : MediaDataSource() {
                            override fun readAt(position: Long, buffer: ByteArray, offset: Int, size: Int): Int {
                                if (position >= audioBytes.size) return -1
                                val remaining = audioBytes.size - position.toInt()
                                val bytesToRead = if (size > remaining) remaining else size
                                System.arraycopy(audioBytes, position.toInt(), buffer, offset, bytesToRead)
                                return bytesToRead
                            }
                            override fun getSize(): Long = audioBytes.size.toLong()
                            override fun close() {}
                        }
                        activeDataSource = dataSource
                        player.setDataSource(dataSource)
                        player.setOnCompletionListener {
                            stopPlaying()
                            methodChannel?.invokeMethod("onComplete", null)
                        }
                        player.setOnErrorListener { _, _, _ ->
                            stopPlaying()
                            methodChannel?.invokeMethod("onError", null)
                            true
                        }
                        player.prepare()
                        player.start()
                        result.success(true)
                    } catch (e: Exception) {
                        stopPlaying()
                        result.error("PLAY_ERROR", e.message, null)
                    }
                }
                "stop" -> {
                    stopPlaying()
                    result.success(true)
                }
                "isPlaying" -> {
                    val playing = mediaPlayer?.isPlaying ?: false
                    result.success(playing)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun stopPlaying() {
        try {
            mediaPlayer?.let {
                if (it.isPlaying) {
                    it.stop()
                }
                it.reset() // Re-arms the player for immediate reuse without destroying native handles
            }
            activeDataSource?.close()
            activeDataSource = null
        } catch (_: Exception) {}
    }

    override fun onDestroy() {
        try {
            mediaPlayer?.let {
                if (it.isPlaying) {
                    it.stop()
                }
                it.release()
            }
            mediaPlayer = null
            activeDataSource?.close()
            activeDataSource = null
        } catch (_: Exception) {}
        super.onDestroy()
    }
}
