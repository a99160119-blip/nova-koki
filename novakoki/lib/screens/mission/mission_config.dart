import 'dart:math';

import '../../models/alarm.dart';

String newSessionId() =>
    '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 30)}';

/// Everything a wake-up mission needs. [practice] missions never award XP.
class MissionConfig {
  MissionConfig({
    required this.sessionId,
    required this.alarmId,
    required this.title,
    required this.scheduledAt,
    required this.multDifficulty,
    required this.questionCount,
    required this.dotDifficulty,
    required this.dotTarget,
    required this.snoozeEnabled,
    required this.snoozeMinutes,
    required this.practice,
  });

  /// Mission for a ringing alarm. [alarm] may be null if it was deleted
  /// while ringing; sensible defaults are used then.
  factory MissionConfig.forAlarm(Alarm? alarm, int alarmId) {
    return MissionConfig(
      sessionId: newSessionId(),
      alarmId: alarmId,
      title: alarm?.title ?? '',
      scheduledAt: DateTime.now(),
      multDifficulty: alarm?.difficulty ?? Difficulty.medium,
      questionCount: alarm?.questionCount ?? 3,
      dotDifficulty: alarm?.dotDifficulty ?? Difficulty.medium,
      dotTarget: alarm?.dotTarget ?? 15,
      snoozeEnabled: alarm?.snoozeEnabled ?? false,
      snoozeMinutes: alarm?.snoozeMinutes ?? 5,
      practice: false,
    );
  }

  factory MissionConfig.practice() {
    return MissionConfig(
      sessionId: newSessionId(),
      alarmId: null,
      title: '',
      scheduledAt: null,
      multDifficulty: Difficulty.medium,
      questionCount: 3,
      dotDifficulty: Difficulty.medium,
      dotTarget: 15,
      snoozeEnabled: false,
      snoozeMinutes: 5,
      practice: true,
    );
  }

  final String sessionId;
  final int? alarmId;
  final String title;
  final DateTime? scheduledAt;
  final Difficulty multDifficulty;
  final int questionCount;
  final Difficulty dotDifficulty;
  final int dotTarget;
  final bool snoozeEnabled;
  final int snoozeMinutes;
  final bool practice;
}

class MultiplicationOutcome {
  const MultiplicationOutcome({
    required this.questions,
    required this.correct,
    required this.attempts,
  });

  final int questions;
  final int correct;
  final int attempts;
}

class DotOutcome {
  const DotOutcome({required this.score, required this.durationMs});

  final int score;
  final int durationMs;
}
