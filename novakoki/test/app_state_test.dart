import 'package:flutter_test/flutter_test.dart';
import 'package:novakoki/data/local_store.dart';
import 'package:novakoki/models/alarm.dart';
import 'package:novakoki/models/session.dart';
import 'package:novakoki/platform/alarm_platform.dart';
import 'package:novakoki/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records what the app would send to the native Android layer.
class FakePlatform implements AlarmPlatform {
  List<Alarm> synced = <Alarm>[];
  int syncCount = 0;
  List<int> firedOneShots = <int>[];
  int stopCount = 0;

  @override
  Future<void> syncAlarms(List<Alarm> alarms) async {
    synced = List<Alarm>.of(alarms);
    syncCount++;
  }

  @override
  Future<List<int>> consumeFiredOneShots() async {
    final result = firedOneShots;
    firedOneShots = <int>[];
    return result;
  }

  @override
  Future<void> stopAlarm() async => stopCount++;

  @override
  Future<int?> getRingingAlarm() async => null;

  @override
  Future<void> snooze(int alarmId, int minutes) async {}

  @override
  Future<PlatformStatus> getStatus() async => PlatformStatus.unknown;

  @override
  Future<bool> requestNotificationPermission() async => true;

  @override
  Future<void> openFullScreenIntentSettings() async {}

  @override
  Future<void> openNotificationSettings() async {}

  @override
  Future<void> openBatterySettings() async {}

  @override
  Future<void> previewSound(String sound) async {}

  @override
  Future<void> stopPreview() async {}

  @override
  void setRingingListener(void Function(int alarmId)? listener) {}
}

MissionResult _result(String id, {int? alarmId, int attempts = 3}) {
  return MissionResult(
    sessionId: id,
    alarmId: alarmId,
    scheduledAt: null,
    startedAt: DateTime(2026, 10, 21, 7, 0),
    multDifficulty: Difficulty.medium,
    dotDifficulty: Difficulty.medium,
    multQuestions: 3,
    multCorrect: 3,
    multAttempts: attempts,
    dotScore: 15,
    dotDurationMs: 12000,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<AppState> create(
    FakePlatform platform,
    DateTime Function() clock,
  ) async {
    final store = await LocalStore.open();
    final state = AppState(store: store, platform: platform, clock: clock);
    await state.init();
    return state;
  }

  group('alarm persistence', () {
    test('saved alarms are restored by a new AppState', () async {
      final platform = FakePlatform();
      final first = await create(platform, () => DateTime(2026, 10, 21, 6, 0));
      await first.upsertAlarm(
        Alarm(
          id: first.nextAlarmId(),
          hour: 6,
          minute: 30,
          title: 'Run',
          repeatDays: const <int>{1, 2, 3},
        ),
      );

      final second = await create(
        FakePlatform(),
        () => DateTime(2026, 10, 21, 6, 0),
      );
      expect(second.alarms.length, equals(1));
      expect(second.alarms.first.title, equals('Run'));
      expect(second.alarms.first.repeatDays, equals(<int>{1, 2, 3}));
    });

    test(
      'every change is pushed to the native layer without duplicates',
      () async {
        final platform = FakePlatform();
        final state = await create(
          platform,
          () => DateTime(2026, 10, 21, 6, 0),
        );
        final id = state.nextAlarmId();
        await state.upsertAlarm(Alarm(id: id, hour: 7, minute: 0));
        await state.upsertAlarm(Alarm(id: id, hour: 8, minute: 15));
        expect(state.alarms.length, equals(1));
        expect(platform.synced.length, equals(1));
        expect(platform.synced.first.hour, equals(8));

        await state.setAlarmEnabled(id, false);
        expect(platform.synced.first.enabled, isFalse);
        await state.deleteAlarm(id);
        expect(platform.synced, isEmpty);
      },
    );

    test('invalid alarms are rejected', () async {
      final state = await create(
        FakePlatform(),
        () => DateTime(2026, 10, 21, 6, 0),
      );
      Object? error;
      try {
        await state.upsertAlarm(const Alarm(id: 1, hour: 30, minute: 0));
      } catch (e) {
        error = e;
      }
      expect(error is ArgumentError, isTrue);
      expect(state.alarms, isEmpty);
    });

    test('one-time alarms that fired natively are disabled', () async {
      final platform = FakePlatform();
      final state = await create(platform, () => DateTime(2026, 10, 21, 6, 0));
      final id = state.nextAlarmId();
      await state.upsertAlarm(Alarm(id: id, hour: 7, minute: 0));
      platform.firedOneShots = <int>[id];
      await state.syncNative();
      expect(state.alarms.first.enabled, isFalse);
      expect(platform.synced.first.enabled, isFalse);
    });

    test('nextAlarm picks the soonest enabled alarm', () async {
      final state = await create(
        FakePlatform(),
        () => DateTime(2026, 10, 21, 6, 0),
      );
      await state.upsertAlarm(
        Alarm(id: state.nextAlarmId(), hour: 9, minute: 0),
      );
      await state.upsertAlarm(
        Alarm(id: state.nextAlarmId(), hour: 7, minute: 0),
      );
      await state.upsertAlarm(
        Alarm(id: state.nextAlarmId(), hour: 6, minute: 30, enabled: false),
      );
      final next = state.nextAlarm();
      expect(next, isNotNull);
      expect(next!.alarm.hour, equals(7));
      expect(next.at, equals(DateTime(2026, 10, 21, 7, 0)));
    });
  });

  group('mission completion', () {
    test('a session is recorded once and awards XP', () async {
      var now = DateTime(2026, 10, 21, 7, 5);
      final state = await create(FakePlatform(), () => now);
      final reward = await state.completeMission(_result('s1', attempts: 3));
      expect(reward, isNotNull);
      expect(reward!.session.xpEarned, greaterThan(0));
      expect(state.progress.completedSessions, equals(1));
      expect(state.progress.totalXp, equals(reward.session.xpEarned));
      expect(state.progress.currentStreak, equals(1));
      expect(state.sessions.length, equals(1));
      expect(state.progress.unlocked, contains('first_light'));

      // The same session id can never be rewarded twice.
      final again = await state.completeMission(_result('s1', attempts: 3));
      expect(again, isNull);
      expect(state.progress.completedSessions, equals(1));
      expect(state.sessions.length, equals(1));

      now = DateTime(2026, 10, 22, 7, 5);
      final next = await state.completeMission(_result('s2'));
      expect(next, isNotNull);
      expect(state.progress.currentStreak, equals(2));
      expect(state.progress.bestStreak, equals(2));
    });

    test('progress and sessions survive a restart', () async {
      final now = DateTime(2026, 10, 21, 7, 5);
      final first = await create(FakePlatform(), () => now);
      await first.completeMission(_result('persisted'));

      final second = await create(FakePlatform(), () => now);
      expect(second.sessions.length, equals(1));
      expect(second.sessions.first.id, equals('persisted'));
      expect(second.progress.completedSessions, equals(1));
      expect(second.progress.totalXp, equals(first.progress.totalXp));
      expect(second.progress.unlocked, equals(first.progress.unlocked));
    });

    test('finishing a one-time alarm switches it off', () async {
      final platform = FakePlatform();
      final state = await create(platform, () => DateTime(2026, 10, 21, 7, 5));
      final id = state.nextAlarmId();
      await state.upsertAlarm(Alarm(id: id, hour: 7, minute: 0));
      await state.completeMission(_result('once', alarmId: id));
      expect(state.alarmById(id)!.enabled, isFalse);
      expect(platform.synced.first.enabled, isFalse);
    });

    test('repeating alarms stay enabled after completion', () async {
      final state = await create(
        FakePlatform(),
        () => DateTime(2026, 10, 21, 7, 5),
      );
      final id = state.nextAlarmId();
      await state.upsertAlarm(
        Alarm(
          id: id,
          hour: 7,
          minute: 0,
          repeatDays: const <int>{1, 2, 3, 4, 5},
        ),
      );
      await state.completeMission(_result('weekday', alarmId: id));
      expect(state.alarmById(id)!.enabled, isTrue);
    });

    test('daily completion counters follow the clock', () async {
      final state = await create(
        FakePlatform(),
        () => DateTime(2026, 10, 21, 7, 5),
      );
      await state.upsertAlarm(
        Alarm(
          id: state.nextAlarmId(),
          hour: 7,
          minute: 0,
          repeatDays: const <int>{3},
        ),
      );
      expect(state.completedToday, equals(0));
      expect(state.scheduledToday, equals(1));
      await state.completeMission(_result('today'));
      expect(state.completedToday, equals(1));
    });
  });

  group('storage resilience', () {
    test('corrupt stored data is ignored instead of crashing', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'alarms_v1': 'not json',
        'sessions_v1': '[1, 2, {"id": 5}]',
        'progress_v1': '"nope"',
        'settings_v1': '{',
      });
      final state = await create(
        FakePlatform(),
        () => DateTime(2026, 10, 21, 7, 5),
      );
      expect(state.alarms, isEmpty);
      expect(state.sessions, isEmpty);
      expect(state.progress.totalXp, equals(0));
      expect(state.settings.use24h, isTrue);
    });

    test('the schema version is stamped on first open', () async {
      final store = await LocalStore.open();
      expect(store.schemaVersion, equals(LocalStore.currentSchemaVersion));
    });
  });
}
