import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../logic/multiplication.dart';
import '../../state/app_scope.dart';
import '../../state/app_state.dart';
import 'mission_config.dart';

/// Multiplication challenge: every question must be answered correctly.
class MultiplicationStage extends StatefulWidget {
  const MultiplicationStage({
    super.key,
    required this.config,
    required this.onDone,
  });

  final MissionConfig config;
  final ValueChanged<MultiplicationOutcome> onDone;

  @override
  State<MultiplicationStage> createState() => _MultiplicationStageState();
}

class _MultiplicationStageState extends State<MultiplicationStage> {
  late final AppState _app;
  late final MultiplicationSession _session;
  late MultQuestion _question;
  final Set<int> _wrong = <int>{};
  int? _flashCorrect;
  bool _locked = false;
  String? _feedbackKey;
  Timer? _advance;

  @override
  void initState() {
    super.initState();
    _app = AppScope.read(context);
    _session = MultiplicationSession(
      difficulty: widget.config.multDifficulty,
      questionCount: widget.config.questionCount,
    );
    _question = _session.current;
  }

  @override
  void dispose() {
    _advance?.cancel();
    super.dispose();
  }

  void _onOption(int index) {
    if (_locked || _wrong.contains(index)) return;
    final correct = _session.answer(index);
    _app.haptic();
    if (!correct) {
      setState(() {
        _wrong.add(index);
        _feedbackKey = 'try_again';
      });
      return;
    }
    setState(() {
      _locked = true;
      _flashCorrect = index;
      _feedbackKey = 'nice';
    });
    _advance = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      if (_session.isComplete) {
        widget.onDone(
          MultiplicationOutcome(
            questions: _session.questionCount,
            correct: _session.correctAnswers,
            attempts: _session.attempts,
          ),
        );
        return;
      }
      setState(() {
        _question = _session.current;
        _wrong.clear();
        _flashCorrect = null;
        _locked = false;
        _feedbackKey = null;
      });
    });
  }

  Widget _option(int index) {
    final value = _question.options[index];
    final isWrong = _wrong.contains(index);
    final isCorrect = _flashCorrect == index;
    final base = isCorrect
        ? NovaColors.success
        : (isWrong ? NovaColors.danger : NovaColors.blue);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Semantics(
          button: true,
          label: context.num(value),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: isWrong || _locked ? null : () => _onOption(index),
              child: Ink(
                height: 84,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: base.withValues(alpha: isWrong ? 0.12 : 0.18),
                  border: Border.all(
                    color: base.withValues(alpha: 0.8),
                    width: 1.5,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: base.withValues(alpha: 0.25),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: Center(
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      context.num(value),
                      style: NovaText.display(
                        28,
                        color: isWrong
                            ? NovaColors.textSecondary
                            : Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _session.questionCount;
    final shownIndex =
        (_session.isComplete ? total : _session.index + (_locked ? 0 : 1))
            .clamp(1, total);
    final accuracy = (_session.accuracy * 100).round();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  context.tr('mult_title'),
                  style: NovaText.display(18),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${context.tr('accuracy')} ${context.num(accuracy)}%',
                  style: NovaText.body(12.5, weight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              context
                  .tr('question_of')
                  .replaceAll('{n}', context.num(shownIndex))
                  .replaceAll('{t}', context.num(total)),
              style: NovaText.muted(14),
            ),
          ),
          const SizedBox(height: 8),
          Semantics(
            value: '${_session.index} / $total',
            child: NeonProgress(value: _session.index / total),
          ),
          const SizedBox(height: 28),
          GlassCard(
            glow: NovaColors.purple,
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 12),
            child: Center(
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${context.num(_question.a)} × ${context.num(_question.b)} = ?',
                    style: NovaText.display(44, spacing: 2),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(children: <Widget>[_option(0), _option(1)]),
          Row(children: <Widget>[_option(2), _option(3)]),
          const SizedBox(height: 14),
          SizedBox(
            height: 24,
            child: AnimatedOpacity(
              opacity: _feedbackKey == null ? 0 : 1,
              duration: const Duration(milliseconds: 150),
              child: Text(
                _feedbackKey == null ? '' : context.tr(_feedbackKey!),
                style: NovaText.body(
                  15,
                  weight: FontWeight.w700,
                  color: _feedbackKey == 'nice'
                      ? NovaColors.success
                      : NovaColors.danger,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
