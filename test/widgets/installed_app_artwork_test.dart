import 'dart:io';
import 'package:flauncher/models/app.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/widgets/installed_app_icon.dart';
import 'package:flauncher/widgets/reference_dock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import '../mocks.mocks.dart';

void main() {
  final banner = File('assets/reference_ui/movies_art.png').readAsBytesSync();
  final icon = File('assets/app_logos/apple_tv.png').readAsBytesSync();
  App app(String id) =>
      App(packageName: id, name: id, version: '1', hidden: false);
  testWidgets(
    'TV artwork fills the common dock slot using contain, without an inner icon-sized square',
    (tester) async {
      final service = MockAppsService();
      final installed = app('installed.tv');
      when(
        service.getAppBanner(installed.packageName),
      ).thenAnswer((_) async => banner);
      await tester.pumpWidget(
        ChangeNotifierProvider<AppsService>.value(
          value: service,
          child: MaterialApp(
            home: Center(
              child: SizedBox(
                width: 103,
                height: 70,
                child: InstalledAppIcon(app: installed, preferTvBanner: true),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.fit, BoxFit.contain);
      expect(tester.getSize(find.byType(Image)), const Size(99, 66));
      final source = (image.image as ResizeImage).imageProvider as MemoryImage;
      expect(source.bytes, same(banner));
      verify(service.getAppBanner(installed.packageName)).called(1);
      verifyNever(service.getAppIcon(any));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'missing or failed TV banner uses original icon in the same expanded slot',
    (tester) async {
      final service = MockAppsService();
      final installed = app('installed.phone');
      when(
        service.getAppBanner(installed.packageName),
      ).thenThrow(PlatformException(code: 'no-banner'));
      when(
        service.getAppIcon(installed.packageName),
      ).thenAnswer((_) async => icon);
      Widget build() => ChangeNotifierProvider<AppsService>.value(
        value: service,
        child: MaterialApp(
          home: Center(
            child: SizedBox(
              width: 103,
              height: 70,
              child: InstalledAppIcon(app: installed, preferTvBanner: true),
            ),
          ),
        ),
      );
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(Image)), const Size(99, 66));
      expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.contain);
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();
      verify(service.getAppBanner(installed.packageName)).called(1);
      verify(service.getAppIcon(installed.packageName)).called(1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('seven slots keep equal frame sizes and remote spacing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = MockAppsService();
    final apps = [app('tv.one'), app('phone.two'), app('tv.three')];
    for (final installed in apps) {
      when(
        service.getAppBanner(installed.packageName),
      ).thenAnswer((_) async => installed == apps[1] ? Uint8List(0) : banner);
      when(
        service.getAppIcon(installed.packageName),
      ).thenAnswer((_) async => icon);
    }
    final first = FocusNode(), all = FocusNode();
    addTearDown(first.dispose);
    addTearDown(all.dispose);
    final launched = <App>[];
    await tester.pumpWidget(
      ChangeNotifierProvider<AppsService>.value(
        value: service,
        child: MaterialApp(
          home: Center(
            child: SizedBox(
              width: 1009,
              height: 92,
              child: ReferenceDock(
                apps: apps,
                onLaunch: launched.add,
                onEdit: () {},
                onLeftBoundary: () {},
                onUp: (_) {},
                firstFocus: first,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final frames = [
      for (final installed in apps)
        tester.getRect(find.byKey(ValueKey('dock-${installed.packageName}'))),
    ];
    for (final frame in frames) {
      expect(frame.height, 70);
      expect(frame.width, closeTo((981 - 72) / 7, .001));
    }
    expect(
      frames[1].left - frames[0].left,
      closeTo(frames.first.width + 12, .001),
    );
    expect(
      frames[2].left - frames[1].left,
      closeTo(frames.first.width + 12, .001),
    );
    for (final artwork in tester.widgetList<InstalledAppIcon>(
      find.byType(InstalledAppIcon),
    ))
      expect(artwork.preferTvBanner, isTrue);
    first.requestFocus();
    await tester.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(launched, [apps.last]);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
