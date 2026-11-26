import 'dart:convert';

class SemVer implements Comparable<SemVer> {
  const SemVer(this.major, this.minor, this.patch);

  final int major;
  final int minor;
  final int patch;

  /// Parses strings like `2.4.0`, `v2.4.0`, or `v2.4.0+4`.
  static SemVer? tryParse(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return null;
    if (s.startsWith('v') || s.startsWith('V')) {
      s = s.substring(1);
    }
    final plusIdx = s.indexOf('+');
    if (plusIdx != -1) {
      s = s.substring(0, plusIdx);
    }
    final dashIdx = s.indexOf('-');
    if (dashIdx != -1) {
      s = s.substring(0, dashIdx);
    }
    final parts = s.split('.');
    if (parts.length != 3) return null;
    final maj = int.tryParse(parts[0]);
    final min = int.tryParse(parts[1]);
    final pat = int.tryParse(parts[2]);
    if (maj == null || min == null || pat == null) return null;
    if (maj < 0 || min < 0 || pat < 0) return null;
    return SemVer(maj, min, pat);
  }

  @override
  int compareTo(SemVer other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  bool isNewerThan(SemVer other) => compareTo(other) > 0;

  @override
  String toString() => '$major.$minor.$patch';
}

class AppReleaseInfo {
  const AppReleaseInfo({
    required this.tagName,
    required this.version,
    required this.downloadUrl,
    required this.isDirectApk,
    this.releaseNotes,
  });

  final String tagName;
  final SemVer version;
  final String downloadUrl;
  final bool isDirectApk;
  final String? releaseNotes;

  bool isNewerThan(String installedVersion) {
    final installed = SemVer.tryParse(installedVersion);
    if (installed == null) return false;
    return version.isNewerThan(installed);
  }
}

class AppUpdateParser {
  static AppReleaseInfo? parseLatestRelease(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map<String, dynamic>) return null;

      if (decoded['draft'] == true || decoded['prerelease'] == true) {
        return null;
      }

      final tagName = decoded['tag_name']?.toString().trim() ?? '';
      final version = SemVer.tryParse(tagName);
      if (version == null) return null;

      String? apkUrl;
      final assets = decoded['assets'];
      if (assets is List) {
        for (final item in assets) {
          if (item is! Map) continue;
          final name = item['name']?.toString().toLowerCase() ?? '';
          final url = item['browser_download_url']?.toString().trim() ?? '';
          if (name.endsWith('.apk') && url.isNotEmpty) {
            apkUrl = url;
            break;
          }
        }
      }

      final htmlUrl = decoded['html_url']?.toString().trim() ?? '';
      final downloadUrl = apkUrl ?? htmlUrl;
      if (downloadUrl.isEmpty) return null;

      final body = decoded['body']?.toString().trim();

      return AppReleaseInfo(
        tagName: tagName,
        version: version,
        downloadUrl: downloadUrl,
        isDirectApk: apkUrl != null,
        releaseNotes: (body != null && body.isNotEmpty) ? body : null,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Converts raw GitHub Release markdown bodies into clean, readable lines
/// without requiring a full Markdown rendering package.
class ReleaseNotesFormatter {
  static final RegExp _leadingMarkers = RegExp(r'^(?:#+\s*|[-*•]\s*)');
  static final RegExp _markdownLinks = RegExp(r'\[([^\]]+)\]\([^)]+\)');
  static final RegExp _bareUrl = RegExp(r'^https?://\S+$');

  static List<String> extractLines(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    final result = <String>[];
    for (final rawLine in raw.split('\n')) {
      var line = rawLine.trim();
      if (line.isEmpty) continue;
      if (_bareUrl.hasMatch(line)) continue;
      line = line.replaceFirst(_leadingMarkers, '').trim();
      if (line.isEmpty) continue;
      line = line.replaceAllMapped(_markdownLinks, (m) => m.group(1) ?? '');
      line = line.replaceAll('**', '').replaceAll('__', '').replaceAll('`', '');
      line = line.trim();
      if (line.isEmpty || _bareUrl.hasMatch(line)) continue;
      result.add(line);
    }
    return result;
  }
}
