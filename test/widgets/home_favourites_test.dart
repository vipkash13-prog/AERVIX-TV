import 'package:flauncher/models/app.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/dock_favourites.dart';
import 'package:flauncher/widgets/aervix_home.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    'seven favourites integrate with the home remote editor and survive restart',
    (tester) async {
      await initializeDateFormatting('ar');
      SharedPreferences.setMockInitialValues({'keep': 'yes'});
      final prefs = await SharedPreferences.getInstance();
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final apps = List.generate(
        10,
        (i) => App(
          packageName: 'installed.$i',
          name: 'TV $i',
          version: '1',
          hidden: false,
        ),
      );
      final service = MockAppsService();
      when(service.initialized).thenReturn(true);
      when(service.applications).thenReturn(apps);
      when(service.categories).thenReturn([]);
      when(service.getAppIcon(any)).thenAnswer((_) async => Uint8List(0));
      Future<void> home(DockFavourites store) async {
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AppsService>.value(value: service),
              ChangeNotifierProvider<DockFavourites>.value(value: store),
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

      final store = DockFavourites(prefs);
      await home(store);
      expect(store.initialized, isTrue);
      expect(find.byKey(const ValueKey('dock-installed.6')), findsOneWidget);
      expect(find.byKey(const ValueKey('dock-installed.7')), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('dock-edit-area')), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'dock-first');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
      await tester.pump(const Duration(milliseconds: 650));
      await tester.pumpAndSettle();
      expect(find.text('تعديل TV 0'), findsOneWidget);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(find.text('نقل التطبيق'), findsOneWidget);
      expect(find.text('إخفاء التطبيق'), findsOneWidget);
      expect(find.text('إلغاء التثبيت'), findsOneWidget);
      await tester.tap(find.text('تعديل المفضلة وإضافة تطبيق'));
      await tester.pumpAndSettle();
      expect(find.text('تعديل التطبيقات المفضلة (7/7)'), findsOneWidget);
      await tester.tap(find.byTooltip('إزالة من المفضلة').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('dock-installed.0')), findsNothing);
      expect(find.byKey(const ValueKey('dock-empty-6')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
      final restored = DockFavourites(prefs);
      await home(restored);
      expect(find.byKey(const ValueKey('dock-installed.0')), findsNothing);
      expect(prefs.getString('keep'), 'yes');
      await tester.pumpWidget(const SizedBox());
      restored.dispose();
      expect(tester.takeException(), isNull);
    },
  );
}
