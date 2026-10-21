import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/alarm.dart';
import '../models/progress.dart';
import '../models/session.dart';
import '../models/settings.dart';

/// Local persistence on top of SharedPreferences (JSON documents).
///
/// Everything is stored on the device, so the app works fully offline. Records
/// that fail validation are dropped instead of crashing the app.
class LocalStore {
  LocalStore._(this._prefs);

  final SharedPreferences _prefs;

  static const int currentSchemaVersion = 1;
  static const String _kSchema = 'schema_version';
  static const String _kAlarms = 'alarms_v1';
  static const String _kSessions = 'sessions_v1';
  static const String _kProgress = 'progress_v1';
  static const String _kSettings = 'settings_v1';

  static Future<LocalStore> open() async {
    final prefs = await SharedPreferences.getInstance();
    final store = LocalStore._(prefs);
    await store._migrate();
    return store;
  }

  /// Version 0 (no marker) to 1 only stamps the version; later schema changes
  /// add their conversion steps here, in order.
  Future<void> _migrate() async {
    final version = _prefs.getInt(_kSchema) ?? 0;
    if (version < 1) {
      await _prefs.setInt(_kSchema, 1);
    }
  }

  int get schemaVersion => _prefs.getInt(_kSchema) ?? 0;

  Object? _decode(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  List<Alarm> loadAlarms() {
    final data = _decode(_kAlarms);
    if (data is! List) return <Alarm>[];
    final alarms = <Alarm>[];
    final seen = <int>{};
    for (final entry in data) {
      if (entry is! Map) continue;
      final alarm = Alarm.fromJson(Map<String, dynamic>.from(entry));
      if (alarm.id <= 0 || !seen.add(alarm.id)) continue;
      if (alarm.validate().isEmpty) alarms.add(alarm);
    }
    return alarms;
  }

  Future<void> saveAlarms(List<Alarm> alarms) async {
    await _prefs.setString(
      _kAlarms,
      jsonEncode(alarms.map((a) => a.toJson()).toList()),
    );
  }

  List<WakeSession> loadSessions() {
    final data = _decode(_kSessions);
    if (data is! List) return <WakeSession>[];
    final sessions = <WakeSession>[];
    final ids = <String>{};
    for (final entry in data) {
      if (entry is! Map) continue;
      final session = WakeSession.tryFromJson(Map<String, dynamic>.from(entry));
      if (session != null && ids.add(session.id)) sessions.add(session);
    }
    return sessions;
  }

  Future<void> saveSessions(List<WakeSession> sessions) async {
    await _prefs.setString(
      _kSessions,
      jsonEncode(sessions.map((s) => s.toJson()).toList()),
    );
  }

  UserProgress loadProgress() {
    final data = _decode(_kProgress);
    if (data is! Map) return UserProgress.empty;
    return UserProgress.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> saveProgress(UserProgress progress) async {
    await _prefs.setString(_kProgress, jsonEncode(progress.toJson()));
  }

  AppSettings loadSettings() {
    final data = _decode(_kSettings);
    if (data is! Map) return const AppSettings();
    return AppSettings.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> saveSettings(AppSettings settings) async {
    await _prefs.setString(_kSettings, jsonEncode(settings.toJson()));
  }
}
