import '../models/alarm.dart';

/// First time the alarm fires strictly after [now], in the local time zone.
///
/// The native Android scheduler uses the same rules. Repeat days are ISO
/// weekdays (Monday = 1 ... Sunday = 7); an empty set means a one-time alarm.
DateTime nextOccurrence(Alarm alarm, DateTime now) {
  for (var offset = 0; offset <= 7; offset++) {
    final day = DateTime(now.year, now.month, now.day + offset);
    if (alarm.repeatDays.isNotEmpty &&
        !alarm.repeatDays.contains(day.weekday)) {
      continue;
    }
    final candidate = DateTime(
      day.year,
      day.month,
      day.day,
      alarm.hour,
      alarm.minute,
    );
    if (candidate.isAfter(now)) return candidate;
  }
  return DateTime(now.year, now.month, now.day + 8, alarm.hour, alarm.minute);
}
