package com.novakoki.alarm

import android.Manifest
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.view.WindowManager
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var pendingNotificationResult: MethodChannel.Result? = null

    @Suppress("DEPRECATION")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O_MR1) {
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON,
            )
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel = ch
        ch.setMethodCallHandler { call, result -> handle(call, result) }
        AlarmEvents.listener = { id ->
            runOnUiThread { channel?.invokeMethod("alarmRinging", id) }
        }
    }

    override fun onDestroy() {
        AlarmEvents.listener = null
        super.onDestroy()
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "syncAlarms" -> {
                try {
                    val json = call.arguments as? String ?: "[]"
                    AlarmScheduler.syncFromFlutter(applicationContext, NativeAlarm.parseList(json))
                    result.success(true)
                } catch (e: Exception) {
                    result.error("sync_failed", e.message, null)
                }
            }
            "getRingingAlarm" ->
                result.success(if (AlarmService.ringingId >= 0) AlarmService.ringingId else null)
            "stopAlarm" -> {
                AlarmService.stop()
                result.success(null)
            }
            "snooze" -> {
                val id = call.argument<Int>("alarmId") ?: -1
                val minutes = call.argument<Int>("minutes") ?: 5
                AlarmService.stop()
                AlarmStore.get(applicationContext, id)?.let {
                    AlarmScheduler.scheduleSnooze(applicationContext, it, minutes)
                }
                result.success(null)
            }
            "getStatus" -> result.success(status())
            "requestNotificationPermission" -> requestNotifications(result)
            "openFullScreenIntentSettings" -> {
                openSettings(
                    if (Build.VERSION.SDK_INT >= 34) {
                        Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, Uri.parse("package:$packageName"))
                    } else {
                        notificationSettingsIntent()
                    },
                )
                result.success(null)
            }
            "openNotificationSettings" -> {
                openSettings(notificationSettingsIntent())
                result.success(null)
            }
            "openBatterySettings" -> {
                openSettings(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                result.success(null)
            }
            "previewSound" -> {
                SoundPlayer.playPreview(applicationContext, call.argument<String>("sound") ?: "nova_pulse")
                result.success(null)
            }
            "stopPreview" -> {
                SoundPlayer.stopPreview()
                result.success(null)
            }
            "consumeFiredOneShots" -> result.success(AlarmStore.consumeFired(applicationContext))
            else -> result.notImplemented()
        }
    }

    private fun notificationSettingsIntent(): Intent =
        Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName)

    private fun openSettings(intent: Intent) {
        try {
            startActivity(intent)
        } catch (e: Exception) {
            // Settings screen not available on this device.
        }
    }

    private fun status(): Map<String, Any> {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val fullScreen = if (Build.VERSION.SDK_INT >= 34) nm.canUseFullScreenIntent() else true
        val power = getSystemService(Context.POWER_SERVICE) as PowerManager
        return mapOf(
            "notificationsGranted" to NotificationManagerCompat.from(this).areNotificationsEnabled(),
            "fullScreenIntentGranted" to fullScreen,
            "batteryUnrestricted" to power.isIgnoringBatteryOptimizations(packageName),
            "sdkInt" to Build.VERSION.SDK_INT,
        )
    }

    private fun requestNotifications(result: MethodChannel.Result) {
        val granted = Build.VERSION.SDK_INT < 33 ||
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        if (granted) {
            result.success(NotificationManagerCompat.from(this).areNotificationsEnabled())
            return
        }
        pendingNotificationResult?.success(false)
        pendingNotificationResult = result
        ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST_NOTIFICATIONS)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_NOTIFICATIONS) {
            val ok = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingNotificationResult?.success(ok)
            pendingNotificationResult = null
        }
    }

    companion object {
        private const val CHANNEL = "com.novakoki.alarm/native"
        private const val REQUEST_NOTIFICATIONS = 9001
    }
}
