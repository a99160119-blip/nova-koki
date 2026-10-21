package com.novakoki.alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Restores alarms after a restart, app update, or a time / time-zone change. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED -> AlarmScheduler.rescheduleAll(context, afterRestart = true)
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED -> AlarmScheduler.rescheduleAll(context, afterRestart = false)
        }
    }
}
