package com.novakoki.alarm

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import java.util.Calendar

/**
 * Schedules alarms with AlarmManager.setAlarmClock(). That API is exact, shows the alarm
 * icon in the status bar, is allowed while the device is idle, and does not require the
 * SCHEDULE_EXACT_ALARM permission.
 */
object AlarmScheduler {
    const val ACTION_FIRE = "com.novakoki.alarm.ACTION_FIRE"
    const val EXTRA_ALARM_ID = "nk_alarm_id"
    const val EXTRA_SNOOZE = "nk_snooze"
    private const val SNOOZE_OFFSET = 1_000_000

    /** Next trigger strictly after [now], using the device's current time zone. */
    fun nextTrigger(a: NativeAlarm, now: Long = System.currentTimeMillis()): Long {
        for (offset in 0..7) {
            val c = Calendar.getInstance()
            c.timeInMillis = now
            c.add(Calendar.DAY_OF_YEAR, offset)
            c.set(Calendar.HOUR_OF_DAY, a.hour)
            c.set(Calendar.MINUTE, a.minute)
            c.set(Calendar.SECOND, 0)
            c.set(Calendar.MILLISECOND, 0)
            val weekday = isoWeekday(c)
            if (a.daysMask != 0 && (a.daysMask and (1 shl (weekday - 1))) == 0) continue
            if (c.timeInMillis > now) return c.timeInMillis
        }
        return now + 24L * 60L * 60L * 1000L
    }

    /** Monday = 1 ... Sunday = 7, matching Dart's DateTime.weekday. */
    private fun isoWeekday(c: Calendar): Int {
        val d = c.get(Calendar.DAY_OF_WEEK)
        return if (d == Calendar.SUNDAY) 7 else d - 1
    }

    private fun alarmManager(context: Context) =
        context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    private fun firePendingIntent(context: Context, requestCode: Int, alarmId: Int, snooze: Boolean): PendingIntent {
        val intent = Intent(context, AlarmReceiver::class.java)
            .setAction(ACTION_FIRE)
            .putExtra(EXTRA_ALARM_ID, alarmId)
            .putExtra(EXTRA_SNOOZE, snooze)
        return PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun showPendingIntent(context: Context, requestCode: Int): PendingIntent =
        PendingIntent.getActivity(
            context,
            requestCode,
            Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    private fun setClock(context: Context, requestCode: Int, alarmId: Int, snooze: Boolean, at: Long) {
        val info = AlarmManager.AlarmClockInfo(at, showPendingIntent(context, requestCode))
        alarmManager(context).setAlarmClock(info, firePendingIntent(context, requestCode, alarmId, snooze))
    }

    /** Schedules the next occurrence. Re-using the same request code replaces any earlier one. */
    fun schedule(context: Context, a: NativeAlarm, at: Long = nextTrigger(a)) {
        setClock(context, a.id, a.id, false, at)
        AlarmStore.setTrigger(context, a.id, at)
    }

    fun scheduleSnooze(context: Context, a: NativeAlarm, minutes: Int) {
        val at = System.currentTimeMillis() + minutes.coerceAtLeast(1) * 60_000L
        setClock(context, a.id + SNOOZE_OFFSET, a.id, true, at)
    }

    fun cancel(context: Context, id: Int, includeSnooze: Boolean) {
        val am = alarmManager(context)
        am.cancel(firePendingIntent(context, id, id, false))
        if (includeSnooze) {
            am.cancel(firePendingIntent(context, id + SNOOZE_OFFSET, id, true))
        }
    }

    /** Called when Flutter pushes its alarm list: cancel, de-duplicate and re-schedule. */
    fun syncFromFlutter(context: Context, alarms: List<NativeAlarm>) {
        val previous = AlarmStore.scheduledIds(context)
        val newIds = alarms.map { it.id }.toSet()
        AlarmStore.saveAll(context, alarms)
        for (id in previous) {
            cancel(context, id, includeSnooze = id !in newIds)
        }
        val scheduled = HashSet<Int>()
        for (a in alarms) {
            // Always cancel first so one request code can never be scheduled twice.
            cancel(context, a.id, includeSnooze = false)
            if (a.enabled) {
                schedule(context, a)
                scheduled.add(a.id)
            }
        }
        AlarmStore.setScheduledIds(context, scheduled)
    }

    /**
     * Re-creates alarms after boot, app update or time/time-zone change.
     * After a reboot a one-time alarm whose time already passed is treated as missed
     * (it is disabled instead of being moved to tomorrow).
     */
    fun rescheduleAll(context: Context, afterRestart: Boolean) {
        val now = System.currentTimeMillis()
        val scheduled = HashSet<Int>()
        for (a in AlarmStore.loadAll(context)) {
            if (!a.enabled) continue
            if (afterRestart && a.daysMask == 0) {
                val trigger = AlarmStore.getTrigger(context, a.id)
                if (trigger != null) {
                    if (trigger <= now) {
                        AlarmStore.markOneShotFired(context, a.id)
                    } else {
                        schedule(context, a, trigger)
                        scheduled.add(a.id)
                    }
                    continue
                }
            }
            schedule(context, a)
            scheduled.add(a.id)
        }
        AlarmStore.setScheduledIds(context, scheduled)
    }
}
