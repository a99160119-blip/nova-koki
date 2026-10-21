import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../logic/gamification.dart';
import '../../models/session.dart';
import '../../state/app_scope.dart';
import '../../state/app_state.dart';
import 'mission_config.dart';

/// Celebration screen. Records the session exactly once and awards XP.
class SuccessStage extends StatefulWidget {
  const SuccessStage({
    super.key,
    required this.config,
    required this.startedAt,
    required this.mult,
    required this.dots,
    required this.onContinue,
  });

  final MissionConfig config;
  final DateTime startedAt;
  final MultiplicationOutcome mult;
  final DotOutcome dots;
  final VoidCallback onContinue;

  @override
  State<SuccessStage> createState() => _SuccessStageState();
}

class _Particle {
  const _Particle(this.angle, this.speed, this.size, this.phase, this.color);

  final double angle;
  final double speed;
  final double size;
  final double phase;
  final Color color;
}

class _SuccessStageState extends State<SuccessStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  );
  late final List<_Particle> _particles;
  bool _recorded = false;
  SessionReward? _reward;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(7);
    const palette = <Color>[
      NovaColors.purple,
      NovaColors.blue,
      NovaColors.pink,
      Colors.white,
    ];
    _particles = List<_Particle>.generate(
      70,
      (i) => _Particle(
        rng.nextDouble() * 2 * math.pi,
        0.35 + rng.nextDouble() * 0.65,
        1.5 + rng.nextDouble() * 3.5,
        rng.nextDouble(),
        palette[rng.nextInt(palette.length)],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _record());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _anim.stop();
    } else if (!_anim.isAnimating) {
      _anim.repeat();
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _record() async {
    if (_recorded || !mounted) return;
    _recorded = true;
    final app = AppScope.read(context);
    final config = widget.config;
    if (config.practice) return;
    await app.platform.stopAlarm();
    final reward = await app.completeMission(
      MissionResult(
        sessionId: config.sessionId,
        alarmId: config.alarmId,
        scheduledAt: config.scheduledAt,
        startedAt: widget.startedAt,
        multDifficulty: config.multDifficulty,
        dotDifficulty: config.dotDifficulty,
        multQuestions: widget.mult.questions,
        multCorrect: widget.mult.correct,
        multAttempts: widget.mult.attempts,
        dotScore: widget.dots.score,
        dotDurationMs: widget.dots.durationMs,
      ),
    );
    if (mounted) setState(() => _reward = reward);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = reduceMotion(context);
    final reward = _reward;
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: ExcludeSemantics(
            child: CustomPaint(painter: _ParticlePainter(_anim, _particles)),
          ),
        ),
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            children: <Widget>[
              SizedBox(
                width: 170,
                height: 170,
                child: ExcludeSemantics(
                  child: AnimatedBuilder(
                    animation: _anim,
                    builder: (context, _) => CustomPaint(
                      painter: NovaMarkPainter(
                        glow: reduce
                            ? 1
                            : 0.8 + 0.2 * math.sin(_anim.value * 2 * math.pi),
                        rotation: reduce ? 0 : _anim.value * 2 * math.pi / 4,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  context.tr('congrats'),
                  style: NovaText.display(32, spacing: 2).copyWith(
                    shadows: <Shadow>[
                      Shadow(
                        color: NovaColors.purple.withValues(alpha: 0.9),
                        blurRadius: 22,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                context.tr('mission_done'),
                textAlign: TextAlign.center,
                style: NovaText.display(15, color: NovaColors.blue, spacing: 1),
              ),
              const SizedBox(height: 18),
              GlassCard(
                child: Text(
                  '“${context.tr('motivation')}”',
                  textAlign: TextAlign.center,
                  style: NovaText.body(16).copyWith(height: 1.45),
                ),
              ),
              const SizedBox(height: 14),
              if (widget.config.practice)
                GlassCard(
                  child: Text(
                    context.tr('practice_done'),
                    textAlign: TextAlign.center,
                    style: NovaText.muted(14),
                  ),
                )
              else if (reward != null)
                _RewardCard(reward: reward, reduce: reduce),
              const SizedBox(height: 18),
              Text(
                context.tr('brand_line'),
                textAlign: TextAlign.center,
                style: NovaText.display(
                  12,
                  color: NovaColors.textSecondary,
                  spacing: 1,
                ),
              ),
              const SizedBox(height: 18),
              NeonButton(
                label: context.tr('continue_day'),
                icon: Icons.rocket_launch_rounded,
                height: 62,
                onPressed: widget.onContinue,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RewardCard extends StatelessWidget {
  const _RewardCard({required this.reward, required this.reduce});

  final SessionReward reward;
  final bool reduce;

  @override
  Widget build(BuildContext context) {
    final level = LevelCalculator.levelForXp(reward.totalXp);
    return GlassCard(
      glow: NovaColors.blue,
      child: Column(
        children: <Widget>[
          Text(context.tr('xp_earned'), style: NovaText.muted(13)),
          const SizedBox(height: 4),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(
              begin: 0,
              end: reward.session.xpEarned.toDouble(),
            ),
            duration: reduce
                ? Duration.zero
                : const Duration(milliseconds: 1400),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => Text(
              '+${context.num(value.round())} ${context.tr('xp')}',
              style: NovaText.display(34, color: NovaColors.success),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Text(
                '${context.tr('level')} ${context.num(level)}',
                style: NovaText.body(14, weight: FontWeight.w700),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: NeonProgress(
                  value: LevelCalculator.progressInLevel(reward.totalXp),
                  height: 8,
                ),
              ),
            ],
          ),
          if (reward.leveledUp) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              context
                  .tr('level_up')
                  .replaceAll('{n}', context.num(reward.levelAfter)),
              textAlign: TextAlign.center,
              style: NovaText.body(
                14,
                color: NovaColors.pink,
                weight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(
                Icons.local_fire_department_rounded,
                color: NovaColors.pink,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                context
                    .tr('streak_now')
                    .replaceAll('{n}', context.num(reward.streak)),
                style: NovaText.body(14, weight: FontWeight.w600),
              ),
            ],
          ),
          if (reward.newAchievements.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            Text(context.tr('new_badges'), style: NovaText.muted(13)),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final id in reward.newAchievements)
                  Chip(
                    avatar: const Icon(
                      Icons.emoji_events_rounded,
                      size: 18,
                      color: NovaColors.success,
                    ),
                    label: Text(context.tr('ach_$id')),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter(this.animation, this.particles) : super(repaint: animation);

  final Animation<double> animation;
  final List<_Particle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.2);
    final maxDist = size.longestSide * 0.6;
    for (final p in particles) {
      final t = (animation.value + p.phase) % 1.0;
      final dist = p.speed * t * maxDist;
      final pos =
          center + Offset(math.cos(p.angle) * dist, math.sin(p.angle) * dist);
      canvas.drawCircle(
        pos,
        p.size * (1 - 0.5 * t),
        Paint()
          ..color = p.color.withValues(alpha: (1 - t) * 0.9)
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 2.5),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => false;
}
