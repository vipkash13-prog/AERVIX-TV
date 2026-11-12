import 'package:flauncher/xtream/browser_page.dart';
import 'package:flauncher/xtream/models.dart';
import 'package:flauncher/xtream/player_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'fixtures.dart';
import 'playback_test.dart' show FakeVideoPlatform, frames;

class LongMoviesFixture extends CatalogueFixture {
  @override
  Object response(String action) => action == 'get_vod_streams'
      ? List.generate(
          60,
          (i) => {
            'stream_id': i + 1,
            'name': 'فيلم رقم ${i + 1}',
            'category_id': '1',
            'num': i + 1,
          },
        )
      : super.response(action);
}

void main() {
  testWidgets(
    'movie Back preserves category, search, scroll and focus despite duplicate Back',
    (tester) async {
      final platform = FakeVideoPlatform();
      VideoPlayerPlatform.instance = platform;
      final f = LongMoviesFixture();
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
                      kind: MediaKind.movie,
                    ),
                  ),
                ),
                child: const Text('الرئيسية التجريبية'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('الرئيسية التجريبية'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('xtream-search-input')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('xtream-search-input')),
        'فيلم',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('xtream-category-1')));
      await tester.pumpAndSettle();
      final results = find.byType(ListView).last;
      await tester.scrollUntilVisible(
        find.text('فيلم رقم 35'),
        400,
        scrollable: find
            .descendant(of: results, matching: find.byType(Scrollable))
            .first,
      );
      await tester.pumpAndSettle();
      final controller = tester.widget<ListView>(results).controller!;
      final offset = controller.offset;
      final requests = f.actions.where((a) => a == 'get_vod_streams').length;
      await tester.tap(find.text('فيلم رقم 35'));
      await frames(tester);
      expect(platform.sources.values.last.uri, endsWith('/35.mp4'));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.binding.handlePopRoute();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(XtreamBrowserPage), findsOneWidget);
      expect(find.byType(XtreamPlayerPage), findsNothing);
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'xtream-result-movie:35',
      );
      expect(controller.offset, closeTo(offset, 1));
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('xtream-search-input')),
            )
            .controller!
            .text,
        'فيلم',
      );
      expect(f.actions.where((a) => a == 'get_vod_streams').length, requests);
      expect(
        tester
            .widget<ListTile>(find.byKey(const ValueKey('xtream-category-1')))
            .selected,
        isTrue,
      );
      // The immediately selected film opens with a single OK after return.
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await frames(tester);
      expect(find.byType(XtreamPlayerPage), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('الرئيسية التجريبية'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await frames(tester);
      expect(tester.takeException(), isNull);
    },
  );
}
