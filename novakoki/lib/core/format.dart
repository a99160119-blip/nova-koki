import 'package:flutter/widgets.dart';

import 'l10n.dart';
import 'utils.dart';

class ClockText {
  const ClockText(this.time, this.suffix);

  /// e.g. `06:30` or `6:30`.
  final String time;

  /// `AM` / `PM` (localized) in 12-hour mode, otherwise null.
  final String? suffix;

  String get full => suffix == null ? time : '$time $suffix';
}

ClockText formatClock(
  BuildContext context,
  int hour,
  int minute, {
  required bool use24h,
}) {
  final s = context.strings;
  if (use24h) {
    return ClockText(s.digits('${twoDigits(hour)}:${twoDigits(minute)}'), null);
  }
  final h12 = hour % 12 == 0 ? 12 : hour % 12;
  return ClockText(
    s.digits('$h12:${twoDigits(minute)}'),
    hour < 12 ? s.t('am') : s.t('pm'),
  );
}

/// "in 7h 12m" style text for the time left until an alarm.
String remainingText(BuildContext context, Duration remaining) {
  final s = context.strings;
  final totalMinutes =
      remaining.inMinutes + (remaining.inSeconds % 60 > 0 ? 1 : 0);
  if (totalMinutes <= 0) return s.t('less_than_minute');
  final days = totalMinutes ~/ (24 * 60);
  final hours = (totalMinutes % (24 * 60)) ~/ 60;
  final minutes = totalMinutes % 60;
  final parts = <String>[];
  if (days > 0) parts.add('${s.digits(days)} ${s.t('unit_d')}');
  if (hours > 0) parts.add('${s.digits(hours)} ${s.t('unit_h')}');
  if (minutes > 0 && days == 0)
    parts.add('${s.digits(minutes)} ${s.t('unit_m')}');
  return s.t('in_time').replaceAll('{t}', parts.join(' '));
}

/// Short repeat description: "Every day", "Mon, Wed", "One time only".
String repeatSummary(BuildContext context, Set<int> days) {
  final s = context.strings;
  if (days.isEmpty) return s.t('repeat_once');
  if (days.length == 7) return s.t('repeat_daily');
  final sorted = days.toList()..sort();
  return sorted.map((d) => s.t('d$d')).join(s.isFa ? '، ' : ', ');
}
