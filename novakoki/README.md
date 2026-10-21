# NOVA KOKI

A futuristic smart alarm clock for Android. To switch the alarm off you have to
wake up properly: press **I'M AWAKE**, answer multiplication questions, then
finish a dot-tapping reaction game. Package: `com.novakoki.alarm`.

> **Status:** the source in this repository has **not been compiled or run on a
> device yet**. The only verification so far is described under
> [Verification status](#verification-status). An APK exists only after the
> GitHub Actions workflow has finished successfully.

## Get the APK from GitHub Actions

1. Create an empty repository on GitHub and push this project to it:
   ```bash
   git init -b main
   git add .
   git commit -m "NOVA KOKI"
   git remote add origin https://github.com/<you>/<repo>.git
   git push -u origin main
   ```
2. Open the repository's **Actions** tab. The *Build Android APK* workflow starts
   on every push (you can also start it with **Run workflow**).
3. Open the finished run. If every step has a green check, scroll to the
   **Artifacts** section at the bottom of the run summary and download
   **NOVA-KOKI-APK**. It is a zip file that contains `app-release.apk`.
4. Unzip it, copy the APK to your phone and open it. Android will ask you to
   allow installing from this source.

If a step fails, open it to read the log. The run summary of a successful build
shows the APK size, SHA-256 and signing type.

### Signing

Without any secrets the release APK is signed with the **Android debug key**.
That is fine for testing on your own phone but not for the Play Store. To sign
with your own key, add these repository secrets (Settings → Secrets and
variables → Actions); the workflow then writes `android/key.properties` for the
build and nothing is ever committed:

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | your `.jks` file, base64-encoded |
| `ANDROID_KEYSTORE_PASSWORD` | keystore password |
| `ANDROID_KEY_ALIAS` | key alias |
| `ANDROID_KEY_PASSWORD` | key password |

### Build tool versions

* Flutter: latest **stable** channel (not pinned). Pin it by adding
  `flutter-version: <x.y.z>` to the Flutter step if you need reproducible builds.
* Java 17 (Temurin), Android Gradle Plugin 8.11.1, Gradle 8.14, Kotlin 2.2.20,
  `minSdk 24`, `compileSdk`/`targetSdk` from Flutter.
* If a future Flutter release asks for newer Gradle/AGP/Kotlin versions, the build
  log says which. Update them in `android/settings.gradle.kts` and
  `android/gradle/wrapper/gradle-wrapper.properties`.
* GitHub Actions are pinned to major version tags (`@v4`, `@v2`, `@v3`), not to
  commit SHAs. Dependabot (`.github/dependabot.yml`) proposes updates weekly.
  For stricter supply-chain control replace each tag with the commit SHA of that
  release.
* `pubspec.lock` is not committed because it could not be generated offline.
  Run `flutter pub get` once locally and commit the lock file for repeatable builds.

## Features

* **Home:** large digital clock, date, next alarm with countdown and on/off
  status, daily mission progress, streak, completed missions, level/XP, alarm
  list (swipe to delete), shortcuts to statistics and settings.
* **Alarms:** create, edit, delete, enable/disable; time, repeat days, title,
  sound (3 bundled + device alarm tone, with preview), vibration, multiplication
  difficulty and question count, dot-game difficulty and tap count, optional snooze.
  12/24-hour display is an app-wide setting.
* **Wake-up flow:** alarm screen → multiplication challenge (4 options, wrong
  answers can be retried, every question must be answered correctly) → dot-tapping
  game (default 15 taps, optional 30 s timer, dots shrink as you progress, never
  below 48 dp) → success screen with particles, XP animation and the required
  messages. The session is recorded exactly once.
* **Gamification:** XP, levels, consecutive-day streaks (a missed day restarts the
  streak but never removes XP), best streak, accuracy, best dot time, weekly and
  monthly progress, achievements FIRST LIGHT, EARLY BIRD, NOVA STREAK, QUICK
  THINKER, REACTION MASTER.
* **Languages:** English and Persian with right-to-left layout and Persian digits.
  Dates use the Gregorian calendar in both languages.
* **Accessibility:** touch targets of at least 48 dp, semantic labels on progress
  and options, in-app *Reduce motion* plus Android's "remove animations".
* **Practice mission** on the home screen runs the challenges without an alarm
  and awards no XP.
* Fully offline; no network permission is requested.

## How alarms work on Android

* Flutter keeps the alarm list (JSON in `shared_preferences`) and sends the whole
  list to native code over the `com.novakoki.alarm/native` method channel.
* `AlarmScheduler` uses **`AlarmManager.setAlarmClock()`**: exact, works in
  Doze, shows the alarm icon in the status bar, and needs **no**
  `SCHEDULE_EXACT_ALARM` permission. Each alarm has one request code, so
  re-syncing replaces instead of duplicating.
* When an alarm fires, `AlarmReceiver` schedules the next occurrence (repeating
  alarms) or marks the one-time alarm as fired, then starts `AlarmService`, a
  foreground service (`mediaPlayback`) that plays the sound on the alarm audio
  stream, vibrates, and posts a full-screen notification that opens the app over
  the lock screen.
* `BootReceiver` re-creates alarms after a restart, app update, time change or
  time-zone change. After a restart, a one-time alarm whose time already passed is
  treated as missed (disabled) rather than moved to tomorrow.
* The alarm keeps ringing until the mission is completed, the user snoozes, uses
  *Stop alarm without mission* (no XP), or 10 minutes pass.

### Permissions

| Permission | Why |
|---|---|
| `POST_NOTIFICATIONS` | alarm notification (Android 13+), requested from the home banner/settings |
| `USE_FULL_SCREEN_INTENT` | open the alarm screen over the lock screen (Android 14+ may require the user to allow it; Settings shows the status) |
| `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK` | ring while the app is in the background |
| `VIBRATE`, `WAKE_LOCK` | vibration and waking the screen |
| `RECEIVE_BOOT_COMPLETED` | restore alarms after restart |

### Limitations (also shown in Settings)

* A **force-stopped** app does not ring until it is opened again. This is an
  Android rule that no app can bypass.
* Some manufacturers (Xiaomi, Huawei, Oppo, Samsung, …) kill background apps
  aggressively. Exclude NOVA KOKI from battery optimization (Settings → Alarm
  reliability) if alarms are late or missing. Behaviour differs per device and has
  not been tested on any device yet.
* Android decides whether the full-screen alarm screen opens over the lock
  screen. Without the permission you still get the sound and a notification.
* If Android refuses to start the foreground service from the background, the
  app falls back to a full-screen notification without looping sound.
* Snoozed alarms do not survive a device restart.
* Not implemented: optional per-question countdown in the multiplication
  challenge, optional sound effects and success sound, Jalali (Persian) calendar.

## Project layout

```
lib/
  main.dart, app.dart          bootstrap, MaterialApp, ringing-alarm hand-off
  core/                        theme, widgets, localization (EN/FA), formatting
  models/                      Alarm, WakeSession, UserProgress, AppSettings
  logic/                       pure Dart: scheduling, multiplication, dot game,
                               XP / level / streak / achievements, statistics
  data/local_store.dart        JSON persistence + schema versioning
  platform/alarm_platform.dart method-channel bridge to Android
  state/                       AppState (single source of truth), AppScope
  screens/                     home, alarm editor, mission flow, stats, settings
android/app/src/main/
  kotlin/com/novakoki/alarm/   scheduler, receivers, foreground service, sounds
  res/                         icons, synthesized alarm sounds, strings (EN/FA)
test/                          unit tests (see below)
tool/generate_assets.py        regenerates the launcher icon and alarm sounds
assets/fonts/                  Orbitron and Vazirmatn (SIL Open Font License)
.github/workflows/build-android.yml
```

Persistence uses `shared_preferences` with JSON documents (alarms, sessions,
progress, settings) and a stored schema version for future migrations. It was
chosen over SQLite to keep dependencies and native build risk low; the data
volume is tiny. Invalid or corrupt records are dropped on load.

## Tests

`flutter test` runs: alarm validation and JSON, next-occurrence scheduling,
multiplication generation and session rules, dot-game scoring, XP, levels,
streaks, achievements, statistics, and `AppState` (persistence round-trip,
single recording of a session, native sync, one-time alarm handling, corrupt
data). There are no widget or on-device tests yet.

## Verification status

Done in the authoring environment (which had no Flutter or Android SDK):

* All Dart files parse and are formatted (`dart format`).
* The pure-Dart layers (`models`, `logic`, `utils`) pass `dart analyze` with no issues.
* The unit tests were executed with a bare Dart SDK against a small stand-in for
  `flutter_test`, plus stand-ins for `flutter/foundation`, `flutter/services` and
  `shared_preferences` for the `AppState` tests: 50 tests passed. They have not been
  run with the real `flutter_test`.
* The workflow, pubspec and Android XML files were checked to be well-formed, and
  every localization key used in code exists in both languages.

**Not verified:** Flutter widget code and Kotlin code have never been compiled,
`flutter analyze` and `flutter build apk` have not run, and nothing has run on a
device or emulator. Expect to fix a few compile or lint errors on the first CI
run; the logs will point to them.

## Fonts and licenses

Orbitron and Vazirmatn are bundled under the SIL Open Font License 1.1
(`assets/fonts/OFL-*.txt`). The alarm sounds and launcher icon are generated by
`tool/generate_assets.py`.
