import 'package:flauncher/models/app.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/widgets/aervix_home.dart';
import 'package:flauncher/xtream/browser_page.dart';
import 'package:flauncher/xtream/xtream_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import '../mocks.mocks.dart';
import 'fixtures.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ar'));
  Future<void> home(WidgetTester tester, CatalogueFixture f) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final apps = MockAppsService();
    when(apps.initialized).thenReturn(true);
    when(apps.applications).thenReturn(<App>[]);
    when(apps.categories).thenReturn([]);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppsService>.value(value: apps),
          ChangeNotifierProvider<XtreamService>.value(value: f.service),
        ],
        child: MaterialApp(
          home: AervixHome(
            client: MockClient((_) async => http.Response('', 503)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'sidebar media items open internal catalogues without duplicated home cards',
    (tester) async {
      final f = CatalogueFixture();
      await f.init();
      addTearDown(f.service.dispose);
      await home(tester, f);
      for (final name in [2, 3, 1]) {
        await tester.tap(find.byKey(ValueKey('navigation-$name')));
        await tester.pumpAndSettle();
        expect(find.byType(XtreamBrowserPage), findsOneWidget);
        expect(find.text('Adult XXX'), findsNothing);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
      }
      expect(
        f.actions,
        containsAll([
          'get_vod_categories',
          'get_vod_streams',
          'get_series_categories',
          'get_series',
          'get_live_categories',
          'get_live_streams',
        ]),
      );
      expect(find.byKey(const ValueKey('reference-sidebar')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('without an account, sidebar media opens setup', (tester) async {
    final f = CatalogueFixture();
    await f.init(emptyAccount: true);
    addTearDown(f.service.dispose);
    await home(tester, f);
    await tester.tap(find.byKey(const ValueKey('navigation-1')));
    await tester.pumpAndSettle();
    expect(find.text('اشتراك Xtream Codes'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(3));
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(find.byType(XtreamBrowserPage), findsNothing);
    expect(f.actions, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });
}
