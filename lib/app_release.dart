import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Force update (F-11 / MOB-01), the phone's half. Every API call carries
/// this build's number (X-App-Version); below the club's minimum the API
/// answers 426 UPGRADE_REQUIRED and the router shows the Update page until
/// the app is replaced. Queued work stays queued: a 426 is neither a refusal
/// nor a failed attempt (sync.dart parkFor).

/// This build, as Android knows it (versionName, versionCode).
class AppBuild {
  const AppBuild(this.name, this.code);
  final String name;
  final int code;
}

/// Read once at start (main.dart). 0 / '' where there is no Android host:
/// tests and web send no version, so nothing ever holds them back.
AppBuild appBuild = const AppBuild('', 0);

/// MainActivity.kt answers it: a few lines of Kotlin instead of a plugin.
const _channel = MethodChannel('o_house/app');

Future<void> loadAppBuild() async {
  try {
    final m = await _channel.invokeMapMethod<String, Object?>('build');
    appBuild = AppBuild('${m?['name'] ?? ''}', (m?['code'] as num?)?.toInt() ?? 0);
  } catch (_) {
    // No channel (tests, web): no version is sent, and nobody is held back.
  }
}

/// The header every API call adds; empty while the build is unknown.
Map<String, String> get appVersionHeaders =>
    appBuild.code > 0 ? {'x-app-version': '${appBuild.code}'} : const {};

/// Non-null once the API said this build is too old: the download link,
/// or '' when the club set none. The router listens to it.
final upgradeRequired = ValueNotifier<String?>(null);

/// Records a 426 answer. Pure apart from the notifier; any body is fine.
void noteUpgrade(String body) {
  var url = '';
  try {
    final j = jsonDecode(body);
    if (j is Map && j['updateUrl'] is String) url = j['updateUrl'] as String;
  } on FormatException {
    // A 426 without our body still means "update".
  }
  upgradeRequired.value = url;
}

/// Opens the download link in the phone's browser.
Future<void> openUpdateLink(String url) => _channel.invokeMethod<void>('openUrl', url);
