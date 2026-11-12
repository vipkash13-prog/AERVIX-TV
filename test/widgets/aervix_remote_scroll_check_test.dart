import 'package:flauncher/models/app.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/widgets/aervix_home.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import '../mocks.mocks.dart';

void main() {
  testWidgets(
    'remote crosses exactly seven favourites and returns without scrolling through installed apps',
    (tester) async {
      await initializeDateFormatting('ar');
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = MockAppsService();
      final apps = List.generate(
        18,
        (index) => App(
          packageName: 'installed.$index',
          name: 'TV ${index.toString().padLeft(2, '0')}',
          version: '1',
          hidden: false,
        ),
      );
      when(service.initialized).thenReturn(true);
      when(service.applications).thenReturn(apps);
      when(service.categories).thenReturn([]);
      when(service.getAppIcon(any)).thenAnswer((_) async => Uint8List(0));
      for (final app in apps) {
        when(service.launchApp(app)).thenAnswer((_) async {});
      }
      await tester.pumpWidget(
        ChangeNotifierProvider<AppsService>.value(
          value: service,
          child: MaterialApp(
            home: AervixHome(
              client: MockClient((_) async => http.Response('', 503)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      for (var i = 0; i < 6; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
      }
      expect(find.byKey(const ValueKey('dock-installed.7')), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      verify(service.launchApp(apps[6])).called(1);
      for (var i = 0; i < 6; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      verify(service.launchApp(apps.first)).called(1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
