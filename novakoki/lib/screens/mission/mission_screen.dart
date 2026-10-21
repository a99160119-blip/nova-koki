import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../state/app_scope.dart';
import '../../state/app_state.dart';
import 'dot_game_stage.dart';
import 'mission_config.dart';
import 'multiplication_stage.dart';
import 'ring_stage.dart';
import 'success_stage.dart';

export 'mission_config.dart';

enum MissionStage { ring, multiplication, dots, success }

/// Runs the whole wake-up flow: ring, multiplication, dots, success.
class MissionScreen extends StatefulWidget {
  const MissionScreen({super.key, required this.config});

  final MissionConfig config;

  @override
  State<MissionScreen> createState() => _MissionScreenState();
}

class _MissionScreenState extends State<MissionScreen> {
  late final AppState _app;
  late MissionStage _stage;
  late final DateTime _startedAt;
  MultiplicationOutcome? _mult;
  DotOutcome? _dots;

  @override
  void initState() {
    super.initState();
    _app = AppScope.read(context);
    _app.beginMission(widget.config.alarmId);
    _startedAt = DateTime.now();
    _stage = widget.config.practice
        ? MissionStage.multiplication
        : MissionStage.ring;
  }

  @override
  void dispose() {
    _app.endMission();
    super.dispose();
  }

  void _finish() => Navigator.of(context).pop();

  Future<void> _handleBack() async {
    switch (_stage) {
      case MissionStage.ring:
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.tr('ring_hint'))));
      case MissionStage.multiplication:
      case MissionStage.dots:
        final leave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(ctx.tr('leave_title')),
            content: Text(ctx.tr('leave_body')),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(ctx.tr('stay')),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(ctx.tr('leave')),
              ),
            ],
          ),
        );
        if (leave != true || !mounted) return;
        if (widget.config.practice) {
          _finish();
        } else {
          // The alarm keeps ringing; go back to the wake-up screen.
          setState(() => _stage = MissionStage.ring);
        }
      case MissionStage.success:
        _finish();
    }
  }

  Widget _buildStage() {
    switch (_stage) {
      case MissionStage.ring:
        return RingStage(
          key: const ValueKey<String>('ring'),
          config: widget.config,
          onAwake: () => setState(() => _stage = MissionStage.multiplication),
          onClose: _finish,
        );
      case MissionStage.multiplication:
        return MultiplicationStage(
          key: const ValueKey<String>('mult'),
          config: widget.config,
          onDone: (outcome) => setState(() {
            _mult = outcome;
            _stage = MissionStage.dots;
          }),
        );
      case MissionStage.dots:
        return DotGameStage(
          key: const ValueKey<String>('dots'),
          config: widget.config,
          onDone: (outcome) => setState(() {
            _dots = outcome;
            _stage = MissionStage.success;
          }),
        );
      case MissionStage.success:
        return SuccessStage(
          key: const ValueKey<String>('success'),
          config: widget.config,
          startedAt: _startedAt,
          mult: _mult!,
          dots: _dots!,
          onContinue: _finish,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _buildStage(),
          ),
        ),
      ),
    );
  }
}
