package com.novakoki.alarm

/** Lets the running Flutter activity (if any) learn immediately that an alarm started ringing. */
object AlarmEvents {
    @Volatile
    var listener: ((Int) -> Unit)? = null

    fun notifyRinging(alarmId: Int) {
        listener?.invoke(alarmId)
    }
}
