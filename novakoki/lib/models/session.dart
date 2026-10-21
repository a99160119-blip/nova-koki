import 'alarm.dart';

/// Raw outcome of a finished mission, before XP is calculated.
class MissionResult {
  const MissionResult({
    required this.sessionId,
    required this.alarmId,
    required this.scheduledAt,
    required this.startedAt,
    required this.multDifficulty,
    required this.dotDifficulty,
    required this.multQuestions,
    required this.multCorrect,
    required this.multAttempts,
    required this.dotScore,
    required this.dotDurationMs,
  });

  final String sessionId;
  final int? alarmId;
  final DateTime? scheduledAt;
  final DateTime startedAt;
  final Difficulty multDifficulty;
  final Difficulty dotDifficulty;
  final int multQuestions;
  final int multCorrect;
  final int multAttempts;
  final int dotScore;
  final int dotDurationMs;
}

/// A completed wake-up session as stored on the device.
class WakeSession {
  const WakeSession({
    required this.id,
    required this.alarmId,
    required this.scheduledAt,
    required this.startedAt,
    required this.completedAt,
    required this.multQuestions,
    required this.multCorrect,
    required this.multAttempts,
    required this.dotScore,
    required this.dotDurationMs,
    required this.xpEarned,
    this.completed = true,
  });

  final String id;
  final int? alarmId;
  final DateTime? scheduledAt;
  final DateTime startedAt;
  final DateTime completedAt;
  final int multQuestions;
  final int multCorrect;
  final int multAttempts;
  final int dotScore;
  final int dotDurationMs;
  final int xpEarned;
  final bool completed;

  double get accuracy => multAttempts == 0 ? 0 : multCorrect / multAttempts;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'alarmId': alarmId,
    'scheduledAt': scheduledAt?.toIso8601String(),
    'startedAt': startedAt.toIso8601String(),
    'completedAt': completedAt.toIso8601String(),
    'multQuestions': multQuestions,
    'multCorrect': multCorrect,
    'multAttempts': multAttempts,
    'dotScore': dotScore,
    'dotDurationMs': dotDurationMs,
    'xpEarned': xpEarned,
    'completed': completed,
  };

  /// Returns null when the stored record is unusable.
  static WakeSession? tryFromJson(Map<String, dynamic> json) {
    try {
      final id = json['id'];
      final started = DateTime.tryParse('${json['startedAt']}');
      final completed = DateTime.tryParse('${json['completedAt']}');
      if (id is! String || started == null || completed == null) return null;
      int asInt(Object? v) => v is num ? v.toInt() : 0;
      return WakeSession(
        id: id,
        alarmId: json['alarmId'] is num
            ? (json['alarmId'] as num).toInt()
            : null,
        scheduledAt: json['scheduledAt'] is String
            ? DateTime.tryParse(json['scheduledAt'] as String)
            : null,
        startedAt: started,
        completedAt: completed,
        multQuestions: asInt(json['multQuestions']),
        multCorrect: asInt(json['multCorrect']),
        multAttempts: asInt(json['multAttempts']),
        dotScore: asInt(json['dotScore']),
        dotDurationMs: asInt(json['dotDurationMs']),
        xpEarned: asInt(json['xpEarned']),
        completed: json['completed'] is bool ? json['completed'] as bool : true,
      );
    } catch (_) {
      return null;
    }
  }
}
