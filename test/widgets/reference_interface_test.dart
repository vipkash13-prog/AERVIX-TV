import 'dart:convert';
import 'dart:io';
import 'package:flauncher/l10n/app_localizations.dart';
import 'package:flauncher/models/app.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/aervix_home.dart';
import 'package:flauncher/widgets/reference_chrome.dart';
import 'package:flauncher/widgets/reference_dock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import '../mocks.mocks.dart';
import '../xtream/sports_guide_test.dart' show SportsFixture;
import 'package:flauncher/xtream/xtream_service.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
    final font = FontLoader('Cairo')
      ..addFont(rootBundle.load('assets/fonts/Cairo.ttf'));
    await font.load();
    if (Platform.environment['AERVIX_CAPTURE'] == '1') {
      final icons = FontLoader('MaterialIcons')
        ..addFont(
          Future.value(
            ByteData.sublistView(
              File(
                '/tmp/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
              ).readAsBytesSync(),
            ),
          ),
        );
      await icons.load();
    }
  });
  const assets = [
    'apple_tv',
    'nuvio_tv',
    'stremio',
    'shahid',
    'vlc',
    'aiostreams',
    'movieboxpro',
    'mx_player',
  ];
  const names = [
    'Apple TV',
    'Nuvio TV',
    'Stremio',
    'Shahid',
    'VLC',
    'AIOStreams',
    'MovieBoxPro',
    'MX Player',
  ];
  for (final width in [1280, 1920, 3840]) {
    testWidgets('Reference geometry, live values and RTL at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width.toDouble(), width * 9 / 16);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final sports = SportsFixture(now: DateTime.utc(2026, 11, 11, 16, 36));
      await sports.init();
      addTearDown(sports.service.dispose);
      final service = MockAppsService();
      final settings = MockSettingsService();
      when(settings.appHighlightAnimationEnabled).thenReturn(true);
      final apps = List.generate(
        names.length,
        (i) => App(
          packageName: 'fixture.${assets[i]}',
          name: names[i],
          version: '1',
          hidden: false,
        ),
      );
      when(service.initialized).thenReturn(true);
      when(service.applications).thenReturn(apps);
      when(service.categories).thenReturn([]);
      for (var i = 0; i < apps.length; i++) {
        final bytes = File(
          'assets/app_logos/${assets[i]}.png',
        ).readAsBytesSync();
        when(
          service.getAppIcon(apps[i].packageName),
        ).thenAnswer((_) async => bytes);
        when(service.launchApp(apps[i])).thenAnswer((_) async {});
      }
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode(
            request.url.host == 'api.open-meteo.com'
                ? {
                    'current': {
                      'temperature_2m': 26.7,
                      'relative_humidity_2m': 58,
                      'wind_speed_10m': 12,
                      'weather_code': 2,
                      'is_day': 1,
                    },
                    'daily': {
                      'temperature_2m_max': [31],
                      'temperature_2m_min': [24],
                    },
                  }
                : {
                    'data': {
                      'date': {
                        'hijri': {
                          'day': '1',
                          'month': {
                            'ar': 'جمادى الآخرة',
                            'en': 'Jumada al-Akhirah',
                          },
                          'year': '1448',
                        },
                      },
                      'timings': {
                        'Fajr': '05:11',
                        'Sunrise': '06:30',
                        'Dhuhr': '12:13',
                        'Asr': '15:30',
                        'Maghrib': '18:04',
                        'Isha': '19:34',
                      },
                    },
                  },
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<XtreamService>.value(value: sports.service),
            ChangeNotifierProvider<AppsService>.value(value: service),
            ChangeNotifierProvider<SettingsService>.value(value: settings),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: const Locale('ar'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: ThemeData.dark().copyWith(
              textTheme: Typography.material2021().white.apply(
                fontFamily: 'Cairo',
              ),
            ),
            home: AervixHome(
              client: client,
              clock: () => DateTime.utc(2026, 11, 11, 16, 36),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final expected = <String, Rect>{
        'sports': ReferenceLayout.sports,
        'apps': ReferenceLayout.apps,
        'sports-panel': ReferenceLayout.sportsPanel,
        'movies': ReferenceLayout.movies,
        'series': ReferenceLayout.series,
        'live': ReferenceLayout.live,
        'weather': ReferenceLayout.weather,
        'prayer': ReferenceLayout.prayer,
        'clock': ReferenceLayout.clock,
        'applications-band': ReferenceLayout.dock,
      };
      for (final entry in expected.entries) {
        final actual = tester.getRect(
          find.byKey(
            ValueKey(
              entry.key == 'applications-band'
                  ? entry.key
                  : 'reference-${entry.key}',
            ),
          ),
        );
        final target = Rect.fromLTWH(
          entry.value.left * width / 1280,
          entry.value.top * width / 1280,
          entry.value.width * width / 1280,
          entry.value.height * width / 1280,
        );
        expect(
          (actual.topLeft - target.topLeft).distance,
          lessThan(.1),
          reason: entry.key,
        );
        expect(
          (actual.bottomRight - target.bottomRight).distance,
          lessThan(.1),
          reason: entry.key,
        );
      }
      for (final id in ['movies', 'series', 'live'])
        expect(find.byKey(ValueKey('reference-$id')), findsOneWidget);
      expect(find.text('الألعاب'), findsNothing);
      expect(find.byKey(const ValueKey('reference-sidebar')), findsNothing);
      expect(find.text('AERVIX TV'), findsOneWidget);
      expect(find.byType(ReferenceDock), findsOneWidget);
      expect(find.text('26.7°C'), findsOneWidget);
      expect(find.text('05:11'), findsOneWidget);
      expect(find.text('07:36'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.text('مواقيت الصلاة - جدة'))),
        TextDirection.rtl,
      );
      expect(tester.takeException(), isNull);
      if (Platform.environment['AERVIX_CAPTURE'] == '1') {
        final context = tester.element(find.byType(AervixHome));
        await tester.runAsync(() async {
          final images = <ImageProvider>[
            ResizeImage.resizeIfNeeded(
              width >= 3000 ? 3840 : 1920,
              null,
              AssetImage(ReferenceLayout.wallpaper(width.toDouble())),
            ),
            for (final name in ['movies', 'series', 'live'])
              ResizeImage.resizeIfNeeded(
                width >= 3000 ? 1024 : 512,
                null,
                AssetImage('assets/reference_ui/${name}_art.png'),
              ),
            const AssetImage('assets/branding/logo_aervix.png'),
            const AssetImage('assets/prayer/icon_mosque.png'),
            const AssetImage('assets/weather/weather_partly_cloudy.png'),
            for (final asset in assets)
              ResizeImage.resizeIfNeeded(
                512,
                null,
                MemoryImage(
                  File('assets/app_logos/$asset.png').readAsBytesSync(),
                ),
              ),
          ];
          await Future.wait(
            images.map((image) => precacheImage(image, context)),
          );
          await Future<void>.delayed(const Duration(milliseconds: 400));
        });
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(AervixHome),
          matchesGoldenFile(
            '../../design_preview/reference_2026_11_13/interface_$width.png',
          ),
        );
      }
      if (width == 1280) {
        Future<void> key(LogicalKeyboardKey key) async {
          await tester.sendKeyEvent(key);
          await tester.pumpAndSettle();
        }

        expect(FocusManager.instance.primaryFocus?.debugLabel, 'navigation-2');
        for (var i = 0; i < 5; i++) await key(LogicalKeyboardKey.arrowDown);
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'dock-last');
        for (var i = 0; i < 6; i++) await key(LogicalKeyboardKey.arrowLeft);
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'dock-first');
        await key(LogicalKeyboardKey.arrowLeft);
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'all-apps');
        await key(LogicalKeyboardKey.select);
        expect(find.text('جميع التطبيقات'), findsOneWidget);
        await tester.tap(find.text('MX Player'));
        await tester.pumpAndSettle();
        verify(service.launchApp(apps.last)).called(1);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await key(LogicalKeyboardKey.arrowRight);
        await key(LogicalKeyboardKey.arrowUp);
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'header-9');
        await key(LogicalKeyboardKey.arrowUp);
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'header-7');
        for (var i = 0; i < 6; i++) await key(LogicalKeyboardKey.arrowRight);
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'header-7');
        await tester.tap(find.byKey(const ValueKey('reference-weather')));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('غائم جزئيًا'),
          ),
          findsOneWidget,
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('reference-prayer')));
        await tester.pumpAndSettle();
        expect(find.text('الشروق'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        final calls = <MethodCall>[];
        const channel = MethodChannel('me.efesser.flauncher/method');
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (call) async {
            calls.add(call);
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          ),
        );
        for (final index in [3, 4, 6]) {
          final node = tester
              .widgetList<Focus>(find.byType(Focus))
              .map((f) => f.focusNode)
              .whereType<FocusNode>()
              .firstWhere((n) => n.debugLabel == 'header-$index');
          node.requestFocus();
          await tester.pumpAndSettle();
          await key(LogicalKeyboardKey.enter);
          if (index == 6) {
            await tester.tap(find.text('إعدادات الوقت والتاريخ'));
            await tester.pumpAndSettle();
          }
        }
        expect(calls.map((c) => c.method), contains('openWifiSettings'));
        expect(
          calls
              .where((c) => c.method == 'launchActivityFromAction')
              .map((c) => c.arguments),
          containsAll([
            'android.settings.BLUETOOTH_SETTINGS',
            'android.settings.DATE_SETTINGS',
          ]),
        );
        await key(LogicalKeyboardKey.escape);
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'navigation-2');
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}
