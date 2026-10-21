import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../logic/dot_game.dart';
import '../../state/app_scope.dart';
import '../../state/app_state.dart';
import 'mission_config.dart';

/// Reaction game: tap glowing dots until the target count is reached.
class DotGameStage extends StatefulWidget {
  const DotGameStage({super.key, required this.config, required this.onDone});

  final MissionConfig config;
  final ValueChanged<DotOutcome> onDone;

  @override
  State<DotGameStage> createState() => _DotGameStageState();
}

class _DotGameStageState extends State<DotGameStage> {
  static const int _timeLimitMs = 30000;

  late final AppState _app;
  late final DotGame _game;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _ticker;
  Timer? _messageTimer;
  Size _area = Size.zero;
  bool _done = false;
  bool _timerEnabled = false;
  int _remainingMs = _timeLimitMs;
  bool _showTimesUp = false;

  @override
  void initState() {
    super.initState();
    _app = AppScope.read(context);
    _timerEnabled = _app.settings.dotTimer;
    _game = DotGame(
      target: widget.config.dotTarget,
      difficulty: widget.config.dotDifficulty,
    );
    _stopwatch.start();
    if (_timerEnabled) {
      _ticker = Timer.periodic(
        const Duration(milliseconds: 100),
        (_) => _tick(),
      );
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _messageTimer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  void _tick() {
    if (!mounted || _done) return;
    final left = _timeLimitMs - _stopwatch.elapsedMilliseconds;
    if (left <= 0) {
      _restartRound();
    } else {
      setState(() => _remainingMs = left);
    }
  }

  void _restartRound() {
    _game.reset();
    _stopwatch
      ..reset()
      ..start();
    if (_area != Size.zero) _game.spawnNext(_area.width, _area.height);
    _messageTimer?.cancel();
    _messageTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _showTimesUp = false);
    });
    setState(() {
      _remainingMs = _timeLimitMs;
      _showTimesUp = true;
    });
  }

  void _onTapDot(int id) {
    if (_done) return;
    // Only the current dot can score, and only once.
    if (!_game.tap(id)) return;
    _app.haptic();
    if (_game.isComplete) {
      _done = true;
      _ticker?.cancel();
      _stopwatch.stop();
      widget.onDone(
        DotOutcome(
          score: _game.score,
          durationMs: _stopwatch.elapsedMilliseconds,
        ),
      );
      return;
    }
    setState(() {
      _game.spawnNext(_area.width, _area.height);
    });
  }

  Widget _dot(DotTarget dot, bool reduce) {
    final diameter = dot.radius * 2;
    return TweenAnimationBuilder<double>(
      key: ValueKey<int>(dot.id),
      tween: Tween<double>(begin: reduce ? 1 : 0.3, end: 1),
      duration: reduce ? Duration.zero : const Duration(milliseconds: 160),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onTapDot(dot.id),
        child: Container(
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: <Color>[Colors.white, NovaColors.blue, NovaColors.purple],
              stops: <double>[0.0, 0.45, 1.0],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: NovaColors.blue.withValues(alpha: 0.7),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reduce = reduceMotion(context);
    final taps = context
        .tr('taps_progress')
        .replaceAll('{n}', context.num(_game.score))
        .replaceAll('{t}', context.num(_game.target));
    final seconds = (_remainingMs / 1000).ceil();
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  context.tr('dot_title'),
                  style: NovaText.display(18),
                ),
              ),
              if (_timerEnabled)
                Text(
                  '${context.tr('time_left')}: ${context.num(seconds)}',
                  style: NovaText.body(
                    14,
                    weight: FontWeight.w700,
                    color: seconds <= 5 ? NovaColors.danger : NovaColors.blue,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(taps, style: NovaText.muted(14)),
          ),
          const SizedBox(height: 8),
          Semantics(
            value: taps,
            child: NeonProgress(value: _game.progress),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  border: Border.all(
                    color: NovaColors.blue.withValues(alpha: 0.35),
                  ),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _area = Size(constraints.maxWidth, constraints.maxHeight);
                    if (_game.current == null && !_game.isComplete) {
                      _game.spawnNext(_area.width, _area.height);
                    }
                    final dot = _game.current;
                    return Stack(
                      children: <Widget>[
                        if (dot != null)
                          Positioned(
                            left: dot.center.x - dot.radius,
                            top: dot.center.y - dot.radius,
                            child: _dot(dot, reduce),
                          ),
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: 12,
                          child: Center(
                            child: Text(
                              _showTimesUp
                                  ? context.tr('times_up')
                                  : context.tr('dot_hint'),
                              textAlign: TextAlign.center,
                              style: _showTimesUp
                                  ? NovaText.body(
                                      14,
                                      color: NovaColors.danger,
                                      weight: FontWeight.w700,
                                    )
                                  : NovaText.muted(12.5),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
