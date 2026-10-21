import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/l10n.dart';
import 'core/theme.dart';
import 'core/widgets.dart';
import 'screens/home_screen.dart';
import 'screens/mission/mission_screen.dart';
import 'state/app_scope.dart';
import 'state/app_state.dart';

class NovaKokiApp extends StatefulWidget {
  const NovaKokiApp({super.key, required this.state});

  final AppState state;

  @override
  State<NovaKokiApp> createState() => _NovaKokiAppState();
}

class _NovaKokiAppState extends State<NovaKokiApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.state.platform.setRingingListener(_openMission);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkRinging());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.state.platform.setRingingListener(null);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.state.refreshOnResume().then((_) => _checkRinging());
    }
  }

  /// Shows the alarm screen if an alarm is ringing right now.
  Future<void> _checkRinging() async {
    final id = await widget.state.platform.getRingingAlarm();
    if (id != null) _openMission(id);
  }

  void _openMission(int alarmId) {
    final app = widget.state;
    if (app.activeMissionAlarmId == alarmId) return;
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    app.beginMission(alarmId);
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => MissionScreen(
          config: MissionConfig.forAlarm(app.alarmById(alarmId), alarmId),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: widget.state,
      child: ListenableBuilder(
        listenable: widget.state,
        builder: (context, _) {
          final locale = widget.state.locale;
          return MaterialApp(
            navigatorKey: _navigatorKey,
            title: 'NOVA KOKI',
            debugShowCheckedModeBanner: false,
            theme: buildNovaTheme(fa: locale.languageCode == 'fa'),
            locale: locale,
            supportedLocales: Strings.supportedLocales,
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              StringsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) =>
                NovaBackground(child: child ?? const SizedBox.shrink()),
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
