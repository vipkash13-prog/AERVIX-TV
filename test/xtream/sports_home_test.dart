import 'package:flauncher/models/app.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/widgets/aervix_home.dart';
import 'package:flauncher/xtream/browser_page.dart';
import 'package:flauncher/xtream/player_page.dart';
import 'package:flauncher/xtream/xtream_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import '../mocks.mocks.dart';
import 'sports_guide_test.dart' show SportsFixture;
import 'playback_test.dart' show FakeVideoPlatform, frames;

void main() {
  testWidgets(
    'sports panel plays real subscription channel; menu filters sports; header search reaches input',
    (tester) async {
      await initializeDateFormatting('ar');
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final platform = FakeVideoPlatform();
      VideoPlayerPlatform.instance = platform;
      final fixture = SportsFixture();
      await fixture.init();
      addTearDown(fixture.service.dispose);
      final apps = MockAppsService();
      when(apps.initialized).thenReturn(true);
      when(apps.applications).thenReturn(<App>[]);
      when(apps.categories).thenReturn([]);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppsService>.value(value: apps),
            ChangeNotifierProvider<XtreamService>.value(value: fixture.service),
          ],
          child: MaterialApp(
            home: AervixHome(
              clock: () => fixture.now,
              client: MockClient((_) async => http.Response('', 503)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('دوري: الهلال ضد النصر'), findsOneWidget);
      await tester.tap(find.text('دوري: الهلال ضد النصر'));
      await frames(tester);
      expect(find.byType(XtreamPlayerPage), findsOneWidget);
      expect(platform.sources.values.last.uri, endsWith('/1.ts'));
      expect(platform.maxAlive, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await frames(tester);
      await tester.tap(find.byKey(const ValueKey('navigation-0')));
      await tester.pumpAndSettle();
      expect(find.text('القنوات الرياضية'), findsOneWidget);
      expect(find.text('Adult XXX'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('status-7')));
      await tester.pumpAndSettle();
      expect(find.text('البحث في الاشتراك'), findsOneWidget);
      await tester.tap(find.text('الأفلام').last);
      await tester.pumpAndSettle();
      expect(find.byType(XtreamBrowserPage), findsOneWidget);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'xtream-search');
      await tester.pumpWidget(const SizedBox());
      await frames(tester);
      expect(tester.takeException(), isNull);
    },
  );
}
