import 'dart:convert';
import 'dart:io';

import 'package:flauncher/flauncher_channel.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class UpdateResult {
  final bool updateAvailable;
  final String currentVersion;
  final String latestVersion;
  final String? releaseNotes;
  final String? apkUrl;
  final String? apkName;

  const UpdateResult({
    required this.updateAvailable,
    required this.currentVersion,
    required this.latestVersion,
    this.releaseNotes,
    this.apkUrl,
    this.apkName,
  });
}

class DownloadedApk {
  final String path;
  final String version;

  const DownloadedApk({required this.path, required this.version});
}

/// ABI-split APKs are named like `arclauncher-1.0.5-arm64-v8a.apk`.
/// Universal builds omit the ABI suffix (`arclauncher-1.0.5.apk`).
bool isAbiSplitApk(String name) {
  return RegExp(
    r"-(arm64-v8a|armeabi-v7a|armeabi|x86_64|x86)\.apk$",
    caseSensitive: false,
  ).hasMatch(name);
}

/// Prefers a universal APK asset; falls back to the first APK if none match.
({String name, String url})? pickReleaseApk(List<dynamic> assets) {
  String? fallbackName;
  String? fallbackUrl;

  for (final asset in assets) {
    if (asset is! Map) {
      continue;
    }

    final name = asset["name"];
    final downloadUrl = asset["browser_download_url"];
    if (name is! String || downloadUrl is! String) {
      continue;
    }
    if (!name.toLowerCase().endsWith(".apk")) {
      continue;
    }

    if (isAbiSplitApk(name)) {
      fallbackName ??= name;
      fallbackUrl ??= downloadUrl;
      continue;
    }

    return (name: name, url: downloadUrl);
  }

  if (fallbackName != null && fallbackUrl != null) {
    return (name: fallbackName, url: fallbackUrl);
  }
  return null;
}

/// Cleans and sanitizes release notes from a GitHub release body:
/// - Strips automated VirusTotal analysis tables and report comments
/// - Shortens GitHub PR and issue URLs to concise references (e.g. #42)
/// - Removes redundant "Full Changelog" URLs
String? cleanReleaseNotes(String? notes) {
  if (notes == null) {
    return null;
  }

  var text = notes;

  final vtIndex = text.indexOf("<!-- virustotal-report -->");
  if (vtIndex != -1) {
    text = text.substring(0, vtIndex);
  }

  final vtHeaderIndex = text.indexOf(
    RegExp(r"^##\s*VirusTotal", multiLine: true),
  );
  if (vtHeaderIndex != -1) {
    text = text.substring(0, vtHeaderIndex);
  }

  // Remove "Full Changelog: https://..." lines
  text = text.replaceAll(
    RegExp(
      r"^\s*\*?\*?Full Changelog\*?\*?:?.*$",
      multiLine: true,
      caseSensitive: false,
    ),
    "",
  );

  // Shorten PR and issue links
  text = text.replaceAllMapped(
    RegExp(r"in https://github\.com/[^/\s]+/[^/\s]+/pull/(\d+)"),
    (m) => "(#${m[1]})",
  );
  text = text.replaceAllMapped(
    RegExp(r"https://github\.com/[^/\s]+/[^/\s]+/(?:issues|pull)/(\d+)"),
    (m) => "#${m[1]}",
  );

  text = text.trim();
  return text.isEmpty ? null : text;
}

class UpdateService {
  static const String _owner = "vipkash13-prog";
  static const String _repo = "AERVIX-TV";
  final FLauncherChannel _fLauncherChannel;
  final http.Client? _client;

  UpdateService({FLauncherChannel? fLauncherChannel, http.Client? client})
    : _client = client,
      _fLauncherChannel = fLauncherChannel ?? FLauncherChannel();

  Future<UpdateResult> checkForUpdate() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;
    final release = await _fetchLatestStableRelease();

    final latestVersion = _normalizeVersion(release.tagName);
    final updateAvailable = _compareVersions(latestVersion, currentVersion) > 0;

    return UpdateResult(
      updateAvailable: updateAvailable,
      currentVersion: currentVersion,
      latestVersion: latestVersion,
      releaseNotes: cleanReleaseNotes(release.body),
      apkUrl: release.apkDownloadUrl,
      apkName: release.apkName,
    );
  }

  Future<DownloadedApk> downloadApk(UpdateResult update) async {
    if (!update.updateAvailable || update.apkUrl == null) {
      throw StateError("No update APK available to download.");
    }

    final uri = Uri.parse(update.apkUrl!);
    if (uri.scheme != 'https' ||
        uri.host != 'github.com' ||
        !uri.path.startsWith('/$_owner/$_repo/releases/download/') ||
        !uri.path.toLowerCase().endsWith('.apk')) {
      throw StateError('The APK must be a direct AERVIX-TV release asset.');
    }
    final client = _client ?? http.Client();
    File? partial;
    try {
      final response = await client
          .send(
            http.Request('GET', uri)
              ..headers['User-Agent'] = 'AERVIX-TV-Updater',
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200)
        throw HttpException('APK download failed: ${response.statusCode}');
      final directory = await getApplicationSupportDirectory();
      final updatesDirectory = Directory('${directory.path}/updates');
      await updatesDirectory.create(recursive: true);
      final fileName =
          update.apkName ?? 'AERVIX-TV-${update.latestVersion}.apk';
      if (!RegExp(r'^[a-zA-Z0-9._-]+\.apk$').hasMatch(fileName))
        throw const FormatException('Invalid APK name');
      partial = File('${updatesDirectory.path}/$fileName.part');
      await response.stream
          .timeout(const Duration(seconds: 30))
          .pipe(partial.openWrite());
      final file = await partial.rename('${updatesDirectory.path}/$fileName');
      return DownloadedApk(path: file.path, version: update.latestVersion);
    } catch (_) {
      if (partial != null && await partial.exists()) await partial.delete();
      rethrow;
    } finally {
      if (_client == null) client.close();
    }
  }

  Future<bool> installApk(String apkPath) {
    return _fLauncherChannel.installApk(apkPath);
  }

  Future<void> requestInstallUnknownAppsPermission() {
    return _fLauncherChannel.requestInstallUnknownAppsPermission();
  }

  Future<_GitHubRelease> _fetchLatestStableRelease() async {
    final uri = Uri.parse(
      "https://api.github.com/repos/$_owner/$_repo/releases",
    );
    final client = _client ?? http.Client();
    try {
      final response = await client
          .get(
            uri,
            headers: {
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'AERVIX-TV-Updater',
            },
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200)
        throw HttpException(
          'Release check failed: ${response.statusCode}',
          uri: uri,
        );
      final body = response.body;
      final parsed = jsonDecode(body);
      if (parsed is! List) {
        throw const FormatException("Unexpected releases response format.");
      }

      for (final releaseData in parsed) {
        if (releaseData is! Map<String, dynamic>) {
          continue;
        }
        if ((releaseData["draft"] as bool?) ?? false) {
          continue;
        }
        if ((releaseData["prerelease"] as bool?) ?? false) {
          continue;
        }

        final tagName = releaseData["tag_name"] as String?;
        final releaseBody = releaseData["body"] as String?;
        final assets = releaseData["assets"];
        if (tagName == null || assets is! List) {
          continue;
        }

        final apk = pickReleaseApk(assets);
        if (apk == null) {
          continue;
        }

        return _GitHubRelease(
          tagName: tagName,
          body: releaseBody,
          apkName: apk.name,
          apkDownloadUrl: apk.url,
        );
      }

      throw StateError("No stable release with an APK asset was found.");
    } finally {
      if (_client == null) client.close();
    }
  }

  String _normalizeVersion(String version) {
    var normalized = version.trim();
    if (normalized.startsWith("v") || normalized.startsWith("V")) {
      normalized = normalized.substring(1);
    }
    return normalized.split('+').first;
  }

  int _compareVersions(String left, String right) {
    final leftParts = _versionParts(left);
    final rightParts = _versionParts(right);
    final maxLength = leftParts.length > rightParts.length
        ? leftParts.length
        : rightParts.length;
    for (var i = 0; i < maxLength; i++) {
      final leftValue = i < leftParts.length ? leftParts[i] : 0;
      final rightValue = i < rightParts.length ? rightParts[i] : 0;
      if (leftValue != rightValue) {
        return leftValue.compareTo(rightValue);
      }
    }
    return 0;
  }

  List<int> _versionParts(String version) {
    return _normalizeVersion(version)
        .split(".")
        .map(
          (part) => int.tryParse(part.replaceAll(RegExp(r"[^0-9]"), "")) ?? 0,
        )
        .toList();
  }
}

class _GitHubRelease {
  final String tagName;
  final String? body;
  final String apkName;
  final String apkDownloadUrl;

  const _GitHubRelease({
    required this.tagName,
    required this.body,
    required this.apkName,
    required this.apkDownloadUrl,
  });
}
