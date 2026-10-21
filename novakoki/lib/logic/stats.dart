import '../core/utils.dart';
import '../models/alarm.dart';
import '../models/session.dart';
import 'alarm_schedule.dart';

class StatsCalculator {
  /// Completed missions per day for the last [days] days, oldest first,
  /// ending with [today].
  static List<int> lastDaysCounts(
    List<WakeSession> sessions,
    DateTime today,
    int days,
  ) {
    final counts = List<int>.filled(days, 0);
    for (final s in sessions) {
      if (!s.completed) continue;
      for (var i = 0; i < days; i++) {
        final day = DateTime(
          today.year,
          today.month,
          today.day - (days - 1 - i),
        );
        if (isSameDay(s.completedAt, day)) {
          counts[i]++;
          break;
        }
      }
    }
    return counts;
  }

  static int completedInMonth(List<WakeSession> sessions, DateTime today) {
    return sessions
        .where(
          (s) =>
              s.completed &&
              s.completedAt.year == today.year &&
              s.completedAt.month == today.month,
        )
        .length;
  }

  static int completedOn(List<WakeSession> sessions, DateTime day) {
    return sessions
        .where((s) => s.completed && isSameDay(s.completedAt, day))
        .length;
  }

  /// Enabled alarms that apply to [now]'s date.
  static int scheduledToday(List<Alarm> alarms, DateTime now) {
    var count = 0;
    for (final a in alarms) {
      if (!a.enabled) continue;
      if (a.repeatDays.isEmpty) {
        if (isSameDay(nextOccurrence(a, now), now)) count++;
      } else if (a.repeatDays.contains(now.weekday)) {
        count++;
      }
    }
    return count;
  }
}
