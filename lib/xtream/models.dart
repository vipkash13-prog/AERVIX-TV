import 'dart:convert';

enum MediaKind { live, movie, series }

extension MediaKindLabel on MediaKind {
  String get label => switch (this) {
    MediaKind.live => 'البث المباشر',
    MediaKind.movie => 'الأفلام',
    MediaKind.series => 'المسلسلات',
  };
  String get categoryAction => switch (this) {
    MediaKind.live => 'get_live_categories',
    MediaKind.movie => 'get_vod_categories',
    MediaKind.series => 'get_series_categories',
  };
  String get streamAction => switch (this) {
    MediaKind.live => 'get_live_streams',
    MediaKind.movie => 'get_vod_streams',
    MediaKind.series => 'get_series',
  };
}

class XtreamFailure implements Exception {
  final String message;
  const XtreamFailure(this.message);
  @override
  String toString() => message; // Never include authenticated URLs or server bodies.
}

class XtreamAccount {
  final Uri server;
  final String username, password;
  const XtreamAccount(this.server, this.username, this.password);
  factory XtreamAccount.input(
    String address,
    String username,
    String password,
  ) {
    final url = Uri.tryParse(address.trim());
    if (url == null ||
        !['http', 'https'].contains(url.scheme) ||
        url.host.isEmpty ||
        url.userInfo.isNotEmpty) {
      throw const XtreamFailure(
        'أدخل عنوان هوست صالحًا يبدأ بـ https:// أو http://',
      );
    }
    final user = username.trim().isNotEmpty
        ? username.trim()
        : url.queryParameters['username'] ?? '';
    final pass = password.isNotEmpty
        ? password
        : url.queryParameters['password'] ?? '';
    if (user.isEmpty || pass.isEmpty)
      throw const XtreamFailure('اسم المستخدم وكلمة المرور مطلوبان');
    final segments = url.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isNotEmpty &&
        ['get.php', 'player_api.php', 'xmltv.php'].contains(segments.last))
      segments.removeLast();
    return XtreamAccount(
      Uri(
        scheme: url.scheme,
        host: url.host,
        port: url.hasPort ? url.port : null,
        pathSegments: segments,
      ),
      user,
      pass,
    );
  }
  factory XtreamAccount.decode(String value) {
    final data = jsonDecode(value) as Map;
    return XtreamAccount.input(
      data['host'] as String,
      data['username'] as String,
      data['password'] as String,
    );
  }
  String encode() => jsonEncode({
    'host': server.toString(),
    'username': username,
    'password': password,
  });
  String get scope =>
      base64Url.encode(utf8.encode('${server.toString()}|$username'));
  Uri api([String? action, Map<String, String> extra = const {}]) =>
      server.replace(
        pathSegments: [
          ...server.pathSegments.where((s) => s.isNotEmpty),
          'player_api.php',
        ],
        queryParameters: {
          'username': username,
          'password': password,
          if (action != null) 'action': action,
          ...extra,
        },
      );
  Uri stream(MediaKind kind, String id, String extension) => Uri(
    scheme: server.scheme,
    host: server.host,
    port: server.hasPort ? server.port : null,
    pathSegments: [
      ...server.pathSegments.where((s) => s.isNotEmpty),
      switch (kind) {
        MediaKind.live => 'live',
        MediaKind.movie => 'movie',
        MediaKind.series => 'series',
      },
      username,
      password,
      '$id.$extension',
    ],
  );
  @override
  String toString() => 'XtreamAccount(<redacted>)';
}

bool adultFlag(dynamic value) =>
    value == true ||
    value == 1 ||
    value == '1' ||
    value?.toString().toLowerCase() == 'true';

class MediaCategory {
  final String id, name, parent;
  final bool adult;
  const MediaCategory(
    this.id,
    this.name, {
    this.parent = '',
    this.adult = false,
  });
  factory MediaCategory.json(Map data) => MediaCategory(
    '${data['category_id'] ?? ''}',
    '${data['category_name'] ?? ''}',
    parent: '${data['parent_id'] ?? ''}',
    adult: adultFlag(data['is_adult']) || adultFlag(data['adult']),
  );
}

class MediaEntry {
  final MediaKind kind;
  final String id, name, extension, artwork, classification;
  final List<String> categories;
  final bool adult;
  final int? number;
  const MediaEntry({
    required this.kind,
    required this.id,
    required this.name,
    this.categories = const [],
    this.extension = 'mp4',
    this.artwork = '',
    this.classification = '',
    this.adult = false,
    this.number,
  });
  String get key => '${kind.name}:$id';
  factory MediaEntry.json(MediaKind kind, Map data) {
    final category = data['category_ids'] is List
        ? (data['category_ids'] as List).map((x) => '$x').toList()
        : <String>[];
    if (data['category_id'] != null) category.add('${data['category_id']}');
    final ext =
        '${data['container_extension'] ?? (kind == MediaKind.live ? 'ts' : 'mp4')}';
    return MediaEntry(
      kind: kind,
      id: '${data[kind == MediaKind.series ? 'series_id' : 'stream_id'] ?? data['id'] ?? ''}',
      name: '${data['name'] ?? data['title'] ?? ''}',
      categories: category.toSet().toList(),
      extension: RegExp(r'^[a-zA-Z0-9]{1,8}$').hasMatch(ext)
          ? ext
          : (kind == MediaKind.live ? 'ts' : 'mp4'),
      artwork: '${data['stream_icon'] ?? data['cover'] ?? ''}',
      classification:
          '${data['genre'] ?? ''} ${data['genres'] ?? ''} ${data['content_rating'] ?? ''}',
      adult: adultFlag(data['is_adult']) || adultFlag(data['adult']),
      number: int.tryParse('${data['num']}'),
    );
  }
}

class MediaEpisode {
  final int season, order;
  final MediaEntry media;
  const MediaEpisode(this.season, this.order, this.media);
}
