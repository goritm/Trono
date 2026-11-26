import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_update.dart';
import 'settings_service.dart';

enum UpdateCheckStatus {
  updateAvailable,
  upToDate,
  throttled,
  failed,
}

class UpdateCheckResult {
  const UpdateCheckResult({
    required this.status,
    this.release,
    this.installedVersion,
  });

  final UpdateCheckStatus status;
  final AppReleaseInfo? release;
  final String? installedVersion;

  bool get hasUpdate =>
      status == UpdateCheckStatus.updateAvailable && release != null;
}

typedef HttpGetFn = Future<String?> Function(Uri uri);
typedef VersionProviderFn = Future<String> Function();
typedef NowProviderFn = DateTime Function();

/// Anonymous, read-only GitHub Releases checker for Trono APK updates.
/// Zero user data is ever sent; automatic checks are throttled to once per 12h.
class UpdateCheckerService {
  UpdateCheckerService({
    required SettingsService settings,
    VersionProviderFn? currentVersionProvider,
    HttpGetFn? httpGet,
    NowProviderFn? nowProvider,
  }) : _settings = settings,
       _versionProvider = currentVersionProvider ?? _defaultVersionProvider,
       _httpGet = httpGet ?? _defaultHttpGet,
       _nowProvider = nowProvider ?? DateTime.now;

  static final Uri latestReleaseUri = Uri.parse(
    'https://api.github.com/repos/goritm/Trono/releases/latest',
  );
  static const Duration autoCheckThrottle = Duration(hours: 12);

  final SettingsService _settings;
  final VersionProviderFn _versionProvider;
  final HttpGetFn _httpGet;
  final NowProviderFn _nowProvider;

  Future<String> getInstalledVersion() => _versionProvider();

  bool shouldShowHomeBanner(AppReleaseInfo? release) {
    if (release == null) return false;
    return _settings.dismissedUpdateTag != release.tagName;
  }

  Future<void> dismissRelease(String tagName) async {
    await _settings.setDismissedUpdateTag(tagName);
  }

  Future<UpdateCheckResult> checkForUpdate({bool force = false}) async {
    final now = _nowProvider();
    if (!force) {
      final lastChecked = _settings.updateLastCheckedAt;
      if (lastChecked != null &&
          now.difference(lastChecked) < autoCheckThrottle) {
        return const UpdateCheckResult(status: UpdateCheckStatus.throttled);
      }
    }

    try {
      final installed = await _versionProvider();
      final body = await _httpGet(latestReleaseUri);
      if (body == null || body.isEmpty) {
        return UpdateCheckResult(
          status: UpdateCheckStatus.failed,
          installedVersion: installed,
        );
      }

      await _settings.setUpdateLastCheckedAt(now);
      final latest = AppUpdateParser.parseLatestRelease(body);
      if (latest == null) {
        return UpdateCheckResult(
          status: UpdateCheckStatus.upToDate,
          installedVersion: installed,
        );
      }

      if (latest.isNewerThan(installed)) {
        return UpdateCheckResult(
          status: UpdateCheckStatus.updateAvailable,
          release: latest,
          installedVersion: installed,
        );
      }

      return UpdateCheckResult(
        status: UpdateCheckStatus.upToDate,
        installedVersion: installed,
      );
    } catch (_) {
      return const UpdateCheckResult(status: UpdateCheckStatus.failed);
    }
  }

  static Future<bool> openDownload(AppReleaseInfo release) async {
    final uri = Uri.tryParse(release.downloadUrl);
    if (uri == null) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  static Future<String> _defaultVersionProvider() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (_) {
      return '2.4.0';
    }
  }

  static Future<String?> _defaultHttpGet(Uri uri) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 5);
    try {
      final req = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 5));
      req.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      req.headers.set(HttpHeaders.userAgentHeader, 'Trono-App');
      final res = await req.close().timeout(const Duration(seconds: 5));
      if (res.statusCode != HttpStatus.ok) return null;
      return await res.transform(utf8.decoder).join().timeout(
        const Duration(seconds: 5),
      );
    } finally {
      client.close(force: true);
    }
  }
}
