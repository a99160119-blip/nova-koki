import '../core/utils.dart';

enum Difficulty { easy, medium, hard }

Difficulty difficultyFrom(Object? raw, Difficulty fallback) {
  if (raw is num) {
    final index = raw.toInt();
    if (index >= 0 && index < Difficulty.values.length) {
      return Difficulty.values[index];
    }
  }
  return fallback;
}

/// Sound ids understood by the native player. `system` is the device alarm tone.
const List<String> kAlarmSounds = <String>[
  'nova_pulse',
  'aurora',
  'beacon',
  'system',
];

class Alarm {
  const Alarm({
    required this.id,
    required this.hour,
    required this.minute,
    this.title = '',
    this.repeatDays = const <int>{},
    this.enabled = true,
    this.sound = 'nova_pulse',
    this.vibrate = true,
    this.difficulty = Difficulty.medium,
    this.questionCount = 3,
    this.dotDifficulty = Difficulty.medium,
    this.dotTarget = 15,
    this.snoozeEnabled = false,
    this.snoozeMinutes = 5,
  });

  static const int minQuestions = 1;
  static const int maxQuestions = 10;
  static const int minDots = 5;
  static const int maxDots = 30;
  static const int maxTitleLength = 40;

  final int id;
  final int hour;
  final int minute;
  final String title;

  /// ISO weekdays (Monday = 1 ... Sunday = 7). Empty means a one-time alarm.
  final Set<int> repeatDays;
  final bool enabled;
  final String sound;
  final bool vibrate;

  /// Multiplication challenge difficulty.
  final Difficulty difficulty;
  final int questionCount;
  final Difficulty dotDifficulty;
  final int dotTarget;
  final bool snoozeEnabled;
  final int snoozeMinutes;

  Alarm copyWith({
    int? hour,
    int? minute,
    String? title,
    Set<int>? repeatDays,
    bool? enabled,
    String? sound,
    bool? vibrate,
    Difficulty? difficulty,
    int? questionCount,
    Difficulty? dotDifficulty,
    int? dotTarget,
    bool? snoozeEnabled,
    int? snoozeMinutes,
  }) {
    return Alarm(
      id: id,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      title: title ?? this.title,
      repeatDays: repeatDays ?? this.repeatDays,
      enabled: enabled ?? this.enabled,
      sound: sound ?? this.sound,
      vibrate: vibrate ?? this.vibrate,
      difficulty: difficulty ?? this.difficulty,
      questionCount: questionCount ?? this.questionCount,
      dotDifficulty: dotDifficulty ?? this.dotDifficulty,
      dotTarget: dotTarget ?? this.dotTarget,
      snoozeEnabled: snoozeEnabled ?? this.snoozeEnabled,
      snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
    );
  }

  /// Returns localization keys describing each problem; empty when valid.
  List<String> validate() {
    final errors = <String>[];
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      errors.add('err_time');
    }
    if (title.length > maxTitleLength) errors.add('err_title');
    if (repeatDays.any((d) => d < 1 || d > 7)) errors.add('err_days');
    if (!kAlarmSounds.contains(sound)) errors.add('err_sound');
    if (questionCount < minQuestions || questionCount > maxQuestions) {
      errors.add('err_questions');
    }
    if (dotTarget < minDots || dotTarget > maxDots) errors.add('err_dots');
    if (snoozeMinutes < 1 || snoozeMinutes > 30) errors.add('err_snooze');
    return errors;
  }

  /// Bit 0 = Monday ... bit 6 = Sunday. Zero means a one-time alarm.
  int get repeatMask {
    var mask = 0;
    for (final day in repeatDays) {
      if (day >= 1 && day <= 7) mask |= 1 << (day - 1);
    }
    return mask;
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'hour': hour,
    'minute': minute,
    'title': title,
    'repeatDays': (repeatDays.toList()..sort()),
    'enabled': enabled,
    'sound': sound,
    'vibrate': vibrate,
    'difficulty': difficulty.index,
    'questionCount': questionCount,
    'dotDifficulty': dotDifficulty.index,
    'dotTarget': dotTarget,
    'snoozeEnabled': snoozeEnabled,
    'snoozeMinutes': snoozeMinutes,
  };

  /// The subset of fields the native alarm code needs.
  Map<String, Object?> toNativeJson() => <String, Object?>{
    'id': id,
    'hour': hour,
    'minute': minute,
    'daysMask': repeatMask,
    'enabled': enabled,
    'title': title,
    'sound': sound,
    'vibrate': vibrate,
    'snoozeEnabled': snoozeEnabled,
    'snoozeMinutes': snoozeMinutes,
  };

  /// Tolerant parser: clamps out-of-range numbers and falls back to defaults.
  factory Alarm.fromJson(Map<String, dynamic> json) {
    int asInt(Object? v, int fallback) => v is num ? v.toInt() : fallback;
    final days = <int>{};
    final rawDays = json['repeatDays'];
    if (rawDays is List) {
      for (final d in rawDays) {
        if (d is num && d >= 1 && d <= 7) days.add(d.toInt());
      }
    }
    final rawSound = json['sound'];
    final rawTitle = json['title'];
    var title = rawTitle is String ? rawTitle : '';
    if (title.length > maxTitleLength) {
      title = title.substring(0, maxTitleLength);
    }
    return Alarm(
      id: asInt(json['id'], 0),
      hour: clampInt(asInt(json['hour'], 7), 0, 23),
      minute: clampInt(asInt(json['minute'], 0), 0, 59),
      title: title,
      repeatDays: days,
      enabled: json['enabled'] is bool ? json['enabled'] as bool : true,
      sound: rawSound is String && kAlarmSounds.contains(rawSound)
          ? rawSound
          : 'nova_pulse',
      vibrate: json['vibrate'] is bool ? json['vibrate'] as bool : true,
      difficulty: difficultyFrom(json['difficulty'], Difficulty.medium),
      questionCount: clampInt(
        asInt(json['questionCount'], 3),
        minQuestions,
        maxQuestions,
      ),
      dotDifficulty: difficultyFrom(json['dotDifficulty'], Difficulty.medium),
      dotTarget: clampInt(asInt(json['dotTarget'], 15), minDots, maxDots),
      snoozeEnabled: json['snoozeEnabled'] is bool
          ? json['snoozeEnabled'] as bool
          : false,
      snoozeMinutes: clampInt(asInt(json['snoozeMinutes'], 5), 1, 30),
    );
  }
}
