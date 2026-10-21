import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../logic/alarm_schedule.dart';
import '../models/alarm.dart';
import '../state/app_scope.dart';
import '../state/app_state.dart';

class AlarmEditScreen extends StatefulWidget {
  const AlarmEditScreen({super.key, this.alarm});

  /// Null when creating a new alarm.
  final Alarm? alarm;

  @override
  State<AlarmEditScreen> createState() => _AlarmEditScreenState();
}

class _AlarmEditScreenState extends State<AlarmEditScreen> {
  late final AppState _app;
  late Alarm _draft;
  late final TextEditingController _title;

  @override
  void initState() {
    super.initState();
    _app = AppScope.read(context);
    _draft = widget.alarm ?? Alarm(id: _app.nextAlarmId(), hour: 7, minute: 0);
    _title = TextEditingController(text: _draft.title);
  }

  @override
  void dispose() {
    _app.platform.stopPreview();
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final use24 = _app.settings.use24h;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _draft.hour, minute: _draft.minute),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: use24),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (picked != null) {
      setState(
        () =>
            _draft = _draft.copyWith(hour: picked.hour, minute: picked.minute),
      );
    }
  }

  void _setDays(Set<int> days) =>
      setState(() => _draft = _draft.copyWith(repeatDays: days));

  Future<void> _save() async {
    final errors = _draft.validate();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (errors.isNotEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(context.tr(errors.first))));
      return;
    }
    final saved = _draft.copyWith(enabled: true, title: _title.text.trim());
    final now = DateTime.now();
    final remaining = nextOccurrence(saved, now).difference(now);
    final message = context
        .tr('alarm_set_for')
        .replaceAll('{t}', remainingText(context, remaining));
    await _app.platform.stopPreview();
    await _app.upsertAlarm(saved);
    messenger.showSnackBar(SnackBar(content: Text(message)));
    navigator.pop();
  }

  Future<void> _delete() async {
    final navigator = Navigator.of(context);
    final ok = await showDialog<bool>(
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
    if (ok == true) {
      await _app.deleteAlarm(_draft.id);
      navigator.pop();
    }
  }

  Widget _difficultyPicker(
    Difficulty value,
    ValueChanged<Difficulty> onChanged,
  ) {
    return SegmentedButton<Difficulty>(
      showSelectedIcon: false,
      segments: <ButtonSegment<Difficulty>>[
        ButtonSegment<Difficulty>(
          value: Difficulty.easy,
          label: Text(context.tr('easy')),
        ),
        ButtonSegment<Difficulty>(
          value: Difficulty.medium,
          label: Text(context.tr('medium')),
        ),
        ButtonSegment<Difficulty>(
          value: Difficulty.hard,
          label: Text(context.tr('hard')),
        ),
      ],
      selected: <Difficulty>{value},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 6),
    child: Text(
      text,
      style: NovaText.body(14, color: NovaColors.textSecondary),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final use24 = _app.settings.use24h;
    final clock = formatClock(
      context,
      _draft.hour,
      _draft.minute,
      use24h: use24,
    );
    final isNew = widget.alarm == null;
    final days = _draft.repeatDays;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr(isNew ? 'new_alarm' : 'edit_alarm'),
          style: NovaText.display(18),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: <Widget>[
            GlassCard(
              glow: NovaColors.blue,
              onTap: _pickTime,
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Directionality(
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
                          style: NovaText.display(60, spacing: 2),
                        ),
                        if (clock.suffix != null)
                          Text(
                            ' ${clock.suffix}',
                            style: NovaText.display(20, color: NovaColors.blue),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              maxLength: Alarm.maxTitleLength,
              decoration: InputDecoration(
                hintText: context.tr('title_hint'),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 8),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _label(context.tr('repeat')),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: <Widget>[
                      for (var d = 1; d <= 7; d++)
                        FilterChip(
                          label: Text(context.tr('d$d')),
                          selected: days.contains(d),
                          onSelected: (selected) {
                            final next = Set<int>.of(days);
                            if (selected) {
                              next.add(d);
                            } else {
                              next.remove(d);
                            }
                            _setDays(next);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: <Widget>[
                      ActionChip(
                        label: Text(context.tr('repeat_once')),
                        onPressed: () => _setDays(<int>{}),
                      ),
                      ActionChip(
                        label: Text(context.tr('repeat_daily')),
                        onPressed: () => _setDays(<int>{1, 2, 3, 4, 5, 6, 7}),
                      ),
                      ActionChip(
                        label: Text(context.tr('repeat_weekdays')),
                        onPressed: () => _setDays(<int>{1, 2, 3, 4, 5}),
                      ),
                      ActionChip(
                        label: Text(context.tr('repeat_weekend')),
                        onPressed: () => _setDays(<int>{6, 7}),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    repeatSummary(context, days),
                    style: NovaText.muted(12.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _label(context.tr('sound')),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: <Widget>[
                      for (final sound in kAlarmSounds)
                        ChoiceChip(
                          avatar: const Icon(Icons.volume_up_rounded, size: 18),
                          label: Text(context.tr('snd_$sound')),
                          selected: _draft.sound == sound,
                          onSelected: (_) {
                            setState(
                              () => _draft = _draft.copyWith(sound: sound),
                            );
                            _app.platform.previewSound(sound);
                          },
                        ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.tr('vibration')),
                    value: _draft.vibrate,
                    onChanged: (v) =>
                        setState(() => _draft = _draft.copyWith(vibrate: v)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    context.tr('challenge'),
                    style: NovaText.display(14, color: NovaColors.blue),
                  ),
                  const SizedBox(height: 10),
                  _label(context.tr('mult_difficulty')),
                  _difficultyPicker(
                    _draft.difficulty,
                    (v) =>
                        setState(() => _draft = _draft.copyWith(difficulty: v)),
                  ),
                  const SizedBox(height: 8),
                  _label(
                    '${context.tr('questions')}: ${context.num(_draft.questionCount)}',
                  ),
                  Slider(
                    value: _draft.questionCount.toDouble(),
                    min: Alarm.minQuestions.toDouble(),
                    max: Alarm.maxQuestions.toDouble(),
                    divisions: Alarm.maxQuestions - Alarm.minQuestions,
                    label: context.num(_draft.questionCount),
                    onChanged: (v) => setState(
                      () => _draft = _draft.copyWith(questionCount: v.round()),
                    ),
                  ),
                  _label(context.tr('dot_difficulty')),
                  _difficultyPicker(
                    _draft.dotDifficulty,
                    (v) => setState(
                      () => _draft = _draft.copyWith(dotDifficulty: v),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _label(
                    '${context.tr('dot_taps')}: ${context.num(_draft.dotTarget)}',
                  ),
                  Slider(
                    value: _draft.dotTarget.toDouble(),
                    min: Alarm.minDots.toDouble(),
                    max: Alarm.maxDots.toDouble(),
                    divisions: Alarm.maxDots - Alarm.minDots,
                    label: context.num(_draft.dotTarget),
                    onChanged: (v) => setState(
                      () => _draft = _draft.copyWith(dotTarget: v.round()),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.tr('snooze')),
                    value: _draft.snoozeEnabled,
                    onChanged: (v) => setState(
                      () => _draft = _draft.copyWith(snoozeEnabled: v),
                    ),
                  ),
                  if (_draft.snoozeEnabled) ...<Widget>[
                    _label(context.tr('snooze_minutes')),
                    Wrap(
                      spacing: 8,
                      children: <Widget>[
                        for (final m in const <int>[5, 10, 15])
                          ChoiceChip(
                            label: Text(
                              context
                                  .tr('minutes_n')
                                  .replaceAll('{n}', context.num(m)),
                            ),
                            selected: _draft.snoozeMinutes == m,
                            onSelected: (_) => setState(
                              () => _draft = _draft.copyWith(snoozeMinutes: m),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            NeonButton(
              label: context.tr('save'),
              icon: Icons.check_rounded,
              onPressed: _save,
            ),
            if (!isNew) ...<Widget>[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _delete,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: NovaColors.danger,
                ),
                label: Text(
                  context.tr('delete'),
                  style: const TextStyle(color: NovaColors.danger),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
