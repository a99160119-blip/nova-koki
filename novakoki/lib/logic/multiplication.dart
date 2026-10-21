import 'dart:math';

import '../models/alarm.dart';

class MultQuestion {
  const MultQuestion({required this.a, required this.b, required this.options});

  final int a;
  final int b;

  /// Four distinct answer options, one of which is correct.
  final List<int> options;

  int get answer => a * b;
  int get correctIndex => options.indexOf(answer);
}

class MultiplicationGenerator {
  MultiplicationGenerator({Random? random}) : _rng = random ?? Random();

  final Random _rng;

  int _between(int min, int max) => min + _rng.nextInt(max - min + 1);

  MultQuestion next(Difficulty difficulty) {
    final (int a, int b) = switch (difficulty) {
      Difficulty.easy => (_between(2, 9), _between(2, 9)),
      Difficulty.medium => (_between(11, 25), _between(3, 9)),
      Difficulty.hard => (_between(12, 49), _between(6, 19)),
    };
    final answer = a * b;
    final options = <int>{answer};
    final candidates = <int>[
      answer + a,
      answer - a,
      answer + b,
      answer - b,
      answer + 10,
      answer - 10,
      answer + 1,
      answer - 1,
      answer + 2,
      answer - 2,
    ]..shuffle(_rng);
    for (final candidate in candidates) {
      if (options.length >= 4) break;
      if (candidate > 0) options.add(candidate);
    }
    var spread = 3;
    while (options.length < 4) {
      options.add(answer + _between(1, spread));
      spread++;
    }
    final list = options.toList()..shuffle(_rng);
    return MultQuestion(a: a, b: b, options: List<int>.unmodifiable(list));
  }
}

/// Pure challenge logic: the UI only renders [current] and forwards taps.
///
/// A wrong answer never advances; the same question stays until it is answered
/// correctly, so the user must answer every question correctly to finish.
class MultiplicationSession {
  MultiplicationSession({
    required this.difficulty,
    required this.questionCount,
    Random? random,
  }) : _generator = MultiplicationGenerator(random: random) {
    _current = _generator.next(difficulty);
  }

  final Difficulty difficulty;
  final int questionCount;
  final MultiplicationGenerator _generator;

  late MultQuestion _current;
  int _index = 0;
  int _correct = 0;
  int _attempts = 0;

  MultQuestion get current => _current;

  /// Zero-based index of the question being answered.
  int get index => _index;
  int get correctAnswers => _correct;
  int get attempts => _attempts;
  int get wrongAnswers => _attempts - _correct;
  bool get isComplete => _index >= questionCount;

  /// Share of answer taps that were correct (0 when nothing was answered yet).
  double get accuracy => _attempts == 0 ? 0 : _correct / _attempts;

  /// Submits the option at [optionIndex]. Returns true only for a correct answer.
  bool answer(int optionIndex) {
    if (isComplete) return false;
    if (optionIndex < 0 || optionIndex >= _current.options.length) return false;
    _attempts++;
    if (_current.options[optionIndex] == _current.answer) {
      _correct++;
      _index++;
      if (!isComplete) _current = _generator.next(difficulty);
      return true;
    }
    return false;
  }
}
