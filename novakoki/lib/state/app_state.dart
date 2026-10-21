import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/local_store.dart';
import '../logic/alarm_schedule.dart';
import '../logic/gamification.dart';
import '../logic/stats.dart';
import '../models/alarm.dart';
import '../models/progress.dart';
import '../models/session.dart';
import '../models/settings.dart';
import '../platform/alarm_platform.dart';

class NextAlarm {
  const NextAlarm(this.alarm, this.at);

  final Alarm alarm;
  final DateTime at;
}

class SessionReward {
  const SessionReward({
    required this.session,
    required this.levelBefore,
    required this.levelAfter,
    required this.newAchievements,
    required this.streak,
    required this.totalXp,
  });

  final WakeSession session;
  final int levelBefore;
  final int levelAfter;
  final Set<String> newAchievements;
  final int streak;
  final int totalXp;

  bool get leveledUp => levelAfter > levelBefore;
}

/// Single source of truth for alarms, sessions, progress and settings.
class AppState extends ChangeNotifier {
  AppState({
    required this.store,
    required this.platform,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static const int maxStoredSessions = 365;

  final LocalStore store;
  final AlarmPlatform platform;
  final DateTime Function() _clock;

  List<Alarm> _alarms = <Alarm>[];
  List<WakeSession> _sessions = <WakeSession>[];
  UserProgress _progress = UserProgress.empty;
  AppSettings _settings = const AppSettings();
  PlatformStatus _status = PlatformStatus.unknown;

  int? _activeMissionAlarmId;
  bool _missionActive = false;

  List<Alarm> get alarms => _alarms;
  List<WakeSession> get sessions => _sessions;
  UserProgress get progress => _progress;
  AppSettings get settings => _settings;
  PlatformStatus get status => _status;

  DateTime get now => _clock();

  Locale get locale {
    switch (_settings.localeCode) {
      case 'en':
        return const Locale('en');
      case 'fa':
        return const Locale('fa');
      default:
        final system = PlatformDispatcher.instance.locale.languageCode;
        return Locale(system == 'fa' ? 'fa' : 'en');
    }
  }

  Future<void> init() async {
    _alarms = store.loadAlarms();
    _sessions = store.loadSessions();
    _progress = store.loadProgress();
    _settings = store.loadSettings();
    await syncNative();
    _status = await platform.getStatus();
    notifyListeners();
  }

  /// Called when the app returns to the foreground.
  Future<void> refreshOnResume() async {
    await syncNative();
    _status = await platform.getStatus();
    notifyListeners();
  }

  Future<void> refreshStatus() async {
    _status = await platform.getStatus();
    notifyListeners();
  }

  Future<bool> requestNotificationPermission() async {
    final granted = await platform.requestNotificationPermission();
    await refreshStatus();
    return granted;
  }

  // ---------------------------------------------------------------- alarms

  Alarm? alarmById(int id) {
    for (final a in _alarms) {
      if (a.id == id) return a;
    }
    return null;
  }

  int nextAlarmId() {
    var highest = 0;
    for (final a in _alarms) {
      if (a.id > highest) highest = a.id;
    }
    return highest + 1;
  }

  /// Applies the one-time alarms that already fired natively, then pushes the
  /// full alarm list to the native scheduler (which de-duplicates).
  Future<void> syncNative() async {
    final fired = await platform.consumeFiredOneShots();
    if (fired.isNotEmpty) {
      _alarms = <Alarm>[
        for (final a in _alarms)
          (fired.contains(a.id) && a.repeatDays.isEmpty)
              ? a.copyWith(enabled: false)
              : a,
      ];
      await store.saveAlarms(_alarms);
      notifyListeners();
    }
    await platform.syncAlarms(_alarms);
  }

  Future<void> upsertAlarm(Alarm alarm) async {
    final errors = alarm.validate();
    if (errors.isNotEmpty) {
      throw ArgumentError('Invalid alarm: ${errors.join(', ')}');
    }
    final list = List<Alarm>.of(_alarms);
    final index = list.indexWhere((a) => a.id == alarm.id);
    if (index >= 0) {
      list[index] = alarm;
    } else {
      list.add(alarm);
    }
    list.sort(
      (a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute),
    );
    _alarms = list;
    notifyListeners();
    await store.saveAlarms(_alarms);
    await syncNative();
  }

  Future<void> setAlarmEnabled(int id, bool enabled) async {
    final alarm = alarmById(id);
    if (alarm == null) return;
    await upsertAlarm(alarm.copyWith(enabled: enabled));
  }

  Future<void> deleteAlarm(int id) async {
    _alarms = _alarms.where((a) => a.id != id).toList();
    notifyListeners();
    await store.saveAlarms(_alarms);
    await syncNative();
  }

  /// The enabled alarm that rings soonest, or null if none is enabled.
  NextAlarm? nextAlarm([DateTime? at]) {
    final reference = at ?? _clock();
    NextAlarm? best;
    for (final a in _alarms) {
      if (!a.enabled) continue;
      final time = nextOccurrence(a, reference);
      if (best == null || time.isBefore(best.at)) {
        best = NextAlarm(a, time);
      }
    }
    return best;
  }

  // -------------------------------------------------------------- settings

  Future<void> updateSettings(AppSettings settings) async {
    _settings = settings;
    notifyListeners();
    await store.saveSettings(_settings);
  }

  void haptic() {
    if (_settings.haptics) HapticFeedback.lightImpact();
  }

  // --------------------------------------------------------------- mission

  int? get activeMissionAlarmId => _activeMissionAlarmId;
  bool get missionActive => _missionActive;

  void beginMission(int? alarmId) {
    _missionActive = true;
    _activeMissionAlarmId = alarmId;
  }

  void endMission() {
    _missionActive = false;
    _activeMissionAlarmId = null;
  }

  /// Records a finished mission exactly once and awards XP.
  ///
  /// Returns null when a session with the same id was already recorded.
  Future<SessionReward?> completeMission(MissionResult result) async {
    if (_sessions.any((s) => s.id == result.sessionId)) return null;

    final completedAt = _clock();
    final today = dateKey(completedAt);
    final streak = StreakCalculator.update(
      current: _progress.currentStreak,
      best: _progress.bestStreak,
      lastDate: _progress.lastCompletedDate,
      today: today,
    );
    final accuracy = result.multAttempts == 0
        ? 0.0
        : result.multCorrect / result.multAttempts;
    final xp = XpCalculator.sessionXp(
      multDifficulty: result.multDifficulty,
      questionCount: result.multQuestions,
      accuracy: accuracy,
      dotDifficulty: result.dotDifficulty,
      streakAfter: streak.current,
    );
    final session = WakeSession(
      id: result.sessionId,
      alarmId: result.alarmId,
      scheduledAt: result.scheduledAt,
      startedAt: result.startedAt,
      completedAt: completedAt,
      multQuestions: result.multQuestions,
      multCorrect: result.multCorrect,
      multAttempts: result.multAttempts,
      dotScore: result.dotScore,
      dotDurationMs: result.dotDurationMs,
      xpEarned: xp,
    );

    final before = _progress;
    final bestDot =
        before.bestDotTimeMs == null ||
            result.dotDurationMs < before.bestDotTimeMs!
        ? result.dotDurationMs
        : before.bestDotTimeMs;
    var updated = before.copyWith(
      totalXp: before.totalXp + xp,
      currentStreak: streak.current,
      bestStreak: streak.best,
      completedSessions: before.completedSessions + 1,
      lastCompletedDate: today,
      multCorrect: before.multCorrect + result.multCorrect,
      multAttempts: before.multAttempts + result.multAttempts,
      bestDotTimeMs: bestDot,
    );
    final earned = AchievementEvaluator.newlyUnlocked(
      progress: updated,
      sessionAccuracy: accuracy,
      sessionQuestions: result.multQuestions,
      dotCompleted: result.dotScore >= 1,
    );
    updated = updated.copyWith(
      unlocked: <String>{...updated.unlocked, ...earned},
    );

    var sessions = <WakeSession>[..._sessions, session];
    if (sessions.length > maxStoredSessions) {
      sessions = sessions.sublist(sessions.length - maxStoredSessions);
    }

    // Update memory first (synchronously) so a duplicate call is rejected.
    _sessions = sessions;
    _progress = updated;
    notifyListeners();

    await store.saveSessions(_sessions);
    await store.saveProgress(_progress);

    // A finished one-time alarm is switched off.
    final alarmId = result.alarmId;
    if (alarmId != null) {
      final alarm = alarmById(alarmId);
      if (alarm != null && alarm.repeatDays.isEmpty && alarm.enabled) {
        await upsertAlarm(alarm.copyWith(enabled: false));
      }
    }

    return SessionReward(
      session: session,
      levelBefore: LevelCalculator.levelForXp(before.totalXp),
      levelAfter: LevelCalculator.levelForXp(updated.totalXp),
      newAchievements: earned,
      streak: streak.current,
      totalXp: updated.totalXp,
    );
  }

  // ------------------------------------------------------------ statistics

  int get displayStreak => StreakCalculator.displayStreak(
    current: _progress.currentStreak,
    lastDate: _progress.lastCompletedDate,
    today: dateKey(_clock()),
  );

  int get completedToday => StatsCalculator.completedOn(_sessions, _clock());

  int get scheduledToday => StatsCalculator.scheduledToday(_alarms, _clock());

  int get level => LevelCalculator.levelForXp(_progress.totalXp);
}
