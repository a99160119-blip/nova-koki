package com.novakoki.alarm

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat

/**
 * Foreground service that plays the alarm sound, vibrates, and shows a full-screen
 * notification that opens the app. It stops when the user finishes the mission, snoozes,
 * stops the alarm, or after [MAX_RING_MS].
 */
class AlarmService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private val timeout = Runnable { stopRinging(timedOut = true) }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val id = intent?.getIntExtra(EXTRA_ID, -1) ?: -1
        val title = intent?.getStringExtra(EXTRA_TITLE) ?: ""
        val sound = intent?.getStringExtra(EXTRA_SOUND) ?: "nova_pulse"
        val vibrate = intent?.getBooleanExtra(EXTRA_VIBRATE, true) ?: true

        ensureChannels(this)
        ServiceCompat.startForeground(
            this,
            NOTIFICATION_ID,
            buildNotification(id, title),
            ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
        )
        instance = this
        ringingId = id

        SoundPlayer.playAlarm(this, sound)
        stopVibration()
        if (vibrate) startVibration()

        handler.removeCallbacks(timeout)
        handler.postDelayed(timeout, MAX_RING_MS)
        AlarmEvents.notifyRinging(id)
        return START_NOT_STICKY
    }

    fun stopRinging(timedOut: Boolean) {
        handler.removeCallbacks(timeout)
        SoundPlayer.stopAlarm()
        stopVibration()
        val wasRinging = ringingId
        ringingId = -1
        instance = null
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        stopSelf()
        if (timedOut) postMissedNotification(wasRinging)
    }

    override fun onDestroy() {
        handler.removeCallbacks(timeout)
        SoundPlayer.stopAlarm()
        stopVibration()
        if (instance === this) {
            instance = null
            ringingId = -1
        }
        super.onDestroy()
    }

    private fun openAppIntent(id: Int): PendingIntent {
        val open = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(AlarmScheduler.EXTRA_ALARM_ID, id)
        }
        return PendingIntent.getActivity(
            this,
            7001,
            open,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun buildNotification(id: Int, title: String): Notification {
        val pi = openAppIntent(id)
        return NotificationCompat.Builder(this, CHANNEL_ALARM)
            .setSmallIcon(R.drawable.ic_stat_nova)
            .setContentTitle(if (title.isBlank()) getString(R.string.app_name) else title)
            .setContentText(getString(R.string.alarm_notification_text))
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setContentIntent(pi)
            .setFullScreenIntent(pi, true)
            .build()
    }

    private fun postMissedNotification(id: Int) {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val n = NotificationCompat.Builder(this, CHANNEL_MISSED)
            .setSmallIcon(R.drawable.ic_stat_nova)
            .setContentTitle(getString(R.string.app_name))
            .setContentText(getString(R.string.missed_alarm_text))
            .setAutoCancel(true)
            .setContentIntent(openAppIntent(id))
            .build()
        try {
            nm.notify(NOTIFICATION_MISSED_ID, n)
        } catch (e: SecurityException) {
            // Notification permission denied; nothing more can be shown.
        }
    }

    @Suppress("DEPRECATION")
    private fun vibrator(): Vibrator? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)?.defaultVibrator
        } else {
            getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }

    @Suppress("DEPRECATION")
    private fun startVibration() {
        val v = vibrator() ?: return
        val pattern = longArrayOf(0, 700, 500)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            v.vibrate(VibrationEffect.createWaveform(pattern, 0))
        } else {
            v.vibrate(pattern, 0)
        }
    }

    private fun stopVibration() {
        vibrator()?.cancel()
    }

    companion object {
        const val CHANNEL_ALARM = "nova_alarm"
        const val CHANNEL_MISSED = "nova_missed"
        private const val NOTIFICATION_ID = 4101
        private const val NOTIFICATION_MISSED_ID = 4102
        private const val MAX_RING_MS = 10 * 60 * 1000L
        private const val EXTRA_ID = "id"
        private const val EXTRA_TITLE = "title"
        private const val EXTRA_SOUND = "sound"
        private const val EXTRA_VIBRATE = "vibrate"

        @Volatile
        var ringingId: Int = -1

        @Volatile
        var instance: AlarmService? = null

        fun start(context: Context, alarm: NativeAlarm) {
            val intent = Intent(context, AlarmService::class.java)
                .putExtra(EXTRA_ID, alarm.id)
                .putExtra(EXTRA_TITLE, alarm.title)
                .putExtra(EXTRA_SOUND, alarm.sound)
                .putExtra(EXTRA_VIBRATE, alarm.vibrate)
            try {
                ContextCompat.startForegroundService(context, intent)
            } catch (e: Exception) {
                // Android refused to start a foreground service from the background.
                // Fall back to a full-screen notification so the user is still alerted.
                ensureChannels(context)
                postFallback(context, alarm)
            }
        }

        /** Stops the current alarm (sound, vibration, notification). Must run on the main thread. */
        fun stop() {
            instance?.stopRinging(timedOut = false)
        }

        private fun postFallback(context: Context, alarm: NativeAlarm) {
            val open = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra(AlarmScheduler.EXTRA_ALARM_ID, alarm.id)
            }
            val pi = PendingIntent.getActivity(
                context,
                7002,
                open,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            val n = NotificationCompat.Builder(context, CHANNEL_ALARM)
                .setSmallIcon(R.drawable.ic_stat_nova)
                .setContentTitle(if (alarm.title.isBlank()) context.getString(R.string.app_name) else alarm.title)
                .setContentText(context.getString(R.string.alarm_notification_text))
                .setCategory(NotificationCompat.CATEGORY_ALARM)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setAutoCancel(true)
                .setContentIntent(pi)
                .setFullScreenIntent(pi, true)
                .build()
            try {
                val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                nm.notify(NOTIFICATION_ID, n)
            } catch (e: SecurityException) {
                // Notification permission denied.
            }
        }

        fun ensureChannels(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val alarm = NotificationChannel(
                CHANNEL_ALARM,
                context.getString(R.string.alarm_channel_name),
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                setSound(null, null)
                enableVibration(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            val missed = NotificationChannel(
                CHANNEL_MISSED,
                context.getString(R.string.missed_channel_name),
                NotificationManager.IMPORTANCE_DEFAULT,
            )
            nm.createNotificationChannel(alarm)
            nm.createNotificationChannel(missed)
        }
    }
}
