import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/alarm.dart';

/// What Android currently allows for alarms. [unknown] is used off-device.
class PlatformStatus {
  const PlatformStatus({
    required this.supported,
    required this.notificationsGranted,
    required this.fullScreenIntentGranted,
    required this.batteryUnrestricted,
    required this.sdkInt,
  });

  static const PlatformStatus unknown = PlatformStatus(
    supported: false,
    notificationsGranted: true,
    fullScreenIntentGranted: true,
    batteryUnrestricted: true,
    sdkInt: 0,
  );

  final bool supported;
  final bool notificationsGranted;
  final bool fullScreenIntentGranted;
  final bool batteryUnrestricted;
  final int sdkInt;
}

/// Bridge to the native Android alarm code (scheduling, sound, permissions).
abstract class AlarmPlatform {
  /// Replaces all scheduled alarms with [alarms] (no duplicates are possible).
  Future<void> syncAlarms(List<Alarm> alarms);

  /// Id of the alarm that is ringing right now, if any.
  Future<int?> getRingingAlarm();

  Future<void> stopAlarm();
  Future<void> snooze(int alarmId, int minutes);
  Future<PlatformStatus> getStatus();
  Future<bool> requestNotificationPermission();
  Future<void> openFullScreenIntentSettings();
  Future<void> openNotificationSettings();
  Future<void> openBatterySettings();
  Future<void> previewSound(String sound);
  Future<void> stopPreview();

  /// Ids of one-time alarms that fired (or were missed) since the last call.
  Future<List<int>> consumeFiredOneShots();

  /// Called when an alarm starts ringing while the app is running.
  void setRingingListener(void Function(int alarmId)? listener);
}

class MethodChannelAlarmPlatform implements AlarmPlatform {
  MethodChannelAlarmPlatform() {
    _channel.setMethodCallHandler(_onCall);
  }

  static const MethodChannel _channel = MethodChannel(
    'com.novakoki.alarm/native',
  );

  void Function(int alarmId)? _ringingListener;

  Future<dynamic> _onCall(MethodCall call) async {
    if (call.method == 'alarmRinging') {
      final id = call.arguments;
      if (id is int) _ringingListener?.call(id);
    }
    return null;
  }

  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  @override
  void setRingingListener(void Function(int alarmId)? listener) {
    _ringingListener = listener;
  }

  @override
  Future<void> syncAlarms(List<Alarm> alarms) async {
    await _invoke<bool>(
      'syncAlarms',
      jsonEncode(alarms.map((a) => a.toNativeJson()).toList()),
    );
  }

  @override
  Future<int?> getRingingAlarm() => _invoke<int>('getRingingAlarm');

  @override
  Future<void> stopAlarm() async {
    await _invoke<void>('stopAlarm');
  }

  @override
  Future<void> snooze(int alarmId, int minutes) async {
    await _invoke<void>('snooze', <String, Object>{
      'alarmId': alarmId,
      'minutes': minutes,
    });
  }

  @override
  Future<PlatformStatus> getStatus() async {
    try {
      final map = await _channel.invokeMapMethod<String, dynamic>('getStatus');
      if (map == null) return PlatformStatus.unknown;
      return PlatformStatus(
        supported: true,
        notificationsGranted: map['notificationsGranted'] != false,
        fullScreenIntentGranted: map['fullScreenIntentGranted'] != false,
        batteryUnrestricted: map['batteryUnrestricted'] == true,
        sdkInt: map['sdkInt'] is int ? map['sdkInt'] as int : 0,
      );
    } on MissingPluginException {
      return PlatformStatus.unknown;
    } on PlatformException {
      return PlatformStatus.unknown;
    }
  }

  @override
  Future<bool> requestNotificationPermission() async =>
      (await _invoke<bool>('requestNotificationPermission')) ?? false;

  @override
  Future<void> openFullScreenIntentSettings() async {
    await _invoke<void>('openFullScreenIntentSettings');
  }

  @override
  Future<void> openNotificationSettings() async {
    await _invoke<void>('openNotificationSettings');
  }

  @override
  Future<void> openBatterySettings() async {
    await _invoke<void>('openBatterySettings');
  }

  @override
  Future<void> previewSound(String sound) async {
    await _invoke<void>('previewSound', <String, Object>{'sound': sound});
  }

  @override
  Future<void> stopPreview() async {
    await _invoke<void>('stopPreview');
  }

  @override
  Future<List<int>> consumeFiredOneShots() async {
    try {
      final list = await _channel.invokeListMethod<dynamic>(
        'consumeFiredOneShots',
      );
      return (list ?? <dynamic>[]).whereType<int>().toList();
    } on MissingPluginException {
      return <int>[];
    } on PlatformException {
      return <int>[];
    }
  }
}
