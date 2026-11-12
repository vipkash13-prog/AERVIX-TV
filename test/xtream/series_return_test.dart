import 'package:flauncher/xtream/models.dart';
import 'package:flauncher/xtream/browser_page.dart';
import 'package:flauncher/xtream/player_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'fixtures.dart';
import 'playback_test.dart' show FakeVideoPlatform, frames;

class LongSeriesFixture extends CatalogueFixture {
  @override
  Object response(String action) => action == 'get_series_info'
      ? {
          'info': {'name': 'Series'},
          'episodes': {
            '1': List.generate(
              50,
              (i) => {
                'id': 100 + i,
                'season': 1,
                'episode_num': i + 1,
                'title': 'حلقة رقم ${i + 1}',
              },
            ),
          },
        }
      : super.response(action);
}

void main() {
  Future<void> open(WidgetTester tester, CatalogueFixture f) async {
    await f.init();
    addTearDown(f.service.dispose);
    await f.service.refresh(MediaKind.series);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => XtreamSeriesPage(
                    service: f.service,
                    series: f.service.items(MediaKind.series).first,
                  ),
                ),
              ),
              child: const Text('قائمة المسلسلات'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('قائمة المسلسلات'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Back returns to episodes, rejects a duplicate system Back, and OK plays the next episode',
    (tester) async {
      final platform = FakeVideoPlatform();
      VideoPlayerPlatform.instance = platform;
      final f = CatalogueFixture();
      await open(tester, f);
      await tester.tap(find.byKey(const ValueKey('series-episode-1-101')));
      await frames(tester);
      expect(platform.sources.values.last.uri, endsWith('/101.mp4'));
      await tester.binding.handlePopRoute();
      await tester.binding.handlePopRoute();
      await frames(tester);
      await tester.pumpAndSettle();
      expect(find.byType(XtreamPlayerPage), findsNothing);
      expect(find.byKey(const ValueKey('series-episodes-1')), findsOneWidget);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'episode-101');
      expect(f.actions.where((a) => a == 'get_series_info').length, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await frames(tester);
      expect(platform.sources.values.last.uri, endsWith('/102.mp4'));
      await tester.pumpWidget(const SizedBox());
      await frames(tester);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'season and focus survive playback; a later Back still exits normally',
    (tester) async {
      VideoPlayerPlatform.instance = FakeVideoPlatform();
      final f = CatalogueFixture();
      await open(tester, f);
      await tester.tap(find.byKey(const ValueKey('series-season-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('series-episode-1-202')));
      await frames(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await frames(tester);
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const ValueKey('series-season-2')))
            .selected,
        isTrue,
      );
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'episode-202');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('قائمة المسلسلات'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await frames(tester);
    },
  );
  testWidgets(
    'a scrolled episode list returns to the same episode and scroll offset',
    (tester) async {
      VideoPlayerPlatform.instance = FakeVideoPlatform();
      final f = LongSeriesFixture();
      await open(tester, f);
      final list = find.byKey(const PageStorageKey('series-1-season-1'));
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('series-episode-1-134')),
        400,
        scrollable: find
            .descendant(of: list, matching: find.byType(Scrollable))
            .first,
      );
      await tester.pumpAndSettle();
      final controller = tester.widget<ListView>(list).controller!;
      final offset = controller.offset;
      expect(offset, greaterThan(0));
      await tester.tap(find.byKey(const ValueKey('series-episode-1-134')));
      await frames(tester);
      await tester.binding.handlePopRoute();
      await frames(tester);
      expect(tester.widget<ListView>(list).controller, same(controller));
      expect(controller.offset, closeTo(offset, 1));
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'episode-134');
      expect(f.actions.where((a) => a == 'get_series_info').length, 1);
      await tester.pumpWidget(const SizedBox());
      await frames(tester);
      expect(tester.takeException(), isNull);
    },
  );
}
