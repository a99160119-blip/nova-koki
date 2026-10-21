package com.novakoki.alarm

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Handler
import android.os.Looper

/** Plays the bundled alarm sounds (or the system alarm tone) on the alarm audio stream. */
object SoundPlayer {
    private var alarmPlayer: MediaPlayer? = null
    private var previewPlayer: MediaPlayer? = null
    private val handler = Handler(Looper.getMainLooper())
    private val stopPreviewRunnable = Runnable { stopPreview() }

    private fun rawResource(sound: String): Int = when (sound) {
        "nova_pulse" -> R.raw.nova_pulse
        "aurora" -> R.raw.aurora
        "beacon" -> R.raw.beacon
        else -> 0
    }

    private fun create(context: Context, sound: String, loop: Boolean): MediaPlayer? {
        val app = context.applicationContext
        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        val bundled = tryBundled(app, sound, loop, attrs)
        return bundled ?: trySystem(app, loop, attrs)
    }

    private fun tryBundled(app: Context, sound: String, loop: Boolean, attrs: AudioAttributes): MediaPlayer? {
        val res = rawResource(sound)
        if (res == 0) return null
        return try {
            val mp = MediaPlayer()
            mp.setAudioAttributes(attrs)
            val afd = app.resources.openRawResourceFd(res)
            mp.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
            afd.close()
            mp.isLooping = loop
            mp.prepare()
            mp.start()
            mp
        } catch (e: Exception) {
            null
        }
    }

    private fun trySystem(app: Context, loop: Boolean, attrs: AudioAttributes): MediaPlayer? {
        return try {
            val uri = RingtoneManager.getActualDefaultRingtoneUri(app, RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            val mp = MediaPlayer()
            mp.setAudioAttributes(attrs)
            mp.setDataSource(app, uri)
            mp.isLooping = loop
            mp.prepare()
            mp.start()
            mp
        } catch (e: Exception) {
            null
        }
    }

    @Synchronized
    fun playAlarm(context: Context, sound: String) {
        stopAlarm()
        stopPreview()
        alarmPlayer = create(context, sound, true)
    }

    @Synchronized
    fun stopAlarm() {
        alarmPlayer?.let {
            try {
                it.stop()
            } catch (e: Exception) {
                // Already stopped.
            }
            it.release()
        }
        alarmPlayer = null
    }

    @Synchronized
    fun playPreview(context: Context, sound: String) {
        stopPreview()
        previewPlayer = create(context, sound, false)
        handler.postDelayed(stopPreviewRunnable, 5000)
    }

    @Synchronized
    fun stopPreview() {
        handler.removeCallbacks(stopPreviewRunnable)
        previewPlayer?.let {
            try {
                it.stop()
            } catch (e: Exception) {
                // Already stopped.
            }
            it.release()
        }
        previewPlayer = null
    }
}
