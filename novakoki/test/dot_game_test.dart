import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:novakoki/logic/dot_game.dart';
import 'package:novakoki/models/alarm.dart';

void main() {
  group('DotGame', () {
    test('dots always stay inside the play area', () {
      for (final difficulty in Difficulty.values) {
        final game = DotGame(
          target: 30,
          difficulty: difficulty,
          random: Random(1),
        );
        while (!game.isComplete) {
          final dot = game.spawnNext(320, 480);
          expect(dot.center.x - dot.radius, greaterThanOrEqualTo(0));
          expect(dot.center.y - dot.radius, greaterThanOrEqualTo(0));
          expect(dot.center.x + dot.radius, lessThanOrEqualTo(320));
          expect(dot.center.y + dot.radius, lessThanOrEqualTo(480));
          expect(game.tap(dot.id), isTrue);
        }
        expect(game.score, equals(30));
      }
    });

    test('a single tap cannot score twice', () {
      final game = DotGame(
        target: 5,
        difficulty: Difficulty.easy,
        random: Random(2),
      );
      final dot = game.spawnNext(300, 300);
      expect(game.tap(dot.id), isTrue);
      expect(game.tap(dot.id), isFalse);
      expect(game.score, equals(1));
      expect(game.current, isNull);
    });

    test('taps on a stale or unknown dot do not score', () {
      final game = DotGame(
        target: 5,
        difficulty: Difficulty.medium,
        random: Random(3),
      );
      final first = game.spawnNext(300, 300);
      game.tap(first.id);
      final second = game.spawnNext(300, 300);
      expect(game.tap(first.id), isFalse);
      expect(game.tap(9999), isFalse);
      expect(game.score, equals(1));
      expect(game.tap(second.id), isTrue);
      expect(game.score, equals(2));
    });

    test('finishes at the target and ignores further taps', () {
      final game = DotGame(
        target: 3,
        difficulty: Difficulty.hard,
        random: Random(4),
      );
      for (var i = 0; i < 3; i++) {
        expect(game.isComplete, isFalse);
        game.tap(game.spawnNext(300, 300).id);
      }
      expect(game.isComplete, isTrue);
      expect(game.progress, equals(1.0));
      final extra = game.spawnNext(300, 300);
      expect(game.tap(extra.id), isFalse);
      expect(game.score, equals(3));
    });

    test('dots shrink but never below the accessible minimum', () {
      final game = DotGame(
        target: 10,
        difficulty: Difficulty.hard,
        random: Random(5),
      );
      final start = game.currentDiameter;
      for (var i = 0; i < 10; i++) {
        game.tap(game.spawnNext(400, 400).id);
      }
      expect(game.currentDiameter, lessThanOrEqualTo(start));
      expect(game.currentDiameter, greaterThanOrEqualTo(DotGame.minDiameter));
    });

    test('reset starts a fresh round', () {
      final game = DotGame(
        target: 4,
        difficulty: Difficulty.easy,
        random: Random(6),
      );
      game.tap(game.spawnNext(300, 300).id);
      game.reset();
      expect(game.score, equals(0));
      expect(game.current, isNull);
    });
  });
}
