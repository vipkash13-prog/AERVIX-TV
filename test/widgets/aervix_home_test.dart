import 'dart:convert';
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
  setUpAll(() => initializeDateFormatting('ar'));

  test('next prayer uses Riyadh time and rolls over after Isha', () {
    final timings = <String, dynamic>{
      'Fajr': '05:09',
      'Sunrise': '06:33',
      'Dhuhr': '12:08',
      'Asr': '15:32',
      'Maghrib': '17:43',
      'Isha': '19:13',
    };
    expect(nextPrayerKey(timings, DateTime.utc(2026, 11, 11, 1)), 'Fajr');
    expect(nextPrayerKey(timings, DateTime.utc(2026, 11, 11, 3)), 'Dhuhr');
    expect(nextPrayerKey(timings, DateTime.utc(2026, 11, 11, 13)), 'Maghrib');
    expect(nextPrayerKey(timings, DateTime.utc(2026, 11, 11, 20)), 'Fajr');
    expect(nextPrayerKey({}, DateTime.utc(2026)), isNull);
  });

  testWidgets('RTL remote arrows, OK and repeated presses remain responsive', (
    tester,
  ) async {
    var first = 0;
    var second = 0;
    await tester.pumpWidget(
      MaterialApp(
        shortcuts: {
          ...WidgetsApp.defaultShortcuts,
          SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        },
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Row(
              children: [
                SizedBox(
                  width: 150,
                  height: 150,
                  child: GoldFocusTile(
                    autofocus: true,
                    label: 'الأول',
                    onPressed: () => first++,
                    child: const Icon(Icons.apps),
                  ),
                ),
                SizedBox(
                  width: 150,
                  height: 150,
                  child: GoldFocusTile(
                    label: 'الثاني',
                    onPressed: () => second++,
                    child: const Icon(Icons.star),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    expect(first, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(second, 1);
    for (var i = 0; i < 20; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    }
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    expect(second, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'real app model launches, live data renders, app dialog returns',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = MockAppsService();
      final app = App(
        packageName: 'installed.example',
        name: 'Installed TV',
        version: '1',
        hidden: false,
      );
      when(service.initialized).thenReturn(true);
      when(service.applications).thenReturn([app]);
      when(service.categories).thenReturn([]);
      when(service.getAppIcon(any)).thenAnswer((_) async => Uint8List(0));
      when(service.launchApp(app)).thenAnswer((_) async {});
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode(
            request.url.host == 'api.open-meteo.com'
                ? {
                    'current': {
                      'temperature_2m': 28,
                      'relative_humidity_2m': 62,
                      'wind_speed_10m': 18,
                      'weather_code': 2,
                    },
                  }
                : {
                    'data': {
                      'timings': {
                        'Fajr': '05:09',
                        'Sunrise': '06:33',
                        'Dhuhr': '12:08',
                        'Asr': '15:32',
                        'Maghrib': '17:43',
                        'Isha': '19:13',
                      },
                    },
                  },
          ),
          200,
        ),
      );
      await tester.pumpWidget(
        ChangeNotifierProvider<AppsService>.value(
          value: service,
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: AervixHome(client: client),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('28°C'), findsOneWidget);
      expect(find.text('05:09'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('dock-installed.example')));
      await tester.pumpAndSettle();
      verify(service.launchApp(app)).called(1);
      await tester.tap(find.byKey(const ValueKey('navigation-5')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('network failure shows status without fabricated readings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(3840, 2160);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = MockAppsService();
    when(service.initialized).thenReturn(true);
    when(service.applications).thenReturn([]);
    when(service.categories).thenReturn([]);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppsService>.value(
        value: service,
        child: MaterialApp(
          home: AervixHome(
            client: MockClient((_) async => http.Response('unavailable', 503)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reference-weather')));
    await tester.pumpAndSettle();
    expect(find.text('تعذر تحديث الطقس'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reference-prayer')));
    await tester.pumpAndSettle();
    expect(find.text('تعذر تحديث المواقيت'), findsOneWidget);
    expect(find.text('28°C'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'large TV text keeps weather and prayers above the application row',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = MockAppsService();
      when(service.initialized).thenReturn(true);
      when(service.applications).thenReturn([]);
      when(service.categories).thenReturn([]);
      final client = MockClient((_) async => http.Response('unavailable', 503));
      await tester.pumpWidget(
        ChangeNotifierProvider<AppsService>.value(
          value: service,
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: AervixHome(client: client),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final rowTop = tester
          .getTopLeft(find.byKey(const ValueKey('applications-band')))
          .dy;
      expect(
        tester
            .getBottomLeft(find.byKey(const ValueKey('reference-weather')))
            .dy,
        lessThan(rowTop),
      );
      expect(tester.getBottomLeft(find.text('العشاء')).dy, lessThan(rowTop));
      expect(
        tester
            .getBottomLeft(find.byKey(const ValueKey('reference-weather')))
            .dy,
        lessThan(rowTop),
      );
      expect(
        tester.getBottomLeft(find.byKey(const ValueKey('reference-prayer'))).dy,
        lessThan(rowTop),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
