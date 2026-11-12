import 'dart:async';
import 'dart:convert';
import 'package:flauncher/models/app.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/home_preferences.dart';
import 'package:flauncher/widgets/aervix_home.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../mocks.mocks.dart';

void main() {
  testWidgets(
    'city switch rejects stale responses; English preserves fixed geometry',
    (tester) async {
      await initializeDateFormatting('ar');
      await initializeDateFormatting('en');
      SharedPreferences.setMockInitialValues({});
      final prefs = HomePreferences(await SharedPreferences.getInstance());
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final apps = MockAppsService();
      when(apps.initialized).thenReturn(true);
      when(apps.applications).thenReturn(<App>[]);
      when(apps.categories).thenReturn([]);
      final pending = <Completer<http.Response>>[];
      final requests = <Uri>[];
      final client = MockClient((request) async {
        requests.add(request.url);
        if (request.url.queryParameters['latitude'] == '21.4858') {
          final c = Completer<http.Response>();
          pending.add(c);
          return c.future;
        }
        return http.Response(
          jsonEncode(
            request.url.host == 'api.open-meteo.com'
                ? {
                    'current': {
                      'temperature_2m': 31,
                      'relative_humidity_2m': 20,
                      'wind_speed_10m': 8,
                      'weather_code': 0,
                    },
                  }
                : {
                    'data': {
                      'timings': {'Fajr': '05:15'},
                      'date': {
                        'hijri': {
                          'day': '2',
                          'month': {'ar': 'جمادى الآخرة'},
                          'year': '1448',
                        },
                      },
                    },
                  },
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppsService>.value(value: apps),
            ChangeNotifierProvider<HomePreferences>.value(value: prefs),
          ],
          child: MaterialApp(home: AervixHome(client: client)),
        ),
      );
      await tester.pump();
      expect(pending.length, 2);
      final before = tester.getRect(
        find.byKey(const ValueKey('reference-movies')),
      );
      await prefs.setCity('riyadh');
      await tester.pump();
      for (final request in pending)
        request.complete(
          http.Response(
            jsonEncode({
              'current': {'temperature_2m': 99, 'weather_code': 0},
              'data': {
                'timings': {'Fajr': '01:00'},
              },
            }),
            200,
          ),
        );
      await tester.pumpAndSettle();
      expect(find.text('99°C'), findsNothing);
      expect(find.text('31°C'), findsOneWidget);
      expect(find.text('الرياض'), findsOneWidget);
      expect(
        requests
            .where((u) => u.queryParameters['latitude'] == '24.7136')
            .length,
        2,
      );
      await prefs.setLanguage('en');
      await tester.pumpAndSettle();
      expect(find.text('Movies'), findsOneWidget);
      expect(find.text('Riyadh'), findsOneWidget);
      expect(find.text('Prayer Times - Riyadh'), findsOneWidget);
      expect(
        tester.getRect(find.byKey(const ValueKey('reference-movies'))),
        before,
      );
      await tester.pumpWidget(const SizedBox());
      prefs.dispose();
      expect(tester.takeException(), isNull);
    },
  );
}
