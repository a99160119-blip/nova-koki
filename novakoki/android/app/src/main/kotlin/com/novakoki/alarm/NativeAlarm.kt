package com.novakoki.alarm

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/** Alarm as synced from Flutter. [daysMask]: bit 0 = Monday ... bit 6 = Sunday; 0 = one-time. */
data class NativeAlarm(
    val id: Int,
    val hour: Int,
    val minute: Int,
    val daysMask: Int,
    val enabled: Boolean,
    val title: String,
    val sound: String,
    val vibrate: Boolean,
    val snoozeEnabled: Boolean,
    val snoozeMinutes: Int,
) {
    fun toJson(): JSONObject = JSONObject()
        .put("id", id)
        .put("hour", hour)
        .put("minute", minute)
        .put("daysMask", daysMask)
        .put("enabled", enabled)
        .put("title", title)
        .put("sound", sound)
        .put("vibrate", vibrate)
        .put("snoozeEnabled", snoozeEnabled)
        .put("snoozeMinutes", snoozeMinutes)

    companion object {
        fun fromJson(o: JSONObject): NativeAlarm = NativeAlarm(
            id = o.getInt("id"),
            hour = o.getInt("hour"),
            minute = o.getInt("minute"),
            daysMask = o.optInt("daysMask", 0),
            enabled = o.optBoolean("enabled", true),
            title = o.optString("title", ""),
            sound = o.optString("sound", "nova_pulse"),
            vibrate = o.optBoolean("vibrate", true),
            snoozeEnabled = o.optBoolean("snoozeEnabled", false),
            snoozeMinutes = o.optInt("snoozeMinutes", 5),
        )

        fun parseList(json: String): List<NativeAlarm> {
            val arr = JSONArray(json)
            val out = ArrayList<NativeAlarm>()
            for (i in 0 until arr.length()) {
                out.add(fromJson(arr.getJSONObject(i)))
            }
            return out
        }
    }
}

/** Small persistent store used by the receivers, which run without the Flutter engine. */
object AlarmStore {
    private const val PREFS = "nova_native_alarms"
    private const val KEY_ALARMS = "alarms"
    private const val KEY_SCHEDULED = "scheduled_ids"
    private const val KEY_FIRED = "fired_one_shots"
    private const val KEY_TRIGGER_PREFIX = "trigger_"

    private fun prefs(c: Context) =
        c.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    @Synchronized
    fun saveAll(c: Context, alarms: List<NativeAlarm>) {
        val arr = JSONArray()
        alarms.forEach { arr.put(it.toJson()) }
        prefs(c).edit().putString(KEY_ALARMS, arr.toString()).commit()
    }

    @Synchronized
    fun loadAll(c: Context): List<NativeAlarm> {
        val raw = prefs(c).getString(KEY_ALARMS, null) ?: return emptyList()
        return try {
            NativeAlarm.parseList(raw)
        } catch (e: Exception) {
            emptyList()
        }
    }

    fun get(c: Context, id: Int): NativeAlarm? = loadAll(c).firstOrNull { it.id == id }

    @Synchronized
    fun scheduledIds(c: Context): Set<Int> =
        (prefs(c).getStringSet(KEY_SCHEDULED, emptySet()) ?: emptySet())
            .mapNotNull { it.toIntOrNull() }
            .toSet()

    @Synchronized
    fun setScheduledIds(c: Context, ids: Set<Int>) {
        prefs(c).edit().putStringSet(KEY_SCHEDULED, ids.map { it.toString() }.toSet()).commit()
    }

    @Synchronized
    fun setTrigger(c: Context, id: Int, millis: Long) {
        prefs(c).edit().putLong(KEY_TRIGGER_PREFIX + id, millis).commit()
    }

    @Synchronized
    fun getTrigger(c: Context, id: Int): Long? {
        val p = prefs(c)
        return if (p.contains(KEY_TRIGGER_PREFIX + id)) p.getLong(KEY_TRIGGER_PREFIX + id, 0L) else null
    }

    /** One-time alarm has fired (or was missed): disable the native copy and remember it for Flutter. */
    @Synchronized
    fun markOneShotFired(c: Context, id: Int) {
        saveAll(c, loadAll(c).map { if (it.id == id) it.copy(enabled = false) else it })
        val fired = (prefs(c).getStringSet(KEY_FIRED, emptySet()) ?: emptySet()).toMutableSet()
        fired.add(id.toString())
        prefs(c).edit().putStringSet(KEY_FIRED, fired).commit()
    }

    @Synchronized
    fun consumeFired(c: Context): List<Int> {
        val fired = (prefs(c).getStringSet(KEY_FIRED, emptySet()) ?: emptySet())
            .mapNotNull { it.toIntOrNull() }
        prefs(c).edit().remove(KEY_FIRED).commit()
        return fired
    }
}
