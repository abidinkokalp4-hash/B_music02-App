import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../distribution.dart';
import '../platform/device_controls.dart';

/// A newer GitHub release than the installed build.
class AppRelease {
  const AppRelease({required this.build, required this.tag, required this.apkUrl,
      this.notes = '', this.size = 0});
  final int build;
  final String tag, apkUrl, notes;
  final int size;
}

/// In-app updater for APKs installed outside Google Play: checks the latest
/// GitHub release, downloads B_music02.apk to the cache and hands it to the
/// system installer (FileProvider + REQUEST_INSTALL_PACKAGES). Disabled when
/// Google Play installed the app (Play updates it instead).
class AppUpdateService extends ChangeNotifier {
  AppUpdateService({http.Client? client}) : _client = client ?? http.Client();
  static final instance = AppUpdateService();
  static const latestApi =
      'https://api.github.com/repos/abidinkokalp4-hash/B_music02-App/releases/latest';
  static const apkName = 'B_music02.apk';
  static const _checkedKey = 'bmusic_update_checked_at', _skipKey = 'bmusic_update_skipped';
  static const checkEvery = Duration(hours: 12);
  final http.Client _client;
  AppRelease? available;
  double? progress;
  File? downloaded;

  /// "v1.0.123" -> 123 (release tags are v1.0.<CI run number>).
  static int? buildOf(String tag) =>
      int.tryParse(RegExp(r'^v?1\.0\.(\d+)$').firstMatch(tag.trim())?.group(1) ?? '');

  static AppRelease? parse(Map<String, dynamic> json, int currentBuild) {
    final tag = '${json['tag_name'] ?? ''}';
    final build = buildOf(tag);
    if (build == null || build <= currentBuild || json['draft'] == true || json['prerelease'] == true) return null;
    final assets = (json['assets'] as List? ?? const []).whereType<Map>();
    final apk = assets.where((a) => a['name'] == apkName).firstOrNull;
    final url = apk?['browser_download_url'];
    if (url is! String || !url.startsWith('https://github.com/')) return null;
    var notes = '${json['body'] ?? ''}'.trim();
    if (notes.length > 1200) notes = '${notes.substring(0, 1200)}…';
    return AppRelease(build: build, tag: tag, apkUrl: url, notes: notes,
        size: (apk?['size'] as num?)?.toInt() ?? 0);
  }

  Future<AppRelease?> check({required int currentBuild, bool force = false}) async {
    if (kPlayBuild) return null; // Google Play updates Play builds.
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!force && now - (prefs.getInt(_checkedKey) ?? 0) < checkEvery.inMilliseconds) return available;
    try {
      final response = await _client.get(Uri.parse(latestApi),
          headers: {'Accept': 'application/vnd.github+json'}).timeout(const Duration(seconds: 12));
      await prefs.setInt(_checkedKey, now);
      if (response.statusCode != 200) return null;
      available = parse(jsonDecode(response.body) as Map<String, dynamic>, currentBuild);
      notifyListeners();
      debugPrint('[BMusic feature] update-check latest=${available?.tag ?? 'none'}');
      return available;
    } catch (error) {
      debugPrint('[BMusic feature] update-check failed: $error');
      return null;
    }
  }

  /// Native info: installer package, Play install flag, cache folder.
  Future<Map<String, dynamic>> info() async {
    if (kPlayBuild || kIsWeb || !Platform.isAndroid) return const {'fromPlay': true};
    try {
      return await DeviceControls.updateInfo();
    } catch (_) {
      return const {'fromPlay': true};
    }
  }

  Future<bool> skipped(AppRelease release) async =>
      (await SharedPreferences.getInstance()).getString(_skipKey) == release.tag;
  Future<void> skip(AppRelease release) async =>
      (await SharedPreferences.getInstance()).setString(_skipKey, release.tag);

  Future<File> download(AppRelease release) async {
    final dir = '${(await info())['dir'] ?? ''}';
    if (dir.isEmpty) throw StateError('Güncelleme klasörü yok');
    final target = File('$dir/B_music-${release.build}.apk');
    if (await target.exists() && (release.size == 0 || await target.length() == release.size)) {
      return downloaded = target;
    }
    final part = File('${target.path}.part');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client.getUrl(Uri.parse(release.apkUrl));
      final response = await request.close();
      if (response.statusCode != 200) throw HttpException('HTTP ${response.statusCode}');
      final total = response.contentLength > 0 ? response.contentLength : release.size;
      var received = 0;
      final sink = part.openWrite();
      try {
        await for (final chunk in response) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) { progress = received / total; notifyListeners(); }
        }
      } finally {
        await sink.close();
      }
      if (total > 0 && received != total) throw const HttpException('İndirme yarım kaldı');
      await part.rename(target.path);
      return downloaded = target;
    } finally {
      client.close(force: true);
      progress = null;
      notifyListeners();
    }
  }

  /// "installer" (system installer opened) or "permission" (settings opened).
  Future<String> install(File apk) async =>
      await DeviceControls.installUpdate(apk.path) ?? 'installer';
}
