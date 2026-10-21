import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'strings_data.dart';
import 'utils.dart';

/// Minimal localization for English and Persian (see [kStrings]).
class Strings {
  const Strings(this.languageCode);

  final String languageCode;

  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fa'),
  ];

  bool get isFa => languageCode == 'fa';

  String t(String key) {
    final table = kStrings[languageCode] ?? kStrings['en']!;
    return table[key] ?? kStrings['en']![key] ?? key;
  }

  /// Digits in the active language (Persian digits for Persian).
  String digits(Object value) {
    final text = value.toString();
    return isFa ? toPersianDigits(text) : text;
  }

  static Strings of(BuildContext context) =>
      Localizations.of<Strings>(context, Strings) ?? const Strings('en');
}

class StringsDelegate extends LocalizationsDelegate<Strings> {
  const StringsDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'en' || locale.languageCode == 'fa';

  @override
  Future<Strings> load(Locale locale) =>
      SynchronousFuture<Strings>(Strings(locale.languageCode));

  @override
  bool shouldReload(StringsDelegate old) => false;
}

extension NovaL10n on BuildContext {
  Strings get strings => Strings.of(this);
  String tr(String key) => Strings.of(this).t(key);
  bool get isFa => Strings.of(this).isFa;
  String num(Object value) => Strings.of(this).digits(value);
}
