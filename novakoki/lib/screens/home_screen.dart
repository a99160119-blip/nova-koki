import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/format.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../models/alarm.dart';
import '../state/app_scope.dart';
import '../state/app_state.dart';
import 'alarm_edit_screen.dart';
import 'mission/mission_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final next = app.nextAlarm(_now);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: <Widget>[
            _Header(
              onStats: () => _open(const StatsScreen()),
              onSettings: () => _open(const SettingsScreen()),
            ),
            const SizedBox(height: 18),
            _ClockCard(now: _now, next: next),
            if (!app.status.notificationsGranted) ...<Widget>[
              const SizedBox(height: 14),
              const _PermissionBanner(),
            ],
            const SizedBox(height: 14),
            _StatsRow(app: app),
            const SizedBox(height: 14),
            _DailyProgress(app: app),
            const SizedBox(height: 18),
            NeonButton(
              label: context.tr('create_alarm'),
              icon: Icons.add_alarm_rounded,
              onPressed: () => _open(const AlarmEditScreen()),
            ),
            const SizedBox(height: 12),
            GhostButton(
              label: context.tr('practice'),
              icon: Icons.sports_esports_rounded,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      MissionScreen(config: MissionConfig.practice()),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4, right: 4),
              child: Text(
                context.tr('practice_hint'),
                style: NovaText.muted(12),
              ),
            ),
            const SizedBox(height: 14),
            SectionTitle(context.tr('your_alarms')),
            if (app.alarms.isEmpty)
              GlassCard(
                child: Text(
                  context.tr('no_alarms_hint'),
                  style: NovaText.muted(14),
                ),
              )
            else
              for (final alarm in app.alarms)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _AlarmTile(
                    alarm: alarm,
                    onEdit: () => _open(AlarmEditScreen(alarm: alarm)),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onStats, required this.onSettings});

  final VoidCallback onStats;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const NovaMark(size: 40),
        const SizedBox(width: 10),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text('NOVA KOKI', style: NovaText.display(22, spacing: 2)),
          ),
        ),
        IconButton(
          tooltip: context.tr('stats'),
          onPressed: onStats,
          iconSize: 28,
          icon: const Icon(Icons.insights_rounded, color: NovaColors.blue),
        ),
        IconButton(
          tooltip: context.tr('settings'),
          onPressed: onSettings,
          iconSize: 28,
          icon: const Icon(Icons.settings_rounded, color: NovaColors.purple),
        ),
      ],
    );
  }
}

class _ClockCard extends StatelessWidget {
  const _ClockCard({required this.now, required this.next});

  final DateTime now;
  final NextAlarm? next;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final use24 = app.settings.use24h;
    final clock = formatClock(context, now.hour, now.minute, use24h: use24);
    final lang = context.strings.languageCode;
    final date = DateFormat('EEEE, d MMMM yyyy', lang).format(now);
    final nextClock = next == null
        ? null
        : formatClock(
            context,
            next!.alarm.hour,
            next!.alarm.minute,
            use24h: use24,
          );
    return GlassCard(
      glow: NovaColors.purple,
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 16),
      child: Column(
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
                    style: NovaText.display(64, spacing: 2).copyWith(
                      shadows: <Shadow>[
                        Shadow(
                          color: NovaColors.blue.withValues(alpha: 0.7),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                  ),
                  if (clock.suffix != null)
                    Text(
                      ' ${clock.suffix}',
                      style: NovaText.display(18, color: NovaColors.blue),
                    ),
                  Text(
                    ' ${context.num(now.second.toString().padLeft(2, '0'))}',
                    style: NovaText.display(
                      18,
                      color: NovaColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.isFa ? context.num(date) : date,
            style: NovaText.muted(15),
            textAlign: TextAlign.center,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: Colors.white12),
          ),
          Row(
            children: <Widget>[
              Icon(
                next == null ? Icons.alarm_off_rounded : Icons.alarm_on_rounded,
                color: next == null
                    ? NovaColors.textSecondary
                    : NovaColors.success,
                size: 30,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      next == null
                          ? context.tr('no_alarm')
                          : context.tr('next_alarm'),
                      style: NovaText.muted(13),
                    ),
                    if (next != null)
                      Text(
                        '${nextClock!.full}  •  ${remainingText(context, next!.at.difference(now))}',
                        style: NovaText.body(16, weight: FontWeight.w600),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: (next == null ? Colors.white : NovaColors.success)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  next == null
                      ? context.tr('alarm_off')
                      : context.tr('alarm_on'),
                  style: NovaText.body(
                    12,
                    color: next == null
                        ? NovaColors.textSecondary
                        : NovaColors.success,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.read(context);
    return GlassCard(
      glow: NovaColors.pink,
      child: Row(
        children: <Widget>[
          const Icon(Icons.notifications_off_rounded, color: NovaColors.pink),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  context.tr('perm_notif_title'),
                  style: NovaText.body(15, weight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  context.tr('perm_notif_body'),
                  style: NovaText.muted(12.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () async {
              final granted = await app.requestNotificationPermission();
              if (!granted) await app.platform.openNotificationSettings();
            },
            child: Text(context.tr('allow')),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _StatTile(
            icon: Icons.local_fire_department_rounded,
            color: NovaColors.pink,
            value: context.num(app.displayStreak),
            label: context.tr('streak'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            icon: Icons.flag_rounded,
            color: NovaColors.blue,
            value: context.num(app.progress.completedSessions),
            label: context.tr('missions'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            icon: Icons.bolt_rounded,
            color: NovaColors.purple,
            value: '${context.tr('level')} ${context.num(app.level)}',
            label: '${context.num(app.progress.totalXp)} ${context.tr('xp')}',
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      child: Column(
        children: <Widget>[
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: NovaText.display(17)),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, style: NovaText.muted(12)),
          ),
        ],
      ),
    );
  }
}

class _DailyProgress extends StatelessWidget {
  const _DailyProgress({required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    final done = app.completedToday;
    final planned = app.scheduledToday;
    final total = planned > done ? planned : done;
    final value = total == 0 ? 0.0 : done / total;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  context.tr('daily_progress'),
                  style: NovaText.body(15, weight: FontWeight.w600),
                ),
              ),
              Text(
                '${context.num(done)} / ${context.num(total)}',
                style: NovaText.display(15, color: NovaColors.blue),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Semantics(
            label: context.tr('daily_progress'),
            value: '${context.num(done)} / ${context.num(total)}',
            child: NeonProgress(value: value),
          ),
        ],
      ),
    );
  }
}

class _AlarmTile extends StatelessWidget {
  const _AlarmTile({required this.alarm, required this.onEdit});

  final Alarm alarm;
  final VoidCallback onEdit;

  Future<bool> _confirmDelete(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('delete_alarm_q')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              ctx.tr('delete'),
              style: const TextStyle(color: NovaColors.danger),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Widget _background(Alignment alignment) => Container(
    alignment: alignment,
    padding: const EdgeInsets.symmetric(horizontal: 24),
    decoration: BoxDecoration(
      color: NovaColors.danger.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(24),
    ),
    child: const Icon(Icons.delete_rounded, color: Colors.white, size: 28),
  );

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final clock = formatClock(
      context,
      alarm.hour,
      alarm.minute,
      use24h: app.settings.use24h,
    );
    final subtitle = alarm.title.isEmpty
        ? repeatSummary(context, alarm.repeatDays)
        : '${alarm.title}  •  ${repeatSummary(context, alarm.repeatDays)}';
    return Dismissible(
      key: ValueKey<int>(alarm.id),
      direction: DismissDirection.horizontal,
      background: _background(
        AlignmentDirectional.centerStart.resolve(Directionality.of(context)),
      ),
      secondaryBackground: _background(
        AlignmentDirectional.centerEnd.resolve(Directionality.of(context)),
      ),
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) => app.deleteAlarm(alarm.id),
      child: GlassCard(
        onTap: onEdit,
        child: Opacity(
          opacity: alarm.enabled ? 1 : 0.55,
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: <Widget>[
                          Text(clock.time, style: NovaText.display(30)),
                          if (clock.suffix != null)
                            Text(
                              ' ${clock.suffix}',
                              style: NovaText.display(
                                13,
                                color: NovaColors.blue,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: NovaText.muted(13),
                    ),
                  ],
                ),
              ),
              Switch(
                value: alarm.enabled,
                onChanged: (value) => app.setAlarmEnabled(alarm.id, value),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
