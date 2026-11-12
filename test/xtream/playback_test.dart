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
  final positions = <int, Duration>{};
  final playPositions = <int, Duration>{};
  final seeks = <(int, Duration)>[];
  final events = <int, StreamController<VideoEvent>>{};
  bool initializeImmediately = true;
  int startupFailures = 0;
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
        if (startupFailures > 0) {
          startupFailures--;
          scheduleMicrotask(
            () => events[id]!.addError(
              PlatformException(
                code: 'transient',
                message: 'private stream URI',
              ),
            ),
          );
          return;
        }
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
    playPositions[playerId] = positions[playerId] ?? Duration.zero;
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
  Future<void> seekTo(int playerId, Duration position) async {
    positions[playerId] = position;
    seeks.add((playerId, position));
  }

  @override
  Future<Duration> getPosition(int playerId) async =>
      positions[playerId] ?? Duration.zero;
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
      expect(engine.error, isNull);
      expect(engine.loading, isTrue);
      engine.dispose();
      await frames(tester);
      expect(platform.maxAlive, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'two transient startup failures recover without pressing OK again',
    (tester) async {
      platform.startupFailures = 2;
      final engine = VideoMediaEngine();
      unawaited(
        engine.open(
          Uri.parse('https://fixture.test/movie/user/secret/1.mp4'),
          live: false,
        ),
      );
      await frames(tester);
      expect(engine.loading, isTrue);
      expect(engine.error, isNull);
      await tester.pump(const Duration(milliseconds: 850));
      await frames(tester);
      await tester.pump(const Duration(milliseconds: 1650));
      await frames(tester);
      expect(platform.sources.length, 3);
      expect(platform.played, [3]);
      expect(platform.maxAlive, 1);
      expect(engine.error, isNull);
      expect(engine.loading, isFalse);
      engine.dispose();
      await frames(tester);
    },
  );
  testWidgets('retries are bounded and stop cancels a pending retry', (
    tester,
  ) async {
    platform.startupFailures = 20;
    final engine = VideoMediaEngine();
    unawaited(
      engine.open(
        Uri.parse('https://fixture.test/movie/user/secret/1.mp4'),
        live: false,
      ),
    );
    await frames(tester);
    await tester.pump(const Duration(milliseconds: 850));
    await frames(tester);
    await tester.pump(const Duration(milliseconds: 1650));
    await frames(tester);
    expect(platform.sources.length, 3);
    expect(engine.loading, isFalse);
    expect(engine.error, contains('تلقائيًا'));
    expect(engine.error, isNot(contains('private')));
    await tester.pump(const Duration(seconds: 10));
    await frames(tester);
    expect(platform.sources.length, 3);
    unawaited(
      engine.open(
        Uri.parse('https://fixture.test/live/user/secret/2.ts'),
        live: true,
      ),
    );
    await frames(tester);
    unawaited(engine.stop());
    await tester.pump(const Duration(seconds: 5));
    await frames(tester);
    expect(platform.sources.length, 4);
    expect(platform.disposed.length, 4);
    engine.dispose();
    await frames(tester);
  });
  testWidgets(
    'VOD reconnect at 43 seconds restores position before playing and repeated retry retains it',
    (tester) async {
      final engine = VideoMediaEngine();
      final uri = Uri.parse('https://fixture.test/movie/user/secret/1.mp4');
      unawaited(engine.open(uri, live: false));
      await frames(tester);
      platform.positions[1] = const Duration(seconds: 43);
      await tester.pump(const Duration(milliseconds: 600));
      await frames(tester);
      platform.events[1]!.addError(
        PlatformException(code: 'network', message: 'interrupted'),
      );
      await frames(tester);
      await tester.pump(const Duration(milliseconds: 850));
      await frames(tester);
      expect(platform.seeks, contains((2, const Duration(seconds: 43))));
      expect(platform.played, [1, 2]);
      expect(platform.playPositions[2], const Duration(seconds: 43));
      platform.positions[2] = const Duration(seconds: 51);
      await tester.pump(const Duration(milliseconds: 600));
      await frames(tester);
      platform.events[2]!.addError(
        PlatformException(code: 'network', message: 'interrupted'),
      );
      await frames(tester);
      await tester.pump(const Duration(milliseconds: 1650));
      await frames(tester);
      expect(platform.seeks.last, (3, const Duration(seconds: 51)));
      expect(platform.playPositions[3], const Duration(seconds: 51));
      platform.events[3]!.addError(
        PlatformException(code: 'network', message: 'interrupted'),
      );
      await frames(tester);
      expect(engine.error, isNotNull);
      unawaited(engine.retry(uri, live: false));
      await frames(tester);
      expect(platform.seeks.last, (4, const Duration(seconds: 51)));
      expect(platform.playPositions[4], const Duration(seconds: 51));
      // A different film starts at zero; a channel never uses VOD seek state.
      unawaited(
        engine.open(
          Uri.parse('https://fixture.test/movie/user/secret/2.mp4'),
          live: false,
        ),
      );
      await frames(tester);
      expect(platform.seeks.where((entry) => entry.$1 == 5), isEmpty);
      unawaited(
        engine.open(
          Uri.parse('https://fixture.test/live/user/secret/1.ts'),
          live: true,
        ),
      );
      await frames(tester);
      expect(platform.seeks.where((entry) => entry.$1 == 6), isEmpty);
      expect(platform.maxAlive, 1);
      engine.dispose();
      await frames(tester);
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
