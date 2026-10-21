import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:novakoki/logic/multiplication.dart';
import 'package:novakoki/models/alarm.dart';

void main() {
  group('MultiplicationGenerator', () {
    test(
      'every question has four distinct positive options including the answer',
      () {
        final generator = MultiplicationGenerator(random: Random(1));
        for (final difficulty in Difficulty.values) {
          for (var i = 0; i < 300; i++) {
            final q = generator.next(difficulty);
            expect(q.options.length, equals(4));
            expect(q.options.toSet().length, equals(4));
            expect(q.options.every((o) => o > 0), isTrue);
            expect(q.options.contains(q.a * q.b), isTrue);
            expect(q.options[q.correctIndex], equals(q.a * q.b));
          }
        }
      },
    );

    test('difficulty controls operand ranges', () {
      final generator = MultiplicationGenerator(random: Random(2));
      for (var i = 0; i < 200; i++) {
        final easy = generator.next(Difficulty.easy);
        expect(easy.a, inInclusiveRange(2, 9));
        expect(easy.b, inInclusiveRange(2, 9));
        final hard = generator.next(Difficulty.hard);
        expect(hard.a, inInclusiveRange(12, 49));
        expect(hard.b, inInclusiveRange(6, 19));
      }
    });
  });

  group('MultiplicationSession', () {
    test('a wrong answer does not advance and the question stays', () {
      final session = MultiplicationSession(
        difficulty: Difficulty.easy,
        questionCount: 3,
        random: Random(3),
      );
      final q = session.current;
      final wrongIndex = q.options.indexWhere((o) => o != q.answer);
      expect(session.answer(wrongIndex), isFalse);
      expect(session.index, equals(0));
      expect(identical(session.current, q), isTrue);
      expect(session.attempts, equals(1));
      expect(session.correctAnswers, equals(0));
      expect(session.isComplete, isFalse);
    });

    test('completes only after every question is answered correctly', () {
      final session = MultiplicationSession(
        difficulty: Difficulty.medium,
        questionCount: 4,
        random: Random(4),
      );
      var guard = 0;
      while (!session.isComplete && guard++ < 100) {
        final q = session.current;
        // One deliberate mistake on every question first.
        final wrong = q.options.indexWhere((o) => o != q.answer);
        expect(session.answer(wrong), isFalse);
        expect(session.answer(q.correctIndex), isTrue);
      }
      expect(session.isComplete, isTrue);
      expect(session.correctAnswers, equals(4));
      expect(session.attempts, equals(8));
      expect(session.accuracy, closeTo(0.5, 1e-9));
    });

    test('answers after completion and invalid indexes are ignored', () {
      final session = MultiplicationSession(
        difficulty: Difficulty.easy,
        questionCount: 1,
        random: Random(5),
      );
      expect(session.answer(-1), isFalse);
      expect(session.answer(9), isFalse);
      expect(session.attempts, equals(0));
      expect(session.answer(session.current.correctIndex), isTrue);
      expect(session.isComplete, isTrue);
      expect(session.answer(0), isFalse);
      expect(session.attempts, equals(1));
    });
  });
}
