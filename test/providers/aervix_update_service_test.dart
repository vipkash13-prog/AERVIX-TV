import 'dart:convert';
import 'dart:io';
import 'package:flauncher/providers/update_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _Paths extends PathProviderPlatform {
  final String path;
  _Paths(this.path);
  @override
  Future<String?> getApplicationSupportPath() async => path;
}

const _url =
    'https://github.com/vipkash13-prog/AERVIX-TV/releases/download/v1.2.4/AERVIX-TV-1.2.4-armeabi-v7a.apk';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late PathProviderPlatform originalPaths;
  setUp(() async {
    PackageInfo.setMockInitialValues(
      appName: 'AERVIX TV',
      packageName: 'com.omeda.arc',
      version: '1.2.3',
      buildNumber: '5130',
      buildSignature: 'old-key',
    );
    directory = await Directory.systemTemp.createTemp('aervix-updater-test-');
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(directory.path);
  });
  tearDown(() async {
    PathProviderPlatform.instance = originalPaths;
    await directory.delete(recursive: true);
  });

  test(
    'automatic check uses AERVIX repo and ignores drafts, prereleases and ZIP-only releases',
    () async {
      final service = UpdateService(
        client: MockClient((request) async {
          expect(
            request.url.toString(),
            'https://api.github.com/repos/vipkash13-prog/AERVIX-TV/releases',
          );
          return http.Response(
            jsonEncode([
              {'draft': true, 'tag_name': 'v9.0.0', 'assets': []},
              {'prerelease': true, 'tag_name': 'v8.0.0', 'assets': []},
              {
                'tag_name': 'v7.0.0',
                'assets': [
                  {
                    'name': 'bundle.zip',
                    'browser_download_url': 'https://example.com/bundle.zip',
                  },
                ],
              },
              {
                'tag_name': 'v1.2.4',
                'body': 'New release',
                'assets': [
                  {
                    'name': 'AERVIX-TV-1.2.4-armeabi-v7a.apk',
                    'browser_download_url': _url,
                  },
                ],
              },
            ]),
            200,
          );
        }),
      );
      final update = await service.checkForUpdate();
      expect(update.updateAvailable, isTrue);
      expect(update.latestVersion, '1.2.4');
      expect(update.apkUrl, _url);
    },
  );

  test('same version is not offered for reinstall', () async {
    final service = UpdateService(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode([
            {
              'tag_name': 'v1.2.3',
              'assets': [
                {'name': 'AERVIX-TV.apk', 'browser_download_url': _url},
              ],
            },
          ]),
          200,
        ),
      ),
    );
    expect((await service.checkForUpdate()).updateAvailable, isFalse);
  });

  test(
    'download uses a direct APK and atomically replaces its partial file',
    () async {
      final service = UpdateService(
        client: MockClient((request) async {
          expect(request.url.toString(), _url);
          return http.Response.bytes([0x50, 0x4B, 3, 4], 200);
        }),
      );
      final result = await service.downloadApk(
        const UpdateResult(
          updateAvailable: true,
          currentVersion: '1.2.3',
          latestVersion: '1.2.4',
          apkName: 'AERVIX-TV-1.2.4-armeabi-v7a.apk',
          apkUrl: _url,
        ),
      );
      expect(await File(result.path).readAsBytes(), [0x50, 0x4B, 3, 4]);
      expect(await File('${result.path}.part').exists(), isFalse);
    },
  );

  test('rejects APK links outside the AERVIX repository', () async {
    final service = UpdateService();
    await expectLater(
      service.downloadApk(
        const UpdateResult(
          updateAvailable: true,
          currentVersion: '1',
          latestVersion: '2',
          apkUrl: 'https://example.com/other.apk',
        ),
      ),
      throwsStateError,
    );
  });

  test('rejects path traversal in downloaded asset names', () async {
    final service = UpdateService(
      client: MockClient((_) async => http.Response('apk', 200)),
    );
    await expectLater(
      service.downloadApk(
        const UpdateResult(
          updateAvailable: true,
          currentVersion: '1',
          latestVersion: '2',
          apkName: '../escape.apk',
          apkUrl: _url,
        ),
      ),
      throwsFormatException,
    );
    expect(await File('${directory.path}/escape.apk').exists(), isFalse);
  });
}
