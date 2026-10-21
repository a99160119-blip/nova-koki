import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../state/app_scope.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final settings = app.settings;
    final status = app.status;

    Widget switchTile(String key, bool value, ValueChanged<bool> onChanged) {
      return SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(context.tr(key)),
        value: value,
        onChanged: onChanged,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('settings'), style: NovaText.display(18)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: <Widget>[
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(context.tr('language'), style: NovaText.muted(13)),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: <ButtonSegment<String>>[
                      ButtonSegment<String>(
                        value: 'system',
                        label: Text(context.tr('lang_system')),
                      ),
                      const ButtonSegment<String>(
                        value: 'en',
                        label: Text('English'),
                      ),
                      const ButtonSegment<String>(
                        value: 'fa',
                        label: Text('فارسی'),
                      ),
                    ],
                    selected: <String>{settings.localeCode},
                    onSelectionChanged: (s) => app.updateSettings(
                      settings.copyWith(localeCode: s.first),
                    ),
                  ),
                  const SizedBox(height: 8),
                  switchTile(
                    'time_format_24',
                    settings.use24h,
                    (v) => app.updateSettings(settings.copyWith(use24h: v)),
                  ),
                  switchTile(
                    'haptics',
                    settings.haptics,
                    (v) => app.updateSettings(settings.copyWith(haptics: v)),
                  ),
                  switchTile(
                    'reduced_motion',
                    settings.reducedMotion,
                    (v) =>
                        app.updateSettings(settings.copyWith(reducedMotion: v)),
                  ),
                  switchTile(
                    'dot_timer',
                    settings.dotTimer,
                    (v) => app.updateSettings(settings.copyWith(dotTimer: v)),
                  ),
                ],
              ),
            ),
            SectionTitle(context.tr('permissions')),
            GlassCard(
              child: Column(
                children: <Widget>[
                  _PermissionRow(
                    title: context.tr('perm_notifications'),
                    ok: status.notificationsGranted,
                    okText: context.tr('granted'),
                    badText: context.tr('not_granted'),
                    onFix: () async {
                      final granted = await app.requestNotificationPermission();
                      if (!granted)
                        await app.platform.openNotificationSettings();
                    },
                  ),
                  _PermissionRow(
                    title: context.tr('perm_fullscreen'),
                    ok: status.fullScreenIntentGranted,
                    okText: context.tr('granted'),
                    badText: context.tr('not_granted'),
                    onFix: app.platform.openFullScreenIntentSettings,
                  ),
                  _PermissionRow(
                    title: context.tr('perm_battery'),
                    ok: status.batteryUnrestricted,
                    okText: context.tr('battery_ok'),
                    badText: context.tr('battery_limited'),
                    onFix: app.platform.openBatterySettings,
                  ),
                ],
              ),
            ),
            SectionTitle(context.tr('limitations')),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (var i = 1; i <= 5; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Icon(
                              Icons.info_outline_rounded,
                              size: 16,
                              color: NovaColors.blue,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              context.tr('lim_$i'),
                              style: NovaText.body(
                                13.5,
                                color: NovaColors.textSecondary,
                              ).copyWith(height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            SectionTitle(context.tr('about')),
            GlassCard(
              child: Row(
                children: <Widget>[
                  const NovaMark(size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('NOVA KOKI', style: NovaText.display(16)),
                        Text(
                          context.tr('version'),
                          style: NovaText.muted(12.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.title,
    required this.ok,
    required this.okText,
    required this.badText,
    required this.onFix,
  });

  final String title;
  final bool ok;
  final String okText;
  final String badText;
  final Future<void> Function() onFix;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Icon(
            ok ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
            color: ok ? NovaColors.success : NovaColors.pink,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: NovaText.body(15, weight: FontWeight.w600)),
                Text(ok ? okText : badText, style: NovaText.muted(12.5)),
              ],
            ),
          ),
          if (!ok)
            TextButton(
              onPressed: onFix,
              child: Text(context.tr('open_settings')),
            ),
        ],
      ),
    );
  }
}
