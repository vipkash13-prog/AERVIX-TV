import 'dart:async';
import 'package:flauncher/xtream/models.dart';
import 'package:flauncher/xtream/playback.dart';
import 'package:flauncher/xtream/player_page.dart';
import 'package:flauncher/xtream/browser_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'fixtures.dart';

class FakeVideoPlatform extends VideoPlayerPlatform {
  final sources = <int, DataSource>{};
  final disposed = <int>[];
  final played = <int>[];
  final paused = <int>[];
  final events = <int, StreamController<VideoEvent>>{};
  bool initializeImmediately = true;
  int _next = 0, maxAlive = 0;
  @override
  Future<void> init() async {}
  @override
  Future<int> createWithOptions(VideoCreationOptions options) async {
    final id = ++_next;
    sources[id] = options.dataSource;
    events[id] = StreamController<VideoEvent>.broadcast(
      sync: true,
      onListen: () {
        if (initializeImmediately)
          scheduleMicrotask(
            () => events[id]!.add(
              VideoEvent(
                eventType: VideoEventType.initialized,
                duration: const Duration(minutes: 20),
                size: const Size(1920, 1080),
              ),
            ),
          );
      },
    );
    final alive = sources.length - disposed.length;
    if (alive > maxAlive) maxAlive = alive;
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    return events[playerId]!.stream;
  }

  @override
  Future<void> dispose(int playerId) async {
    disposed.add(playerId);
    unawaited(events[playerId]?.close() ?? Future<void>.value());
  }

  @override
  Future<void> play(int playerId) async {
    played.add(playerId);
  }

  @override
  Future<void> pause(int playerId) async {
    paused.add(playerId);
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<void> seekTo(int playerId, Duration position) async {}
  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;
  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const ColoredBox(color: Colors.black);
}

Future<void> frames(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  }
}

void main() {
  late FakeVideoPlatform platform;
  setUp(() {
    platform = FakeVideoPlatform();
    VideoPlayerPlatform.instance = platform;
  });
  testWidgets(
    'internal live playback: UP next, DOWN previous, overlay, no catalogue request and Back to list',
    (tester) async {
      final f = CatalogueFixture();
      await f.init();
      addTearDown(f.service.dispose);
      await f.service.refresh(MediaKind.live);
      final playlist = f.service.items(MediaKind.live, category: '1');
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => XtreamPlayerPage(
                      service: f.service,
                      playlist: playlist,
                      currentPlaylist: () =>
                          f.service.items(MediaKind.live, category: '1'),
                    ),
                  ),
                ),
                child: const Text('channel list'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('channel list'));
      await frames(tester);
      expect(platform.played, isNotEmpty);
      expect(
        platform.sources.values.last.uri,
        endsWith('/live/fixture-user/fixture-password/1.ts'),
      );
      final requests = f.actions.length;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await frames(tester);
      expect(find.text('2 · الثانية'), findsOneWidget);
      expect(platform.sources.values.last.uri, endsWith('/2.ts'));
      expect(find.text('2 · الثانية'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await frames(tester);
      expect(platform.sources.values.last.uri, endsWith('/1.ts'));
      expect(find.text('1 · الأولى'), findsOneWidget);
      expect(f.actions.length, requests);
      expect(platform.maxAlive, 1);
      await tester.pump(const Duration(seconds: 4));
      expect(find.byKey(const ValueKey('playing-channel')), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await frames(tester);
      expect(find.text('channel list'), findsOneWidget);
      expect(platform.disposed.length, platform.sources.length);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'rapid held remote events coalesce; all stream IDs remain in chosen category',
    (tester) async {
      final f = CatalogueFixture();
      await f.init();
      addTearDown(f.service.dispose);
      await f.service.refresh(MediaKind.live);
      final list = f.service.items(MediaKind.live, category: '1');
      await tester.pumpWidget(
        MaterialApp(
          home: XtreamPlayerPage(
            service: f.service,
            playlist: list,
            currentPlaylist: () =>
                f.service.items(MediaKind.live, category: '1'),
          ),
        ),
      );
      await frames(tester);
      for (var i = 0; i < 40; i++) {
        await tester.sendKeyEvent(
          i.isEven ? LogicalKeyboardKey.arrowUp : LogicalKeyboardKey.arrowDown,
        );
      }
      await frames(tester);
      expect(platform.sources.length, lessThanOrEqualTo(2));
      expect(platform.maxAlive, 1);
      expect(platform.sources.values.last.uri, endsWith('/1.ts'));
      await f.service.block(MediaKind.live, '1');
      await frames(tester);
      expect(find.text('1 · الأولى'), findsNothing);
      expect(platform.sources.values.last.uri, endsWith('/2.ts'));
      await tester.pumpWidget(const SizedBox());
      await frames(tester);
      expect(platform.disposed.length, platform.sources.length);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'stale initialization never plays; errors are generic and retryable',
    (tester) async {
      platform.initializeImmediately = false;
      final engine = VideoMediaEngine();
      unawaited(
        engine.open(
          Uri.parse('https://fixture.test/live/user/secret/1.ts'),
          live: true,
        ),
      );
      await frames(tester);
      unawaited(
        engine.open(
          Uri.parse('https://fixture.test/live/user/secret/2.m3u8'),
          live: true,
        ),
      );
      await frames(tester);
      expect(platform.played, isEmpty);
      expect(platform.disposed, [1]);
      expect(platform.sources[2]!.formatHint, VideoFormat.hls);
      platform.events[2]!.add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          duration: const Duration(minutes: 1),
          size: const Size(1920, 1080),
        ),
      );
      await frames(tester);
      expect(platform.played, [2]);
      platform.events[2]!.addError(
        PlatformException(
          code: 'bad',
          message: 'https://fixture.test/user/secret/2.m3u8',
        ),
      );
      await frames(tester);
      expect(engine.error, isNot(contains('secret')));
      expect(engine.loading, isFalse);
      engine.dispose();
      await frames(tester);
      expect(platform.maxAlive, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'movies and series browse through internal player; adult categories absent',
    (tester) async {
      final f = CatalogueFixture();
      await f.init();
      addTearDown(f.service.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: XtreamBrowserPage(service: f.service, kind: MediaKind.movie),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Adult XXX'), findsNothing);
      expect(find.text('concealed title'), findsNothing);
      await tester.tap(find.text('الأولى'));
      await frames(tester);
      expect(
        platform.sources.values.last.uri,
        endsWith('/movie/fixture-user/fixture-password/1.mp4'),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        MaterialApp(
          key: UniqueKey(),
          home: XtreamBrowserPage(service: f.service, kind: MediaKind.series),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('الأولى'));
      await tester.pumpAndSettle();
      expect(find.text('الموسم 1'), findsOneWidget);
      expect(find.text('الموسم 2'), findsOneWidget);
      expect(find.textContaining('XXX'), findsNothing);
      await tester.tap(find.text('1 · الأولى'));
      await frames(tester);
      expect(
        platform.sources.values.last.uri,
        endsWith('/series/fixture-user/fixture-password/101.mp4'),
      );
      await tester.pumpWidget(const SizedBox());
      await frames(tester);
      expect(tester.takeException(), isNull);
    },
  );
}
