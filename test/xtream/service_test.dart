import 'dart:convert';
import 'package:flauncher/xtream/models.dart';
import 'package:flauncher/xtream/content_filter.dart';
import 'package:flauncher/xtream/xtream_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final kind in MediaKind.values) {
    test(
      '${kind.name}: right endpoints, inherited adult filtering, search, favourites and refresh',
      () async {
        final f = CatalogueFixture();
        await f.init();
        addTearDown(f.service.dispose);
        await f.service.refresh(kind);
        expect(
          f.actions,
          containsAll([kind.categoryAction, kind.streamAction]),
        );
        expect(f.service.categories(kind).map((c) => c.id), ['1']);
        expect(f.service.items(kind).map((m) => m.id), ['1', '2', '3']);
        expect(f.service.items(kind, query: 'Porn'), isEmpty);
        final first = f.service.items(kind).first;
        await f.service.toggleFavourite(first);
        expect(f.service.items(kind, favourites: true).map((m) => m.id), ['1']);
        f.newlyAdult = true;
        await f.service.refresh(kind);
        expect(f.service.items(kind, favourites: true), isEmpty);
        expect(() => f.service.stream(first), throwsA(isA<XtreamFailure>()));
        await f.service.block(kind, '2');
        expect(f.service.items(kind).map((m) => m.id), ['3']);
        await f.service.refresh(kind);
        expect(f.service.items(kind).map((m) => m.id), ['3']);
        final restored = XtreamService(
          f.store,
          f.preferences,
          client: MockClient((r) async => http.Response('[]', 200)),
        );
        addTearDown(restored.dispose);
        await restored.ready;
        expect(restored.manualBlocks, contains('${kind.name}:stream:2'));
        expect(f.preferences.getString('existing_setting'), 'preserve');
        await f.service.block(kind, '1', category: true);
        expect(f.service.items(kind), isEmpty);
        expect(f.service.items(kind, query: 'الثالثة'), isEmpty);
        await f.service.unblock('${kind.name}:category:1');
        expect(f.service.items(kind).map((m) => m.id), ['3']);
      },
    );
  }
  test(
    'saved account reused; validation/storage failures preserve old credentials',
    () async {
      final f = CatalogueFixture();
      await f.init();
      addTearDown(f.service.dispose);
      expect(f.service.configured, isTrue);
      expect(f.actions, isEmpty);
      f.unavailable = true;
      await expectLater(
        f.service.save('https://other.test', 'new', 'new'),
        throwsA(isA<XtreamFailure>()),
      );
      expect(f.store.account, same(f.account));
      f.unavailable = false;
      f.store.rejectWrite = true;
      await expectLater(
        f.service.save('https://other.test', 'new', 'new'),
        throwsA(isA<XtreamFailure>()),
      );
      expect(f.store.account, same(f.account));
      f.store.rejectWrite = false;
      await f.service.save('https://other.test', 'new', 'new');
      expect(f.service.host, 'https://other.test');
      expect(
        f.preferences.getKeys().any((k) => k.contains('password')),
        isFalse,
      );
    },
  );
  test(
    'movie and episode paths are internal Xtream URLs, with sorted seasons/episodes',
    () async {
      final f = CatalogueFixture();
      await f.init();
      addTearDown(f.service.dispose);
      await f.service.refresh(MediaKind.movie);
      final movie = f.service.items(MediaKind.movie).first;
      expect(
        f.service.stream(movie).path,
        '/base/movie/fixture-user/fixture-password/1.mp4',
      );
      await f.service.refresh(MediaKind.series);
      final series = f.service.items(MediaKind.series).first;
      final episodes = await f.service.episodes(series);
      expect(episodes.map((e) => e.media.id), ['101', '102', '202']);
      expect(episodes.map((e) => e.season), [1, 1, 2]);
      expect(
        f.service
            .stream(episodes.last.media, episode: true, parent: series)
            .path,
        endsWith('/series/fixture-user/fixture-password/202.mkv'),
      );
      expect(
        () => f.service.stream(episodes.first.media, episode: true),
        throwsA(isA<XtreamFailure>()),
      );
      await f.service.block(MediaKind.series, series.id);
      expect(await f.service.episodes(series), isEmpty);
      expect(
        () => f.service.stream(
          episodes.first.media,
          episode: true,
          parent: series,
        ),
        throwsA(isA<XtreamFailure>()),
      );
    },
  );
  test(
    'detail metadata removes otherwise innocent VOD/series from search and favourites permanently',
    () async {
      final f = CatalogueFixture();
      await f.init();
      addTearDown(f.service.dispose);
      final service = XtreamService(
        f.store,
        f.preferences,
        client: MockClient((request) async {
          final action = request.url.queryParameters['action'] ?? 'auth';
          final data = action == 'get_vod_info'
              ? {
                  'info': {'adult': true},
                }
              : action == 'get_series_info'
              ? {
                  'info': {'genre': 'Adult'},
                  'episodes': {},
                }
              : f.response(action);
          return http.Response(
            jsonEncode(data),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(service.dispose);
      await service.ready;
      for (final kind in [MediaKind.movie, MediaKind.series]) {
        await service.refresh(kind);
        final first = service.items(kind).first;
        await service.toggleFavourite(first);
        if (kind == MediaKind.movie) {
          expect(await service.checkMovie(first), isFalse);
        } else {
          expect(await service.episodes(first), isEmpty);
        }
        expect(service.items(kind, query: first.name), isEmpty);
        expect(service.items(kind, favourites: true), isEmpty);
        await service.refresh(kind);
        expect(service.items(kind).map((m) => m.id), isNot(contains(first.id)));
      }
    },
  );
  test(
    'large catalogues are parsed on a worker and remain filtered in server order',
    () async {
      final f = CatalogueFixture();
      await f.init();
      addTearDown(f.service.dispose);
      final service = XtreamService(
        f.store,
        f.preferences,
        client: MockClient((request) async {
          final action = request.url.queryParameters['action']!;
          final data = action.endsWith('categories')
              ? f.response(action)
              : List.generate(
                  1200,
                  (i) => {
                    'stream_id': i + 1,
                    'name': i % 10 == 0 ? 'XXX' : 'Channel $i',
                    'category_id': '1',
                  },
                );
          return http.Response(
            jsonEncode(data),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(service.dispose);
      await service.ready;
      await service.refresh(MediaKind.live);
      expect(service.items(MediaKind.live).length, 1080);
      expect(service.items(MediaKind.live).first.id, '2');
      expect(service.items(MediaKind.live).last.id, '1200');
    },
  );
  test(
    'full subscription link imported and special credentials encoded without leaking diagnostics',
    () {
      final account = XtreamAccount.input(
        'https://example.test:8443/reverse/get.php?username=user%2Fname&password=p%40ss%3F&type=m3u',
        '',
        '',
      );
      expect(account.api('get_live_streams').path, '/reverse/player_api.php');
      expect(account.api().queryParameters['username'], 'user/name');
      expect(
        account.stream(MediaKind.live, '12', 'ts').pathSegments,
        containsAllInOrder(['live', 'user/name', 'p@ss?', '12.ts']),
      );
      expect(account.toString(), isNot(contains('p@ss')));
      expect(
        () => XtreamAccount.input('ftp://x', 'u', 'p'),
        throwsA(isA<XtreamFailure>()),
      );
    },
  );
  test(
    'keyword boundaries avoid normal names and match Arabic / obfuscated adult labels',
    () {
      final filter = ContentFilter();
      for (final label in [
        'ADULT',
        'xxx HD',
        '[18+]',
        '+18',
        '18 PLUS',
        'P0RN',
        'أفلام إباحية',
        'لِلْكِبَار',
        'قنوات ١٨+',
      ])
        expect(filter.nameBlocked(label), isTrue, reason: label);
      for (final label in [
        'Sussex News',
        'Essex Sports',
        'Classic Movies',
        'قنوات الأطفال',
      ])
        expect(filter.nameBlocked(label), isFalse, reason: label);
    },
  );
}
