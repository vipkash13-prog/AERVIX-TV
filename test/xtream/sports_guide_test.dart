import 'dart:convert';
import 'package:flauncher/xtream/sports_guide.dart';
import 'package:flauncher/xtream/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'fixtures.dart';

class SportsFixture extends CatalogueFixture {
  final DateTime now;
  SportsFixture({DateTime? now}) : now = now ?? DateTime.utc(2026, 11, 13, 15);
  @override
  Object response(String action) {
    if (action == 'get_live_categories')
      return [
        {'category_id': '1', 'category_name': 'Sports SSC'},
        {'category_id': '2', 'category_name': 'Adult XXX'},
      ];
    if (action == 'get_live_streams')
      return List.generate(
        10,
        (i) => {
          'stream_id': i + 1,
          'name': 'SSC ${i + 1}',
          'category_id': i == 9 ? '2' : '1',
        },
      );
    if (action == 'get_short_epg')
      return {
        'epg_listings': [
          {
            'title': base64Encode(utf8.encode('دوري: الهلال ضد النصر')),
            'start_timestamp':
                now
                    .subtract(const Duration(minutes: 15))
                    .millisecondsSinceEpoch ~/
                1000,
            'stop_timestamp':
                now.add(const Duration(hours: 2)).millisecondsSinceEpoch ~/
                1000,
          },
          {
            'title': base64Encode(utf8.encode('Adult XXX football')),
            'start_timestamp': now.millisecondsSinceEpoch ~/ 1000,
            'stop_timestamp':
                now.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
                1000,
          },
          {
            'title': 'sports news',
            'start_timestamp': now.millisecondsSinceEpoch ~/ 1000,
            'stop_timestamp':
                now.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
                1000,
          },
        ],
      };
    return super.response(action);
  }
}

void main() {
  test(
    'real guide is bounded to four allowed sports channels and filters adult programmes',
    () async {
      final f = SportsFixture();
      await f.init();
      addTearDown(f.service.dispose);
      final guide = await f.service.sportsGuide(now: f.now);
      expect(guide.length, 4);
      expect(f.actions.where((a) => a == 'get_short_epg').length, 4);
      expect(
        guide.every(
          (p) => p.title == 'دوري: الهلال ضد النصر' && p.liveAt(f.now),
        ),
        isTrue,
      );
      expect(guide.map((p) => p.channel.id), ['1', '2', '3', '4']);
      await f.service.block(MediaKind.live, '1');
      final filtered = await f.service.sportsGuide(now: f.now);
      expect(
        filtered.any((p) => p.channel.id == '1' || p.channel.id == '10'),
        isFalse,
      );
    },
  );
  test(
    'missing timestamps and expired/non-match listings never create fake matches',
    () async {
      final f = SportsFixture();
      await f.init();
      addTearDown(f.service.dispose);
      await f.service.refresh(MediaKind.live);
      final channel = f.service.items(MediaKind.live).first;
      final data = {
        'epg_listings': [
          {
            'title': 'Football A vs B',
            'start_timestamp': 'not-time',
            'stop_timestamp': 'unknown',
          },
          {
            'title': 'Football A vs B',
            'start_timestamp': -1,
            'stop_timestamp': 999999999999999,
          },
          {
            'title': 'Football A vs B',
            'start_timestamp':
                f.now
                    .subtract(const Duration(hours: 3))
                    .millisecondsSinceEpoch ~/
                1000,
            'stop_timestamp':
                f.now
                    .subtract(const Duration(hours: 1))
                    .millisecondsSinceEpoch ~/
                1000,
          },
        ],
      };
      expect(parseSportsGuide(data, channel, f.now, (_) => false), isEmpty);
      expect(parseSportsGuide({}, channel, f.now, (_) => false), isEmpty);
    },
  );
}
