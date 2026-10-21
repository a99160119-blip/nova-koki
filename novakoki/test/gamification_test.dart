import 'package:flutter_test/flutter_test.dart';
import 'package:novakoki/logic/gamification.dart';
import 'package:novakoki/models/alarm.dart';
import 'package:novakoki/models/progress.dart';

void main() {
  group('XpCalculator', () {
    test('rewards difficulty, accuracy and streak', () {
      final easy = XpCalculator.sessionXp(
        multDifficulty: Difficulty.easy,
        questionCount: 3,
        accuracy: 0.5,
        dotDifficulty: Difficulty.easy,
        streakAfter: 1,
      );
      // 50 base + 3*4 + 0 accuracy bonus + 10 dots + 5 streak
      expect(easy, equals(77));
      final hard = XpCalculator.sessionXp(
        multDifficulty: Difficulty.hard,
        questionCount: 3,
        accuracy: 1.0,
        dotDifficulty: Difficulty.hard,
        streakAfter: 30,
      );
      // 50 + 3*8 + 20 + 30 + 35 (streak capped at 7 days)
      expect(hard, equals(159));
    });
  });

  group('LevelCalculator', () {
    test('level thresholds', () {
      expect(LevelCalculator.levelForXp(0), equals(1));
      expect(LevelCalculator.levelForXp(99), equals(1));
      expect(LevelCalculator.levelForXp(100), equals(2));
      expect(LevelCalculator.levelForXp(299), equals(2));
      expect(LevelCalculator.levelForXp(300), equals(3));
      expect(LevelCalculator.levelForXp(600), equals(4));
    });

    test('progress within a level is between 0 and 1', () {
      expect(LevelCalculator.progressInLevel(0), equals(0));
      expect(LevelCalculator.progressInLevel(200), closeTo(0.5, 1e-9));
    });
  });

  group('StreakCalculator', () {
    test('first completion starts a streak of one', () {
      final r = StreakCalculator.update(
        current: 0,
        best: 0,
        lastDate: null,
        today: '2026-10-21',
      );
      expect(r.current, equals(1));
      expect(r.best, equals(1));
    });

    test('consecutive days extend, same day does not', () {
      var r = StreakCalculator.update(
        current: 3,
        best: 3,
        lastDate: '2026-10-20',
        today: '2026-10-21',
      );
      expect(r.current, equals(4));
      expect(r.best, equals(4));
      r = StreakCalculator.update(
        current: 4,
        best: 4,
        lastDate: '2026-10-21',
        today: '2026-10-21',
      );
      expect(r.current, equals(4));
    });

    test('a missed day restarts at one but keeps the best', () {
      final r = StreakCalculator.update(
        current: 6,
        best: 6,
        lastDate: '2026-10-18',
        today: '2026-10-21',
      );
      expect(r.current, equals(1));
      expect(r.best, equals(6));
    });

    test('month and year boundaries count as consecutive', () {
      expect(
        StreakCalculator.update(
          current: 1,
          best: 1,
          lastDate: '2026-10-31',
          today: '2026-11-01',
        ).current,
        equals(2),
      );
      expect(
        StreakCalculator.update(
          current: 1,
          best: 1,
          lastDate: '2026-12-31',
          today: '2027-01-01',
        ).current,
        equals(2),
      );
    });

    test('a clock moved backwards never breaks or inflates the streak', () {
      final r = StreakCalculator.update(
        current: 5,
        best: 5,
        lastDate: '2026-10-21',
        today: '2026-10-20',
      );
      expect(r.current, equals(5));
    });

    test('display streak is zero once the streak is broken', () {
      expect(
        StreakCalculator.displayStreak(
          current: 5,
          lastDate: '2026-10-20',
          today: '2026-10-21',
        ),
        equals(5),
      );
      expect(
        StreakCalculator.displayStreak(
          current: 5,
          lastDate: '2026-10-18',
          today: '2026-10-21',
        ),
        equals(0),
      );
      expect(
        StreakCalculator.displayStreak(
          current: 0,
          lastDate: null,
          today: '2026-10-21',
        ),
        equals(0),
      );
    });

    test('dateKey formats with zero padding', () {
      expect(dateKey(DateTime(2026, 3, 4)), equals('2026-03-04'));
    });
  });

  group('AchievementEvaluator', () {
    test('first session unlocks FIRST LIGHT and REACTION MASTER only', () {
      const progress = UserProgress(completedSessions: 1, bestStreak: 1);
      final earned = AchievementEvaluator.newlyUnlocked(
        progress: progress,
        sessionAccuracy: 0.5,
        sessionQuestions: 3,
        dotCompleted: true,
      );
      expect(
        earned,
        equals(<String>{
          AchievementIds.firstLight,
          AchievementIds.reactionMaster,
        }),
      );
    });

    test(
      'high accuracy unlocks QUICK THINKER, low question count does not',
      () {
        const progress = UserProgress(completedSessions: 2, bestStreak: 1);
        expect(
          AchievementEvaluator.newlyUnlocked(
            progress: progress,
            sessionAccuracy: 1.0,
            sessionQuestions: 3,
            dotCompleted: false,
          ),
          contains(AchievementIds.quickThinker),
        );
        expect(
          AchievementEvaluator.newlyUnlocked(
            progress: progress,
            sessionAccuracy: 1.0,
            sessionQuestions: 2,
            dotCompleted: false,
          ),
          isNot(contains(AchievementIds.quickThinker)),
        );
      },
    );

    test(
      'five missions and a seven-day streak unlock the milestone badges',
      () {
        const progress = UserProgress(completedSessions: 7, bestStreak: 7);
        final earned = AchievementEvaluator.newlyUnlocked(
          progress: progress,
          sessionAccuracy: 0,
          sessionQuestions: 3,
          dotCompleted: false,
        );
        expect(earned, contains(AchievementIds.earlyBird));
        expect(earned, contains(AchievementIds.novaStreak));
      },
    );

    test('already unlocked achievements are never awarded twice', () {
      final progress = UserProgress(
        completedSessions: 9,
        bestStreak: 9,
        unlocked: <String>{...AchievementIds.all},
      );
      final earned = AchievementEvaluator.newlyUnlocked(
        progress: progress,
        sessionAccuracy: 1,
        sessionQuestions: 5,
        dotCompleted: true,
      );
      expect(earned, isEmpty);
    });
  });
}
