import 'dart:math';

import '../models/alarm.dart';

class DotTarget {
  const DotTarget({
    required this.id,
    required this.center,
    required this.radius,
  });

  final int id;
  final Point<double> center;
  final double radius;
}

/// Logic of the dot-tapping game, independent of any widget.
class DotGame {
  DotGame({required this.target, required this.difficulty, Random? random})
    : _rng = random ?? Random();

  /// Smallest allowed dot diameter, in logical pixels (accessible touch target).
  static const double minDiameter = 48;

  final int target;
  final Difficulty difficulty;
  final Random _rng;

  int _score = 0;
  int _nextId = 1;
  DotTarget? _current;
  Point<double>? _last;

  int get score => _score;
  DotTarget? get current => _current;
  bool get isComplete => _score >= target;
  double get progress {
    if (target <= 0) return 1;
    final p = _score / target;
    return p > 1 ? 1 : p;
  }

  static double baseDiameter(Difficulty d) => switch (d) {
    Difficulty.easy => 88,
    Difficulty.medium => 72,
    Difficulty.hard => 60,
  };

  /// Dots shrink by up to 20% as the round progresses, never below [minDiameter].
  double get currentDiameter {
    final size = baseDiameter(difficulty) * (1 - 0.2 * progress);
    return size < minDiameter ? minDiameter : size;
  }

  Point<double> _randomPoint(
    double minX,
    double maxX,
    double minY,
    double maxY,
  ) {
    return Point<double>(
      minX + _rng.nextDouble() * (maxX - minX),
      minY + _rng.nextDouble() * (maxY - minY),
    );
  }

  /// Creates the next dot fully inside a [width] x [height] play area.
  DotTarget spawnNext(double width, double height) {
    final diameter = currentDiameter;
    final radius = diameter / 2;
    final minX = radius;
    final maxX = width - radius > radius ? width - radius : radius;
    final minY = radius;
    final maxY = height - radius > radius ? height - radius : radius;
    final last = _last;
    var point = _randomPoint(minX, maxX, minY, maxY);
    for (
      var i = 0;
      i < 20 && last != null && point.distanceTo(last) < diameter * 1.5;
      i++
    ) {
      point = _randomPoint(minX, maxX, minY, maxY);
    }
    _last = point;
    final dot = DotTarget(id: _nextId++, center: point, radius: radius);
    _current = dot;
    return dot;
  }

  /// Registers a tap on dot [id]. Only the current dot scores, and only once.
  bool tap(int id) {
    final dot = _current;
    if (isComplete || dot == null || dot.id != id) return false;
    _score++;
    _current = null;
    return true;
  }

  void reset() {
    _score = 0;
    _current = null;
    _last = null;
  }
}
