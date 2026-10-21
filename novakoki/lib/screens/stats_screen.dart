import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/l10n.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../logic/gamification.dart';
import '../logic/stats.dart';
import '../state/app_scope.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final progress = app.progress;
    final now = app.now;
    final level = app.level;
    final week = StatsCalculator.lastDaysCounts(app.sessions, now, 7);
    final month = StatsCalculator.completedInMonth(app.sessions, now);
    final weekMax = week.fold<int>(1, (m, v) => v > m ? v : m);
    final lang = context.strings.languageCode;
    final recent = app.sessions.reversed.take(8).toList();
    final bestDot = progress.bestDotTimeMs;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('stats'), style: NovaText.display(18)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: <Widget>[
            GlassCard(
              glow: NovaColors.purple,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        '${context.tr('level')} ${context.num(level)}',
                        style: NovaText.display(24),
                      ),
                      const Spacer(),
                      Text(
                        '${context.num(progress.totalXp)} ${context.tr('xp')}',
                        style: NovaText.display(16, color: NovaColors.blue),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  NeonProgress(
                    value: LevelCalculator.progressInLevel(progress.totalXp),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${context.num(LevelCalculator.xpForLevel(level + 1) - progress.totalXp)} ${context.tr('xp')} → ${context.tr('level')} ${context.num(level + 1)}',
                    style: NovaText.muted(12.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: _Metric(
                    label: context.tr('current_streak'),
                    value:
                        '${context.num(app.displayStreak)} ${context.tr('days_short')}',
                    color: NovaColors.pink,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Metric(
                    label: context.tr('best_streak'),
                    value:
                        '${context.num(progress.bestStreak)} ${context.tr('days_short')}',
                    color: NovaColors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: _Metric(
                    label: context.tr('total_missions'),
                    value: context.num(progress.completedSessions),
                    color: NovaColors.blue,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Metric(
                    label: context.tr('mult_accuracy'),
                    value: progress.multAttempts == 0
                        ? '—'
                        : '${context.num((progress.multAccuracy * 100).round())}%',
                    color: NovaColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _Metric(
              label: context.tr('best_dot_time'),
              value: bestDot == null
                  ? '—'
                  : context
                        .tr('seconds_n')
                        .replaceAll(
                          '{n}',
                          context.num((bestDot / 1000).toStringAsFixed(1)),
                        ),
              color: NovaColors.blue,
            ),
            SectionTitle(context.tr('weekly')),
            GlassCard(
              child: SizedBox(
                height: 150,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    for (var i = 0; i < week.length; i++)
                      Expanded(
                        child: _Bar(
                          count: week[i],
                          fraction: week[i] / weekMax,
                          label: DateFormat('E', lang).format(
                            DateTime(now.year, now.month, now.day - (6 - i)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            GlassCard(
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      context.tr('monthly'),
                      style: NovaText.body(15),
                    ),
                  ),
                  Text(
                    context.num(month),
                    style: NovaText.display(20, color: NovaColors.blue),
                  ),
                ],
              ),
            ),
            SectionTitle(context.tr('achievements')),
            for (final id in AchievementIds.all)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _AchievementTile(
                  id: id,
                  unlocked: progress.unlocked.contains(id),
                ),
              ),
            SectionTitle(context.tr('recent')),
            if (recent.isEmpty)
              GlassCard(
                child: Text(
                  context.tr('no_sessions'),
                  style: NovaText.muted(14),
                ),
              )
            else
              for (final s in recent)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            context.num(
                              DateFormat(
                                'd MMM, HH:mm',
                                lang,
                              ).format(s.completedAt),
                            ),
                            style: NovaText.body(14),
                          ),
                        ),
                        Text(
                          '+${context.num(s.xpEarned)} ${context.tr('xp')}',
                          style: NovaText.body(
                            14,
                            color: NovaColors.success,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: NovaText.muted(12.5)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(value, style: NovaText.display(20, color: color)),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.count,
    required this.fraction,
    required this.label,
  });

  final int count;
  final double fraction;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        Text(context.num(count), style: NovaText.muted(12)),
        const SizedBox(height: 4),
        Flexible(
          child: FractionallySizedBox(
            heightFactor: count == 0 ? 0.04 : (fraction < 0.1 ? 0.1 : fraction),
            child: Container(
              width: 18,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                gradient: const LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: <Color>[NovaColors.purple, NovaColors.blue],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: NovaText.muted(11)),
      ],
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.id, required this.unlocked});

  final String id;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final color = unlocked ? NovaColors.success : NovaColors.textSecondary;
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: <Widget>[
          Icon(
            unlocked ? Icons.emoji_events_rounded : Icons.lock_rounded,
            color: color,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  context.tr('ach_$id'),
                  style: NovaText.display(
                    13,
                    color: unlocked ? Colors.white : color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(context.tr('ach_${id}_d'), style: NovaText.muted(12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
