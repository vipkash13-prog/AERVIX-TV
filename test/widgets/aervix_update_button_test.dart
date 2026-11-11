import 'package:flauncher/providers/update_service.dart';
import 'package:flauncher/widgets/aervix_update_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Updater extends UpdateService {
  int checks = 0;
  int downloads = 0;
  int installs = 0;
  int permissions = 0;
  bool canInstall = true;
  @override
  Future<UpdateResult> checkForUpdate() async {
    checks++;
    return const UpdateResult(
      updateAvailable: true,
      currentVersion: '1.2.3',
      latestVersion: '1.2.4',
    );
  }

  @override
  Future<DownloadedApk> downloadApk(UpdateResult update) async {
    downloads++;
    return const DownloadedApk(
      path: '/private/updates/aervix.apk',
      version: '1.2.4',
    );
  }

  @override
  Future<bool> installApk(String path) async {
    installs++;
    return canInstall;
  }

  @override
  Future<void> requestInstallUnknownAppsPermission() async {
    permissions++;
  }
}

Future<void> _pump(WidgetTester tester, _Updater service) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 100,
          height: 100,
          child: AervixUpdateButton(service: service),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('background check never downloads or installs without consent', (
    tester,
  ) async {
    final service = _Updater();
    await _pump(tester, service);
    expect(service.checks, 1);
    expect(service.downloads, 0);
    expect(service.installs, 0);
    await tester.tap(find.byType(AervixUpdateButton));
    await tester.pumpAndSettle();
    expect(find.text('تنزيل التحديث'), findsOneWidget);
    await tester.sendKeyEvent(
      LogicalKeyboardKey.enter,
    ); // Focus starts on Later.
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(service.downloads, 0);
    expect(service.installs, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('installer opens only after both explicit consent steps', (
    tester,
  ) async {
    final service = _Updater();
    await _pump(tester, service);
    await tester.tap(find.byType(AervixUpdateButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تنزيل التحديث'));
    await tester.pumpAndSettle();
    expect(service.downloads, 1);
    expect(service.installs, 0);
    await tester.tap(find.text('متابعة التثبيت'));
    await tester.pumpAndSettle();
    expect(service.installs, 1);
    expect(service.permissions, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'unknown sources permission requires consent and retains downloaded APK',
    (tester) async {
      final service = _Updater()..canInstall = false;
      await _pump(tester, service);
      await tester.tap(find.byType(AervixUpdateButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تنزيل التحديث'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('متابعة التثبيت'));
      await tester.pumpAndSettle();
      expect(service.permissions, 0);
      await tester.tap(find.text('فتح الإعدادات'));
      await tester.pumpAndSettle();
      expect(service.permissions, 1);
      service.canInstall = true;
      await tester.tap(find.byType(AervixUpdateButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('متابعة التثبيت'));
      await tester.pumpAndSettle();
      expect(service.downloads, 1);
      expect(service.installs, 2);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
