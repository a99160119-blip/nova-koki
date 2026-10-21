import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/l10n.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../state/app_scope.dart';
import 'mission_config.dart';

/// The alarm screen: large clock, sound waves and the I'M AWAKE button.
/// The alarm sound is played natively and keeps going until the mission ends.
class RingStage extends StatefulWidget {
  const RingStage({
    super.key,
    required this.config,
    required this.onAwake,
    required this.onClose,
  });

  final MissionConfig config;
  final VoidCallback onAwake;

  /// Leaves the mission screen (after snooze or stopping the alarm).
  final VoidCallback onClose;

  @override
  State<RingStage> createState() => _RingStageState();
}

class _RingStageState extends State<RingStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waves = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  );
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _waves.stop();
    } else if (!_waves.isAnimating) {
      _waves.repeat();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _waves.dispose();
    super.dispose();
  }

  Future<void> _snooze() async {
    final app = AppScope.read(context);
    final id = widget.config.alarmId;
    if (id == null) return;
    await app.platform.snooze(id, widget.config.snoozeMinutes);
    widget.onClose();
  }

  Future<void> _stop() async {
    final app = AppScope.read(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(ctx.tr('stop_alarm_q')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.tr('stop')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await app.platform.stopAlarm();
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final use24 = AppScope.of(context).settings.use24h;
    final clock = formatClock(context, _now.hour, _now.minute, use24h: use24);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Column(
                children: <Widget>[
                  const SizedBox(height: 12),
                  const NovaMark(size: 64),
                  const SizedBox(height: 12),
                  Text(
                    context.tr('alarm_ringing'),
                    style: NovaText.display(
                      22,
                      color: NovaColors.blue,
                      spacing: 4,
                    ),
                  ),
                  if (widget.config.title.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      widget.config.title,
                      textAlign: TextAlign.center,
                      style: NovaText.body(20, weight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
              Column(
                children: <Widget>[
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: <Widget>[
                          Text(
                            clock.time,
                            style: NovaText.display(78, spacing: 2).copyWith(
                              shadows: <Shadow>[
                                Shadow(
                                  color: NovaColors.purple.withValues(
                                    alpha: 0.9,
                                  ),
                                  blurRadius: 28,
                                ),
                                Shadow(
                                  color: NovaColors.blue.withValues(alpha: 0.6),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                          ),
                          if (clock.suffix != null)
                            Text(
                              ' ${clock.suffix}',
                              style: NovaText.display(
                                22,
                                color: NovaColors.blue,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 90,
                    width: double.infinity,
                    child: ExcludeSemantics(
                      child: CustomPaint(painter: _WavesPainter(_waves)),
                    ),
                  ),
                ],
              ),
              Column(
                children: <Widget>[
                  Text(
                    context.tr('ring_hint'),
                    textAlign: TextAlign.center,
                    style: NovaText.muted(13),
                  ),
                  const SizedBox(height: 14),
                  NeonButton(
                    label: context.tr('im_awake'),
                    icon: Icons.wb_sunny_rounded,
                    height: 76,
                    fontSize: 26,
                    onPressed: widget.onAwake,
                  ),
                  if (widget.config.snoozeEnabled) ...<Widget>[
                    const SizedBox(height: 10),
                    GhostButton(
                      label:
                          '${context.tr('snooze_btn')} (${context.tr('minutes_n').replaceAll('{n}', context.num(widget.config.snoozeMinutes))})',
                      icon: Icons.snooze_rounded,
                      onPressed: _snooze,
                    ),
                  ],
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: _stop,
                    child: Text(
                      context.tr('stop_alarm'),
                      style: NovaText.muted(13),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WavesPainter extends CustomPainter {
  _WavesPainter(this.animation) : super(repaint: animation);

  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    const colors = <Color>[NovaColors.purple, NovaColors.blue, NovaColors.pink];
    for (var layer = 0; layer < 3; layer++) {
      final path = Path();
      final amp = size.height * (0.38 - layer * 0.09);
      final phase =
          animation.value * 2 * math.pi * (layer + 1) * (layer.isEven ? 1 : -1);
      for (var x = 0.0; x <= size.width; x += 3) {
        final t = x / size.width;
        final envelope = math.sin(t * math.pi);
        final y =
            mid +
            math.sin(t * 2 * math.pi * (2 + layer) + phase) * amp * envelope;
        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = colors[layer].withValues(alpha: 0.85)
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WavesPainter oldDelegate) => false;
}
