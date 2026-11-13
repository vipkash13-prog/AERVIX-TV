import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'content_filter.dart';
import 'account_store.dart';
import 'catalogue.dart';
import 'sports_guide.dart';

Object? decodeXtream(String body) => jsonDecode(body);

class XtreamService extends ChangeNotifier {
  final AccountStore store;
  final SharedPreferences preferences;
  final http.Client _client;
  final ContentFilter filter = ContentFilter();
  final _categories = <MediaKind, List<MediaCategory>>{};
  static final _sportsName = RegExp(
    r'sport|bein|\bssc\b|رياض|الكاس|alkass',
    caseSensitive: false,
  );
  Set<String> _sportsCategoryIds = {};
  final _raw = <MediaKind, List<MediaEntry>>{};
  final _allowed = <MediaKind, List<MediaEntry>>{};
  final _allowedIds = <MediaKind, Set<String>>{};
  final _blockedCategories = <MediaKind, Set<String>>{};
  final _generations = <MediaKind, int>{};
  final _loading = <MediaKind>{};
  final _errors = <MediaKind, String>{};
  Set<String> _manual = {}, _favourites = {}, _automatic = {};
  Set<String> get _policyBlocks => {..._manual, ..._automatic};
  XtreamAccount? _account;
  String? storageError;
  bool _disposed = false;
  int _accountGeneration = 0;
  late final Future<void> ready;
  XtreamService(this.store, this.preferences, {http.Client? client})
    : _client = client ?? http.Client() {
    ready = _load();
  }
  int get accountRevision => _accountGeneration;
  bool get configured => _account != null;
  String? get host => _account?.server.toString();
  Set<String> get manualBlocks => Set.unmodifiable(_manual);
  bool loading(MediaKind kind) => _loading.contains(kind);
  bool loaded(MediaKind kind) => _raw.containsKey(kind);
  String? error(MediaKind kind) => _errors[kind];
  String _key(String part) => 'aervix.xtream.${_account!.scope}.$part';
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _load() async {
    try {
      _account = await store.read();
      _readLists();
    } catch (_) {
      storageError =
          'تعذر قراءة الاشتراك المحفوظ. أعد المحاولة دون حذف التطبيق.';
    }
    _notify();
  }

  void _readLists() {
    if (_account == null) return;
    _manual = (preferences.getStringList(_key('blocked')) ?? []).toSet();
    _automatic = (preferences.getStringList(_key('automatic')) ?? []).toSet();
    _favourites = (preferences.getStringList(_key('favourites')) ?? []).toSet();
  }

  Future<Object?> _request(
    XtreamAccount account, {
    String? action,
    Map<String, String> extra = const {},
  }) async {
    try {
      final response = await _client
          .get(account.api(action, extra))
          .timeout(const Duration(seconds: 18));
      if (response.statusCode != 200)
        throw const XtreamFailure(
          'تعذر الاتصال بالهوست. تحقق من الاتصال وصلاحية الاشتراك.',
        );
      final body = utf8.decode(response.bodyBytes);
      return body.length > 65536
          ? await compute(decodeXtream, body)
          : jsonDecode(body);
    } on XtreamFailure {
      rethrow;
    } catch (_) {
      throw const XtreamFailure('تعذر تحميل المحتوى من الهوست. حاول مجددًا.');
    }
  }

  Future<void> save(String address, String user, String password) async {
    final account = XtreamAccount.input(address, user, password);
    final response = await _request(account);
    if (response is! Map || response['user_info'] is! Map)
      throw const XtreamFailure(
        'الهوست لا يدعم Xtream Codes أو لم يُرجع بيانات اشتراك صالحة.',
      );
    final info = response['user_info'] as Map;
    if (!adultFlag(info['auth']) ||
        (info['status'] != null &&
            '${info['status']}'.toLowerCase() != 'active'))
      throw const XtreamFailure('الاشتراك غير نشط أو بيانات الدخول غير صحيحة.');
    try {
      await store.write(account);
    } catch (_) {
      throw const XtreamFailure(
        'تعذر حفظ الاشتراك بأمان. لم تتغير البيانات القديمة.',
      );
    }
    _account = account;
    storageError = null;
    _accountGeneration++;
    _categories.clear();
    _sportsCategoryIds.clear();
    _raw.clear();
    _allowed.clear();
    _allowedIds.clear();
    _blockedCategories.clear();
    _loading.clear();
    _errors.clear();
    _readLists();
    _notify();
  }

  Future<void> refresh(MediaKind kind) async {
    await ready;
    final account = _account;
    if (account == null || _disposed) return;
    final generation = (_generations[kind] ?? 0) + 1;
    _generations[kind] = generation;
    final scope = _accountGeneration;
    _loading.add(kind);
    _errors.remove(kind);
    _notify();
    try {
      final results = await Future.wait([
        _request(account, action: kind.categoryAction),
        _request(account, action: kind.streamAction),
      ]);
      if (results.any((r) => r is! List))
        throw const XtreamFailure(
          'استجابة تصنيفات أو محتوى غير صالحة من الهوست.',
        );
      if (_disposed ||
          scope != _accountGeneration ||
          _generations[kind] != generation)
        return;
      final payload = <String, Object>{
        'kind': kind.index,
        'categories': results[0] as List,
        'streams': results[1] as List,
        'manual': _policyBlocks.toList(),
      };
      final parsed = (results[1] as List).length >= 500
          ? await compute(parseCatalogue, payload)
          : parseCatalogue(payload);
      if (_disposed ||
          scope != _accountGeneration ||
          _generations[kind] != generation)
        return;
      _categories[kind] = parsed.categories;
      if (kind == MediaKind.live)
        _sportsCategoryIds = parsed.categories
            .where((c) => _sportsName.hasMatch(ContentFilter.normalize(c.name)))
            .map((c) => c.id)
            .toSet();
      _raw[kind] = parsed.raw;
      if (!setEquals(parsed.manual, _policyBlocks)) {
        _apply(kind);
      } else {
        _allowed[kind] = parsed.allowed;
        _allowedIds[kind] = parsed.allowed.map((m) => m.id).toSet();
        _blockedCategories[kind] = parsed.blocked;
      }
    } catch (error) {
      if (scope == _accountGeneration && _generations[kind] == generation)
        _errors[kind] = error is XtreamFailure
            ? error.message
            : 'تعذر تحديث المحتوى';
    } finally {
      if (!_disposed &&
          scope == _accountGeneration &&
          _generations[kind] == generation) {
        _loading.remove(kind);
        _notify();
      }
    }
  }

  void _apply(MediaKind kind) {
    final blocked = filter.blockedCategories(
      kind,
      _categories[kind] ?? [],
      _policyBlocks,
    );
    _blockedCategories[kind] = blocked;
    _allowed[kind] = (_raw[kind] ?? [])
        .where((m) => filter.allows(m, blocked, _policyBlocks))
        .toList(growable: false);
    _allowedIds[kind] = _allowed[kind]!.map((m) => m.id).toSet();
  }

  List<MediaCategory> categories(MediaKind kind) => (_categories[kind] ?? [])
      .where((c) => !(_blockedCategories[kind] ?? {}).contains(c.id))
      .toList();
  List<MediaEntry> items(
    MediaKind kind, {
    String? category,
    String query = '',
    bool favourites = false,
  }) {
    final search = ContentFilter.normalize(query.trim());
    return (_allowed[kind] ?? [])
        .where(
          (m) =>
              (category == null || m.categories.contains(category)) &&
              (!favourites || _favourites.contains(m.key)) &&
              (search.isEmpty ||
                  ContentFilter.normalize(m.name).contains(search)),
        )
        .toList(growable: false);
  }

  bool isAllowed(MediaEntry media) =>
      filter.allows(
        media,
        _blockedCategories[media.kind] ?? {},
        _policyBlocks,
      ) &&
      (_allowedIds[media.kind] ?? {}).contains(media.id);
  bool favourite(MediaEntry media) =>
      isAllowed(media) && _favourites.contains(media.key);
  Future<void> toggleFavourite(MediaEntry media) async {
    if (!isAllowed(media)) return;
    if (!_favourites.add(media.key)) _favourites.remove(media.key);
    await preferences.setStringList(_key('favourites'), _favourites.toList());
    _notify();
  }

  Future<void> block(MediaKind kind, String id, {bool category = false}) async {
    _manual.add('${kind.name}:${category ? 'category' : 'stream'}:$id');
    _apply(kind);
    _favourites.removeWhere(
      (key) =>
          key.startsWith('${kind.name}:') &&
          !(_allowed[kind] ?? []).any((m) => m.key == key),
    );
    await preferences.setStringList(_key('blocked'), _manual.toList());
    await preferences.setStringList(_key('favourites'), _favourites.toList());
    _notify();
  }

  Future<void> unblock(String key) async {
    _manual.remove(key);
    for (final kind in MediaKind.values) {
      _apply(kind);
    }
    await preferences.setStringList(_key('blocked'), _manual.toList());
    _notify();
  }

  bool episodeAllowed(MediaEntry episode, MediaEntry? parent) =>
      parent != null &&
      parent.kind == MediaKind.series &&
      episode.kind == MediaKind.series &&
      isAllowed(parent) &&
      filter.allows(
        episode,
        _blockedCategories[MediaKind.series] ?? {},
        _policyBlocks.where((key) => !key.startsWith('series:stream:')).toSet(),
      );

  bool isSports(MediaEntry media) =>
      media.kind == MediaKind.live &&
      isAllowed(media) &&
      (media.categories.any(_sportsCategoryIds.contains) ||
          _sportsName.hasMatch(ContentFilter.normalize(media.name)));

  Future<List<SportsProgramme>> sportsGuide({DateTime? now}) async {
    await ready;
    if (!configured || _disposed) return [];
    if (!loaded(MediaKind.live)) await refresh(MediaKind.live);
    final account = _account;
    final generation = _accountGeneration;
    if (account == null || _disposed) return [];
    final channels = items(MediaKind.live).where(isSports).take(4).toList();
    var failures = 0;
    final lists = await Future.wait(
      channels.map((channel) async {
        try {
          final data = await _request(
            account,
            action: 'get_short_epg',
            extra: {'stream_id': channel.id, 'limit': '12'},
          );
          return parseSportsGuide(
            data,
            channel,
            now ?? DateTime.now(),
            filter.nameBlocked,
          );
        } on XtreamFailure {
          failures++;
          return <SportsProgramme>[];
        }
      }),
    );
    if (_disposed || generation != _accountGeneration) return [];
    if (channels.isNotEmpty && failures == channels.length)
      throw const XtreamFailure('تعذر تحديث جدول المباريات من الاشتراك');
    final result = lists
        .expand((list) => list)
        .where((event) => isSports(event.channel))
        .toList();
    result.sort((a, b) => a.start.compareTo(b.start));
    return result;
  }

  Uri stream(MediaEntry media, {bool episode = false, MediaEntry? parent}) {
    if (_account == null) throw const XtreamFailure('لا يوجد اشتراك محفوظ');
    if (episode ? !episodeAllowed(media, parent) : !isAllowed(media))
      throw const XtreamFailure('المحتوى غير متاح أو محظور');
    return _account!.stream(media.kind, media.id, media.extension);
  }

  bool _adultDetails(Map data) {
    for (final section in [data, data['info'], data['movie_data']]) {
      if (section is! Map) continue;
      if (adultFlag(section['adult']) ||
          adultFlag(section['is_adult']) ||
          filter.nameBlocked(
            '${section['genre'] ?? ''} ${section['genres'] ?? ''} ${section['name'] ?? ''} ${section['content_rating'] ?? ''}',
          ))
        return true;
    }
    return false;
  }

  Future<void> _rememberAutomatic(MediaEntry item) async {
    _automatic.add('${item.kind.name}:stream:${item.id}');
    _apply(item.kind);
    _notify();
    await preferences.setStringList(_key('automatic'), _automatic.toList());
  }

  Future<bool> checkMovie(MediaEntry movie) async {
    if (movie.kind != MediaKind.movie || !isAllowed(movie)) return false;
    final generation = _accountGeneration;
    final details = await _request(
      _account!,
      action: 'get_vod_info',
      extra: {'vod_id': movie.id},
    );
    if (_disposed || generation != _accountGeneration || !isAllowed(movie))
      return false;
    if (details is! Map)
      throw const XtreamFailure('تعذر التحقق من تفاصيل الفيلم');
    if (_adultDetails(details)) {
      await _rememberAutomatic(movie);
      return false;
    }
    return true;
  }

  Future<List<MediaEpisode>> episodes(MediaEntry series) async {
    if (!isAllowed(series)) return [];
    final account = _account!;
    final generation = _accountGeneration;
    final data = await _request(
      account,
      action: 'get_series_info',
      extra: {'series_id': series.id},
    );
    if (_disposed || generation != _accountGeneration || !isAllowed(series))
      return [];
    if (data is! Map || data['episodes'] is! Map)
      throw const XtreamFailure('لا توجد حلقات متاحة لهذا المسلسل');
    if (_adultDetails(data)) {
      await _rememberAutomatic(series);
      return [];
    }
    final result = <MediaEpisode>[];
    for (final season in (data['episodes'] as Map).entries) {
      if (season.value is! List) continue;
      for (final raw in (season.value as List).whereType<Map>()) {
        final metadata = raw['info'];
        final entry = MediaEntry.json(MediaKind.series, {
          ...raw,
          'series_id': raw['id'],
          'name': raw['title'] ?? 'الحلقة ${raw['episode_num'] ?? ''}',
          'category_ids': series.categories,
          'is_adult':
              adultFlag(raw['is_adult']) ||
              (metadata is Map &&
                  (adultFlag(metadata['is_adult']) ||
                      adultFlag(metadata['adult']))),
        });
        if (episodeAllowed(entry, series))
          result.add(
            MediaEpisode(
              int.tryParse('${raw['season'] ?? season.key}') ?? 0,
              int.tryParse('${raw['episode_num']}') ?? result.length,
              entry,
            ),
          );
      }
    }
    result.sort((a, b) {
      final c = a.season.compareTo(b.season);
      return c != 0 ? c : a.order.compareTo(b.order);
    });
    return result;
  }

  @override
  void dispose() {
    _disposed = true;
    _client.close();
    super.dispose();
  }
}
