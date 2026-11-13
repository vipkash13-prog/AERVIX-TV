import 'dart:convert';
import 'models.dart';

class SportsProgramme {
  final MediaEntry channel;
  final String title;
  final DateTime start, end;
  const SportsProgramme({
    required this.channel,
    required this.title,
    required this.start,
    required this.end,
  });
  bool liveAt(DateTime now) => !start.isAfter(now) && end.isAfter(now);
}

String decodeProgrammeTitle(Object? value) {
  final text = '${value ?? ''}'.trim();
  try {
    return utf8.decode(base64.decode(base64.normalize(text)));
  } catch (_) {
    return text;
  }
}

List<SportsProgramme> parseSportsGuide(
  Object? data,
  MediaEntry channel,
  DateTime now,
  bool Function(String) blocked,
) {
  if (data is! Map || data['epg_listings'] is! List) return [];
  final local = now.toUtc().add(const Duration(hours: 3));
  final day = DateTime.utc(
    local.year,
    local.month,
    local.day,
  ).subtract(const Duration(hours: 3));
  final tomorrow = day.add(const Duration(days: 1));
  final result = <SportsProgramme>[];
  for (final row in (data['epg_listings'] as List).take(40)) {
    if (row is! Map) continue;
    if (adultFlag(row['adult']) || adultFlag(row['is_adult'])) continue;
    final from = int.tryParse('${row['start_timestamp']}');
    final to = int.tryParse('${row['stop_timestamp'] ?? row['end_timestamp']}');
    if (from == null || to == null || from < 0 || to > 4102444800 || to <= from)
      continue;
    final start = DateTime.fromMillisecondsSinceEpoch(from * 1000, isUtc: true);
    final end = DateTime.fromMillisecondsSinceEpoch(to * 1000, isUtc: true);
    if (!end.isAfter(now) || !start.isBefore(tomorrow) || !end.isAfter(day))
      continue;
    final title = decodeProgrammeTitle(row['title']);
    if (title.isEmpty ||
        blocked(title) ||
        !RegExp(
          r'football|soccer|\bvs\b|versus|مبارا|ضد|كرة|كأس|كاس|دوري|دورى|league|cup|uefa|fifa|nba',
          caseSensitive: false,
        ).hasMatch(title))
      continue;
    result.add(
      SportsProgramme(channel: channel, title: title, start: start, end: end),
    );
  }
  return result;
}
