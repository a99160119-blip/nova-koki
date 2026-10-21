class UserProgress {
  const UserProgress({
    this.totalXp = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.completedSessions = 0,
    this.unlocked = const <String>{},
    this.lastCompletedDate,
    this.multCorrect = 0,
    this.multAttempts = 0,
    this.bestDotTimeMs,
  });

  static const UserProgress empty = UserProgress();

  final int totalXp;
  final int currentStreak;
  final int bestStreak;
  final int completedSessions;
  final Set<String> unlocked;

  /// Local calendar date (yyyy-MM-dd) of the last completed mission.
  final String? lastCompletedDate;
  final int multCorrect;
  final int multAttempts;
  final int? bestDotTimeMs;

  double get multAccuracy => multAttempts == 0 ? 0 : multCorrect / multAttempts;

  UserProgress copyWith({
    int? totalXp,
    int? currentStreak,
    int? bestStreak,
    int? completedSessions,
    Set<String>? unlocked,
    String? lastCompletedDate,
    int? multCorrect,
    int? multAttempts,
    int? bestDotTimeMs,
  }) {
    return UserProgress(
      totalXp: totalXp ?? this.totalXp,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      completedSessions: completedSessions ?? this.completedSessions,
      unlocked: unlocked ?? this.unlocked,
      lastCompletedDate: lastCompletedDate ?? this.lastCompletedDate,
      multCorrect: multCorrect ?? this.multCorrect,
      multAttempts: multAttempts ?? this.multAttempts,
      bestDotTimeMs: bestDotTimeMs ?? this.bestDotTimeMs,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'totalXp': totalXp,
    'currentStreak': currentStreak,
    'bestStreak': bestStreak,
    'completedSessions': completedSessions,
    'unlocked': unlocked.toList()..sort(),
    'lastCompletedDate': lastCompletedDate,
    'multCorrect': multCorrect,
    'multAttempts': multAttempts,
    'bestDotTimeMs': bestDotTimeMs,
  };

  factory UserProgress.fromJson(Map<String, dynamic> json) {
    int asInt(Object? v) => v is num && v >= 0 ? v.toInt() : 0;
    final unlocked = <String>{};
    final raw = json['unlocked'];
    if (raw is List) {
      for (final e in raw) {
        if (e is String) unlocked.add(e);
      }
    }
    return UserProgress(
      totalXp: asInt(json['totalXp']),
      currentStreak: asInt(json['currentStreak']),
      bestStreak: asInt(json['bestStreak']),
      completedSessions: asInt(json['completedSessions']),
      unlocked: unlocked,
      lastCompletedDate: json['lastCompletedDate'] is String
          ? json['lastCompletedDate'] as String
          : null,
      multCorrect: asInt(json['multCorrect']),
      multAttempts: asInt(json['multAttempts']),
      bestDotTimeMs: json['bestDotTimeMs'] is num
          ? (json['bestDotTimeMs'] as num).toInt()
          : null,
    );
  }
}
