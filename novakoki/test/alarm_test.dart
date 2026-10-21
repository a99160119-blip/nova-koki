import 'package:flutter_test/flutter_test.dart';
import 'package:novakoki/logic/alarm_schedule.dart';
import 'package:novakoki/models/alarm.dart';

void main() {
  group('Alarm validation', () {
    test('a default alarm is valid', () {
      expect(const Alarm(id: 1, hour: 7, minute: 30).validate(), isEmpty);
    });

    test('rejects out-of-range values', () {
      expect(
        const Alarm(id: 1, hour: 24, minute: 0).validate(),
        contains('err_time'),
      );
      expect(
        const Alarm(id: 1, hour: 7, minute: 60).validate(),
        contains('err_time'),
      );
      expect(
        const Alarm(id: 1, hour: 7, minute: 0, questionCount: 0).validate(),
        contains('err_questions'),
      );
      expect(
        const Alarm(id: 1, hour: 7, minute: 0, questionCount: 11).validate(),
        contains('err_questions'),
      );
      expect(
        const Alarm(id: 1, hour: 7, minute: 0, dotTarget: 2).validate(),
        contains('err_dots'),
      );
      expect(
        const Alarm(id: 1, hour: 7, minute: 0, snoozeMinutes: 0).validate(),
        contains('err_snooze'),
      );
      expect(
        const Alarm(id: 1, hour: 7, minute: 0, sound: 'nope').validate(),
        contains('err_sound'),
      );
      expect(
        const Alarm(
          id: 1,
          hour: 7,
          minute: 0,
          repeatDays: <int>{0, 8},
        ).validate(),
        contains('err_days'),
      );
      expect(
        Alarm(id: 1, hour: 7, minute: 0, title: 'x' * 41).validate(),
        contains('err_title'),
      );
    });
  });

  group('Alarm JSON', () {
    test('round-trips every field', () {
      const alarm = Alarm(
        id: 4,
        hour: 6,
        minute: 45,
        title: 'Gym',
        repeatDays: <int>{1, 3, 5},
        enabled: false,
        sound: 'aurora',
        vibrate: false,
        difficulty: Difficulty.hard,
        questionCount: 6,
        dotDifficulty: Difficulty.easy,
        dotTarget: 20,
        snoozeEnabled: true,
        snoozeMinutes: 10,
      );
      final copy = Alarm.fromJson(alarm.toJson());
      expect(copy.toJson(), equals(alarm.toJson()));
    });

    test('fromJson clamps bad data instead of crashing', () {
      final alarm = Alarm.fromJson(<String, dynamic>{
        'id': 2,
        'hour': 99,
        'minute': -5,
        'questionCount': 500,
        'sound': 42,
        'repeatDays': <dynamic>[1, 9, 'x', 7],
      });
      expect(alarm.hour, equals(23));
      expect(alarm.minute, equals(0));
      expect(alarm.questionCount, equals(Alarm.maxQuestions));
      expect(alarm.sound, equals('nova_pulse'));
      expect(alarm.repeatDays, equals(<int>{1, 7}));
      expect(alarm.validate(), isEmpty);
    });

    test('native mask uses Monday as bit 0', () {
      expect(
        const Alarm(
          id: 1,
          hour: 1,
          minute: 0,
          repeatDays: <int>{1, 7},
        ).repeatMask,
        equals(1 + 64),
      );
      expect(const Alarm(id: 1, hour: 1, minute: 0).repeatMask, equals(0));
    });
  });

  group('nextOccurrence', () {
    // 2026-10-21 is a Wednesday.
    final wednesdayNoon = DateTime(2026, 10, 21, 12, 0);

    test('one-time alarm later today fires today', () {
      const alarm = Alarm(id: 1, hour: 18, minute: 30);
      expect(
        nextOccurrence(alarm, wednesdayNoon),
        equals(DateTime(2026, 10, 21, 18, 30)),
      );
    });

    test('one-time alarm already passed fires tomorrow', () {
      const alarm = Alarm(id: 1, hour: 7, minute: 0);
      expect(
        nextOccurrence(alarm, wednesdayNoon),
        equals(DateTime(2026, 10, 22, 7, 0)),
      );
    });

    test('the current minute is not "next"', () {
      const alarm = Alarm(id: 1, hour: 12, minute: 0);
      expect(
        nextOccurrence(alarm, wednesdayNoon),
        equals(DateTime(2026, 10, 22, 12, 0)),
      );
    });

    test('repeat days pick the next matching weekday', () {
      const monday = Alarm(id: 1, hour: 7, minute: 0, repeatDays: <int>{1});
      expect(
        nextOccurrence(monday, wednesdayNoon),
        equals(DateTime(2026, 10, 26, 7, 0)),
      );
      const wednesday = Alarm(id: 1, hour: 7, minute: 0, repeatDays: <int>{3});
      expect(
        nextOccurrence(wednesday, wednesdayNoon),
        equals(DateTime(2026, 10, 28, 7, 0)),
      );
      const wednesdayLater = Alarm(
        id: 1,
        hour: 20,
        minute: 0,
        repeatDays: <int>{3},
      );
      expect(
        nextOccurrence(wednesdayLater, wednesdayNoon),
        equals(DateTime(2026, 10, 21, 20, 0)),
      );
    });

    test('crosses month boundaries', () {
      const alarm = Alarm(id: 1, hour: 6, minute: 0);
      expect(
        nextOccurrence(alarm, DateTime(2026, 10, 31, 23, 0)),
        equals(DateTime(2026, 11, 1, 6, 0)),
      );
    });
  });
}
