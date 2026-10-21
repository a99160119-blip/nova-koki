package com.novakoki.alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != AlarmScheduler.ACTION_FIRE) return
        val id = intent.getIntExtra(AlarmScheduler.EXTRA_ALARM_ID, -1)
        val isSnooze = intent.getBooleanExtra(AlarmScheduler.EXTRA_SNOOZE, false)
        val alarm = AlarmStore.get(context, id) ?: return
        if (!isSnooze && !alarm.enabled) return

        if (!isSnooze) {
            if (alarm.daysMask != 0) {
                // Repeating alarm: schedule the next occurrence right away.
                AlarmScheduler.schedule(context, alarm)
            } else {
                AlarmStore.markOneShotFired(context, id)
            }
        }
        AlarmService.start(context, alarm)
    }
}
