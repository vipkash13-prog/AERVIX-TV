import 'models.dart';

/// Central policy: applied to categories, catalogue, search, favourites and episodes.
class ContentFilter {
  static final _arabicMarks = RegExp('[\u064B-\u065F\u0670\u0640]');
  static final _labels = RegExp(
    r'(^|[^a-z0-9])(adults?|adulto|adulte|erotik|porno|xxx+|porn(?:ography|ographic)?|p0rn|sex(?:y|ual)?|erotic(?:a)?|brazzers|hustler|playboy|penthouse|red[\s_-]*light|onlyfans|vixen|21\s*\+|18\s*\+|\+\s*18|\[?18\s*plus\]?)(?=$|[^a-z0-9])',
    caseSensitive: false,
  );
  static final _arabic = RegExp(
    'اباح|للكبار|للبالغين|بورن|سكس|جنس(?:ي|ية)?|عري|افلام الكبار',
  );
  static String normalize(String value) => value
      .toLowerCase()
      .replaceAll(_arabicMarks, '')
      .replaceAll(RegExp('[أإآ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('＋', '+')
      .replaceAll('١٨', '18')
      .replaceAll('۱۸', '18');
  bool nameBlocked(String name) {
    final value = normalize(name);
    return _labels.hasMatch(value) || _arabic.hasMatch(value);
  }

  Set<String> blockedCategories(
    MediaKind kind,
    List<MediaCategory> categories,
    Set<String> manual,
  ) {
    final blocked = categories
        .where(
          (c) =>
              c.adult ||
              nameBlocked(c.name) ||
              manual.contains('${kind.name}:category:${c.id}'),
        )
        .map((c) => c.id)
        .toSet();
    var changed = true;
    while (changed) {
      changed = false;
      for (final c in categories) {
        if (c.parent.isNotEmpty &&
            c.parent != '0' &&
            blocked.contains(c.parent) &&
            blocked.add(c.id))
          changed = true;
      }
    }
    return blocked;
  }

  bool allows(MediaEntry entry, Set<String> blocked, Set<String> manual) =>
      entry.id.isNotEmpty &&
      !entry.adult &&
      !nameBlocked(entry.name) &&
      !nameBlocked(entry.classification) &&
      !entry.categories.any(blocked.contains) &&
      !manual.contains('${entry.kind.name}:stream:${entry.id}');
}
