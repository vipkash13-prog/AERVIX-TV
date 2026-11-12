import 'package:flauncher/actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final key in [
    LogicalKeyboardKey.escape,
    LogicalKeyboardKey.gameButtonB,
  ]) {
    testWidgets(
      '${key.keyLabel} closes focused dialog even when action context is above Navigator',
      (tester) async {
        await tester.pumpWidget(
          Builder(
            builder: (outerContext) => MaterialApp(
              shortcuts: {
                ...WidgetsApp.defaultShortcuts,
                SingleActivator(key): const BackIntent(),
              },
              actions: {
                ...WidgetsApp.defaultActions,
                BackIntent: BackAction(outerContext),
              },
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    autofocus: true,
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('dialog'),
                        actions: [
                          TextButton(
                            autofocus: true,
                            onPressed: () {},
                            child: const Text('focused'),
                          ),
                        ],
                      ),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(key);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('Back pops focused nested page before its containing dialog', (
    tester,
  ) async {
    await tester.pumpWidget(
      Builder(
        builder: (outerContext) => MaterialApp(
          shortcuts: {
            ...WidgetsApp.defaultShortcuts,
            const SingleActivator(LogicalKeyboardKey.escape):
                const BackIntent(),
          },
          actions: {
            ...WidgetsApp.defaultActions,
            BackIntent: BackAction(outerContext),
          },
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => AlertDialog(
                    content: SizedBox(
                      width: 300,
                      height: 200,
                      child: Navigator(
                        onGenerateRoute: (_) => MaterialPageRoute<void>(
                          builder: (inner) => TextButton(
                            autofocus: true,
                            onPressed: () => Navigator.of(inner).push(
                              MaterialPageRoute<void>(
                                builder: (_) => Center(
                                  child: TextButton(
                                    autofocus: true,
                                    onPressed: () {},
                                    child: const Text('nested page'),
                                  ),
                                ),
                              ),
                            ),
                            child: const Text('inner root'),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('inner root'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('nested page'), findsNothing);
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
