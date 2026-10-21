import 'dart:math';

import '../models/alarm.dart';
import '../models/progress.dart';

String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Parses a yyyy-MM-dd key into a UTC date (so day differences ignore DST).
DateTime? parseDateKey(String? key) {
  if (key == null) return null;
  final parts = key.split('-');
  if (parts.length != 3) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime.utc(y, m, d);
}

class XpCalculator {
  static const int baseXp = 50;

  static int sessionXp({
    required Difficulty multDifficulty,
    required int questionCount,
    required double accuracy,
    required Difficulty dotDifficulty,
    required int streakAfter,
  }) {
    var xp = baseXp;
    xp += questionCount * (4 + 2 * multDifficulty.index);
    if (accuracy >= 0.9) xp += 20;
    xp += 10 + 10 * dotDifficulty.index;
    xp += min(streakAfter, 7) * 5;
    return xp;
  }
}

class LevelCalculator {
  /// Total XP needed to reach [level]: 0, 100, 300, 600, 1000, ...
  static int xpForLevel(int level) => level <= 1 ? 0 : 50 * level * (level - 1);

  static int levelForXp(int xp) {
    var level = 1;
    while (xp >= xpForLevel(level + 1)) {
      level++;
    }
    return level;
  }

  /// Fraction (0..1) of the way through the current level.
  static double progressInLevel(int xp) {
    final level = levelForXp(xp);
    final start = xpForLevel(level);
    final end = xpForLevel(level + 1);
    return (xp - start) / (end - start);
  }
}

class StreakResult {
  const StreakResult(this.current, this.best);

  final int current;
  final int best;
}

class StreakCalculator {
  /// Streak after completing a mission on [today].
  ///
  /// Completing twice on one day, or a clock/time-zone change that moves the
  /// date backwards, never changes the streak. Missing a day restarts it at 1
  /// on the next completion; nothing else is penalised.
  static StreakResult update({
    required int current,
    required int best,
    required String? lastDate,
    required String today,
  }) {
    final last = parseDateKey(lastDate);
    final now = parseDateKey(today);
    int next;
    if (now == null) {
      next = current <= 0 ? 1 : current;
    } else if (last == null) {
      next = 1;
    } else {
      final diff = now.difference(last).inDays;
      if (diff <= 0) {
        next = current <= 0 ? 1 : current;
      } else if (diff == 1) {
        next = current + 1;
      } else {
        next = 1;
      }
    }
    return StreakResult(next, max(best, next));
  }

  /// Streak to show today: a streak is only alive if the last completion was
  /// today or yesterday.
  static int displayStreak({
    required int current,
    required String? lastDate,
    required String today,
  }) {
    final last = parseDateKey(lastDate);
    final now = parseDateKey(today);
    if (last == null || now == null) return 0;
    return now.difference(last).inDays <= 1 ? current : 0;
  }
}

class AchievementIds {
  static const String firstLight = 'first_light';
  static const String earlyBird = 'early_bird';
  static const String novaStreak = 'nova_streak';
  static const String quickThinker = 'quick_thinker';
  static const String reactionMaster = 'reaction_master';

  static const List<String> all = <String>[
    firstLight,
    earlyBird,
    novaStreak,
    quickThinker,
    reactionMaster,
  ];
}

class AchievementEvaluator {
  /// Achievements newly earned. [progress] is the state after the session.
  static Set<String> newlyUnlocked({
    required UserProgress progress,
    required double sessionAccuracy,
    required int sessionQuestions,
    required bool dotCompleted,
  }) {
    final result = <String>{};
    void check(String id, bool condition) {
      if (condition && !progress.unlocked.contains(id)) result.add(id);
    }

    check(AchievementIds.firstLight, progress.completedSessions >= 1);
    check(AchievementIds.earlyBird, progress.completedSessions >= 5);
    check(AchievementIds.novaStreak, progress.bestStreak >= 7);
    check(
      AchievementIds.quickThinker,
      sessionQuestions >= 3 && sessionAccuracy >= 0.9,
    );
    check(AchievementIds.reactionMaster, dotCompleted);
    return result;
  }
}
