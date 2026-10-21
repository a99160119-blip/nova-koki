/// Small shared helpers that do not depend on Flutter.
int clampInt(int value, int low, int high) {
  if (value < low) return low;
  if (value > high) return high;
  return value;
}

double clampDouble01(double value) {
  if (value < 0) return 0;
  if (value > 1) return 1;
  return value;
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

const String _persianDigits = '۰۱۲۳۴۵۶۷۸۹';

/// Converts ASCII digits to Persian digits.
String toPersianDigits(String input) {
  final buffer = StringBuffer();
  for (final unit in input.codeUnits) {
    if (unit >= 0x30 && unit <= 0x39) {
      buffer.write(_persianDigits[unit - 0x30]);
    } else {
      buffer.writeCharCode(unit);
    }
  }
  return buffer.toString();
}

String twoDigits(int value) => value.toString().padLeft(2, '0');
