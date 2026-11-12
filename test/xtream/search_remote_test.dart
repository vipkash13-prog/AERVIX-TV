import 'package:flauncher/xtream/browser_page.dart';
import 'package:flauncher/xtream/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'fixtures.dart';

void main() {
  Future<CatalogueFixture> open(WidgetTester tester, MediaKind kind) async {
    final f = CatalogueFixture();
    await f.init();
    addTearDown(f.service.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: XtreamBrowserPage(service: f.service, kind: kind),
      ),
    );
    await tester.pumpAndSettle();
    return f;
  }

  Future<void> key(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
  }

  for (final kind in MediaKind.values) {
    testWidgets(
      '${kind.name}: search can be entered and exited to results/categories/header without trapping arrows',
      (tester) async {
        await open(tester, kind);
        await key(tester, LogicalKeyboardKey.arrowUp);
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'xtream-search');
        expect(
          tester
              .widget<TextField>(
                find.byKey(const ValueKey('xtream-search-input')),
              )
              .readOnly,
          isTrue,
        );
        await key(tester, LogicalKeyboardKey.select);
        expect(tester.testTextInput.isVisible, isTrue);
        await tester.enterText(
          find.byKey(const ValueKey('xtream-search-input')),
          'الثانية',
        );
        await key(tester, LogicalKeyboardKey.arrowDown);
        expect(tester.testTextInput.isVisible, isFalse);
        expect(
          FocusManager.instance.primaryFocus?.debugLabel,
          'xtream-result-${kind.name}:2',
        );
        expect(
          find.byKey(ValueKey('xtream-item-${kind.name}:1')),
          findsNothing,
        );
        await key(tester, LogicalKeyboardKey.arrowUp);
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'xtream-search');
        await key(tester, LogicalKeyboardKey.arrowRight);
        expect(
          FocusManager.instance.primaryFocus?.debugLabel,
          'xtream-category-all',
        );
        await key(tester, LogicalKeyboardKey.arrowUp);
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'xtream-search');
        await key(tester, LogicalKeyboardKey.arrowUp);
        expect(
          FocusManager.instance.primaryFocus?.debugLabel,
          'xtream-account',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'Search action and zero results still offer an escape; clear restores safe results',
    (tester) async {
      await open(tester, MediaKind.live);
      await key(tester, LogicalKeyboardKey.arrowUp);
      await key(tester, LogicalKeyboardKey.select);
      await tester.enterText(
        find.byKey(const ValueKey('xtream-search-input')),
        'XXX',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('لا يوجد محتوى متاح'), findsOneWidget);
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'xtream-category-all',
      );
      await key(tester, LogicalKeyboardKey.arrowUp);
      await key(tester, LogicalKeyboardKey.arrowLeft);
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'xtream-search-clear',
      );
      await key(tester, LogicalKeyboardKey.enter);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('xtream-search-input')),
            )
            .controller!
            .text,
        isEmpty,
      );
      await key(tester, LogicalKeyboardKey.arrowDown);
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'xtream-result-live:1',
      );
      expect(find.textContaining('Porn'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Back closes search typing first; a later normal Back closes the catalogue',
    (tester) async {
      final f = CatalogueFixture();
      await f.init();
      addTearDown(f.service.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => XtreamBrowserPage(
                      service: f.service,
                      kind: MediaKind.live,
                    ),
                  ),
                ),
                child: const Text('home'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('home'));
      await tester.pumpAndSettle();
      await key(tester, LogicalKeyboardKey.arrowUp);
      await key(tester, LogicalKeyboardKey.select);
      await key(tester, LogicalKeyboardKey.escape);
      expect(find.byType(XtreamBrowserPage), findsOneWidget);
      expect(tester.testTextInput.isVisible, isFalse);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
