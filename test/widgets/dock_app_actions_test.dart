import 'package:flauncher/models/app.dart';
import 'package:flauncher/providers/dock_favourites.dart';
import 'package:flauncher/widgets/dock_app_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../mocks.mocks.dart';

void main() {
  for (final action in [
    'إزالة من المفضلة',
    'إخفاء التطبيق',
    'إلغاء التثبيت',
    'نقل التطبيق',
  ]) {
    testWidgets('dock context action: $action', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = DockFavourites(await SharedPreferences.getInstance());
      final apps = List.generate(
        3,
        (i) => App(
          packageName: 'app.$i',
          name: 'TV $i',
          version: '1',
          hidden: false,
        ),
      );
      await store.save(apps.map((a) => a.packageName).toList());
      final service = MockAppsService();
      when(service.applications).thenReturn(apps);
      when(service.hideApplication(any)).thenAnswer((_) async {});
      when(service.uninstallApp(any)).thenAnswer((_) async {});
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    editDockApp(context, apps.first, store, service),
                child: const Text('تعديل'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('تعديل'));
      await tester.pumpAndSettle();
      expect(find.text('تعديل TV 0'), findsOneWidget);
      await tester.tap(find.text(action));
      await tester.pumpAndSettle();
      if (action == 'نقل التطبيق') {
        await tester.tap(find.text('3 · TV 2'));
        await tester.pumpAndSettle();
        expect(store.visible(apps).map((a) => a.packageName), [
          'app.1',
          'app.2',
          'app.0',
        ]);
      } else if (action == 'إلغاء التثبيت') {
        verify(service.uninstallApp(apps.first)).called(1);
        expect(store.visible(apps), apps);
      } else {
        expect(store.visible(apps).map((a) => a.packageName), [
          'app.1',
          'app.2',
        ]);
        if (action == 'إخفاء التطبيق')
          verify(service.hideApplication(apps.first)).called(1);
      }
      if (action != 'إلغاء التثبيت') verifyNever(service.uninstallApp(any));
      await tester.pumpWidget(const SizedBox());
      store.dispose();
      expect(tester.takeException(), isNull);
    });
  }
}
