import 'package:flutter_test/flutter_test.dart';
import 'package:novakoki/logic/stats.dart';
import 'package:novakoki/models/alarm.dart';
import 'package:novakoki/models/session.dart';

WakeSession _session(String id, DateTime completedAt) => WakeSession(
  id: id,
  alarmId: 1,
  scheduledAt: null,
  startedAt: completedAt,
  completedAt: completedAt,
  multQuestions: 3,
  multCorrect: 3,
  multAttempts: 3,
  dotScore: 15,
  dotDurationMs: 9000,
  xpEarned: 100,
);

void main() {
  final today = DateTime(2026, 10, 21, 12);

  test('weekly counts are oldest first and end with today', () {
    final sessions = <WakeSession>[
      _session('a', DateTime(2026, 10, 21, 7)),
      _session('b', DateTime(2026, 10, 21, 8)),
      _session('c', DateTime(2026, 10, 19, 7)),
      _session('old', DateTime(2026, 9, 1, 7)),
    ];
    final counts = StatsCalculator.lastDaysCounts(sessions, today, 7);
    expect(counts.length, equals(7));
    expect(counts.last, equals(2));
    expect(counts[4], equals(1));
    expect(counts.fold<int>(0, (a, b) => a + b), equals(3));
  });

  test('monthly count only includes the current month', () {
    final sessions = <WakeSession>[
      _session('a', DateTime(2026, 10, 1, 7)),
      _session('b', DateTime(2026, 10, 20, 7)),
      _session('c', DateTime(2026, 9, 30, 7)),
    ];
    expect(StatsCalculator.completedInMonth(sessions, today), equals(2));
  });

  test(
    'scheduledToday counts one-time and repeating alarms for today only',
    () {
      final alarms = <Alarm>[
        const Alarm(id: 1, hour: 20, minute: 0),
        const Alarm(id: 2, hour: 6, minute: 0),
        const Alarm(id: 3, hour: 6, minute: 0, repeatDays: <int>{3}),
        const Alarm(id: 4, hour: 6, minute: 0, repeatDays: <int>{4}),
        const Alarm(id: 5, hour: 20, minute: 0, enabled: false),
      ];
      // Wednesday: alarm 1 (later today) and alarm 3. Alarm 2 already passed.
      expect(StatsCalculator.scheduledToday(alarms, today), equals(2));
    },
  );
}
