import 'package:flauncher/providers/dock_favourites.dart';
import 'package:flauncher/widgets/dock_favourites_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/dock_favourites_test.dart' show installedApps;

void main() {
  testWidgets(
    'remove, add, reorder and save seven favourites without changing installed apps',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = DockFavourites(prefs);
      final apps = installedApps();
      await store.seed(apps);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => editDockFavourites(context, store, apps),
                child: const Text('edit'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('edit'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'إضافة تطبيق'))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('إزالة من المفضلة').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('إضافة تطبيق'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('TV 7'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('تحريك للأسفل').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();
      expect(DockFavourites(prefs).visible(apps).map((a) => a.packageName), [
        'installed.2',
        'installed.1',
        'installed.3',
        'installed.4',
        'installed.5',
        'installed.6',
        'installed.7',
      ]);
      expect(apps.length, 10);
      expect(apps.every((a) => !a.hidden), isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'cancel discards edits; reset restores original seven only after Save',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = DockFavourites(prefs);
      final apps = installedApps();
      await store.save(['installed.9']);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => editDockFavourites(context, store, apps),
                child: const Text('edit'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('edit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('استعادة الافتراضي'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(store.visible(apps).single.packageName, 'installed.9');
      await tester.tap(find.text('edit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('استعادة الافتراضي'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();
      expect(
        store.visible(apps).map((a) => a.packageName),
        List.generate(7, (i) => 'installed.$i'),
      );
    },
  );
}
