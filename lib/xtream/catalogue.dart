import 'models.dart';
import 'content_filter.dart';

class ParsedCatalogue {
  final List<MediaCategory> categories;
  final List<MediaEntry> raw, allowed;
  final Set<String> blocked, manual;
  ParsedCatalogue(
    this.categories,
    this.raw,
    this.allowed,
    this.blocked,
    this.manual,
  );
}

/// Runs on a worker isolate for large subscriptions, including keyword checks.
ParsedCatalogue parseCatalogue(Map<String, Object> data) {
  final kind = MediaKind.values[data['kind'] as int];
  final categories = (data['categories'] as List)
      .whereType<Map>()
      .map(MediaCategory.json)
      .where((c) => c.id.isNotEmpty)
      .toList();
  final seen = <String>{};
  final raw = (data['streams'] as List)
      .whereType<Map>()
      .map((m) => MediaEntry.json(kind, m))
      .where((m) => m.id.isNotEmpty && seen.add(m.id))
      .toList();
  final manual = (data['manual'] as List<String>).toSet();
  final policy = ContentFilter();
  final blocked = policy.blockedCategories(kind, categories, manual);
  final allowed = raw
      .where((m) => policy.allows(m, blocked, manual))
      .toList(growable: false);
  return ParsedCatalogue(categories, raw, allowed, blocked, manual);
}
