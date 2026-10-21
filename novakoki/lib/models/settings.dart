class AppSettings {
  const AppSettings({
    this.localeCode = 'system',
    this.use24h = true,
    this.haptics = true,
    this.reducedMotion = false,
    this.dotTimer = false,
  });

  /// 'system', 'en' or 'fa'.
  final String localeCode;
  final bool use24h;
  final bool haptics;
  final bool reducedMotion;

  /// Optional 30-second limit in the dot-tapping game.
  final bool dotTimer;

  AppSettings copyWith({
    String? localeCode,
    bool? use24h,
    bool? haptics,
    bool? reducedMotion,
    bool? dotTimer,
  }) {
    return AppSettings(
      localeCode: localeCode ?? this.localeCode,
      use24h: use24h ?? this.use24h,
      haptics: haptics ?? this.haptics,
      reducedMotion: reducedMotion ?? this.reducedMotion,
      dotTimer: dotTimer ?? this.dotTimer,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'localeCode': localeCode,
    'use24h': use24h,
    'haptics': haptics,
    'reducedMotion': reducedMotion,
    'dotTimer': dotTimer,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    bool asBool(Object? v, bool fallback) => v is bool ? v : fallback;
    final code = json['localeCode'];
    return AppSettings(
      localeCode: code == 'en' || code == 'fa' ? code as String : 'system',
      use24h: asBool(json['use24h'], true),
      haptics: asBool(json['haptics'], true),
      reducedMotion: asBool(json['reducedMotion'], false),
      dotTimer: asBool(json['dotTimer'], false),
    );
  }
}
