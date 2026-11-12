import 'package:flauncher/xtream/account_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'fixtures.dart';

void main() {
  Future<CatalogueFixture> open(WidgetTester tester) async {
    final f = CatalogueFixture();
    await f.init(emptyAccount: true);
    addTearDown(f.service.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showXtreamAccount(context, f.service),
              child: const Text('setup'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('setup'));
    await tester.pumpAndSettle();
    return f;
  }

  Future<void> key(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'D-pad escapes editable field shortcuts and reaches username/password/save and cancel',
    (tester) async {
      await open(tester);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'xtream-host');
      await key(tester, LogicalKeyboardKey.arrowDown);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'xtream-user');
      await key(tester, LogicalKeyboardKey.arrowDown);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'xtream-password');
      await key(tester, LogicalKeyboardKey.arrowDown);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'xtream-save');
      await key(tester, LogicalKeyboardKey.arrowRight);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'xtream-cancel');
      await key(tester, LogicalKeyboardKey.arrowLeft);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'xtream-save');
      for (final label in ['xtream-password', 'xtream-user', 'xtream-host']) {
        await key(tester, LogicalKeyboardKey.arrowUp);
        expect(FocusManager.instance.primaryFocus?.debugLabel, label);
      }
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'OK opens editing; values survive remote movement; validation button saves all three inputs',
    (tester) async {
      final f = await open(tester);
      await key(tester, LogicalKeyboardKey.select);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('xtream-host-field')))
            .readOnly,
        isFalse,
      );
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.enterText(
        find.byKey(const ValueKey('xtream-host-field')),
        'https://fixture.test',
      );
      await key(tester, LogicalKeyboardKey.arrowDown);
      expect(tester.testTextInput.isVisible, isFalse);
      await key(tester, LogicalKeyboardKey.enter);
      await tester.enterText(
        find.byKey(const ValueKey('xtream-user-field')),
        'fixture-user',
      );
      await key(tester, LogicalKeyboardKey.arrowDown);
      await key(tester, LogicalKeyboardKey.select);
      await tester.enterText(
        find.byKey(const ValueKey('xtream-password-field')),
        'fixture-password',
      );
      await key(tester, LogicalKeyboardKey.arrowDown);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'xtream-save');
      await key(tester, LogicalKeyboardKey.select);
      expect(find.byType(AlertDialog), findsNothing);
      expect(f.store.account?.username, 'fixture-user');
      expect(f.store.account?.password, 'fixture-password');
      expect(f.store.account?.server.host, 'fixture.test');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('software keyboard Next/Done uses the same field sequence', (
    tester,
  ) async {
    await open(tester);
    await key(tester, LogicalKeyboardKey.select);
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'xtream-user');
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('xtream-user-field')))
          .readOnly,
      isFalse,
    );
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'xtream-password');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'xtream-save');
    expect(tester.testTextInput.isVisible, isFalse);
  });
}
