import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart' show DateFormat;
import 'settings/settings_panel.dart';
import 'gold_focus_tile.dart';
import 'installed_app_icon.dart';
import 'design_asset_icon.dart';
import 'aervix_update_button.dart';
import 'reference_chrome.dart';
import 'reference_dock.dart';
import '../xtream/models.dart';
import '../xtream/xtream_service.dart';
import '../xtream/account_dialog.dart';
import '../xtream/browser_page.dart';
import '../build_flags.dart';
import 'package:provider/provider.dart';
import '../flauncher_channel.dart';
import '../models/app.dart';
import '../providers/apps_service.dart';

export 'gold_focus_tile.dart';

/// A static background and inexpensive focus effects keep TV rendering light.
class AervixHome extends StatefulWidget {
  final http.Client? client;
  final DateTime Function()? clock;
  const AervixHome({super.key, this.client, this.clock});
  @override
  State<AervixHome> createState() => _AervixHomeState();
}

class _AervixHomeState extends State<AervixHome> with WidgetsBindingObserver {
  late final http.Client _client;
  Timer? _clockTimer;
  Timer? _weatherTimer;
  DateTime _now = DateTime.now();
  Map<String, dynamic>? _weather;
  Map<String, dynamic>? _prayers;
  String? _prayerDate;
  bool _weatherFailed = false;
  bool _prayersFailed = false;
  bool _fetching = false;
  final _navFocus = List.generate(
    7,
    (i) => FocusNode(debugLabel: 'navigation-$i'),
  );
  final _heroFocus = List.generate(3, (i) => FocusNode(debugLabel: 'hero-$i'));
  final _headerFocus = List.generate(
    7,
    (i) => FocusNode(debugLabel: 'header-$i'),
  );
  final _dockFocus = FocusNode(debugLabel: 'dock-first');
  final _allAppsFocus = FocusNode(debugLabel: 'dock-all-apps');
  DateTime get _riyadhNow => _now.toUtc().add(const Duration(hours: 3));

  @override
  void initState() {
    super.initState();
    _now = widget.clock?.call() ?? DateTime.now();
    _client = widget.client ?? http.Client();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      setState(() => _now = widget.clock?.call() ?? DateTime.now());
      if (_prayerDate != _date) _refresh();
    });
    _weatherTimer = Timer.periodic(
      const Duration(minutes: 30),
      (_) => _refresh(),
    );
  }

  String get _date => DateFormat(
    'dd-MM-yyyy',
  ).format(_now.toUtc().add(const Duration(hours: 3)));

  Future<void> _refresh() async {
    if (_fetching) return;
    _fetching = true;
    final date = _date;
    try {
      await Future.wait([
        () async {
          try {
            final response = await _client
                .get(
                  Uri.https('api.open-meteo.com', '/v1/forecast', {
                    'latitude': '21.4858',
                    'longitude': '39.1925',
                    'current':
                        'temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m,is_day',
                    'daily': 'temperature_2m_max,temperature_2m_min',
                    'forecast_days': '1',
                    'timezone': 'Asia/Riyadh',
                  }),
                )
                .timeout(const Duration(seconds: 12));
            if (response.statusCode != 200)
              throw const FormatException('weather');
            final decoded = jsonDecode(response.body);
            final current = Map<String, dynamic>.from(
              decoded['current'] as Map,
            );
            final daily = decoded['daily'];
            if (daily is Map) {
              for (final key in ['temperature_2m_max', 'temperature_2m_min']) {
                final values = daily[key];
                if (values is List && values.isNotEmpty)
                  current[key] = values.first;
              }
            }
            if (mounted)
              setState(() {
                _weather = current;
                _weatherFailed = false;
              });
          } catch (_) {
            if (mounted) setState(() => _weatherFailed = true);
          }
        }(),
        () async {
          if (_prayerDate == date && !_prayersFailed) return;
          try {
            final response = await _client
                .get(
                  Uri.https('api.aladhan.com', '/v1/timings/$date', {
                    'latitude': '21.4858',
                    'longitude': '39.1925',
                    'method': '4',
                    'timezonestring': 'Asia/Riyadh',
                  }),
                )
                .timeout(const Duration(seconds: 12));
            if (response.statusCode != 200)
              throw const FormatException('prayers');
            final data = jsonDecode(response.body)['data'];
            final timings = Map<String, dynamic>.from(data['timings'] as Map);
            if (mounted)
              setState(() {
                _prayers = timings;
                _prayerDate = date;
                _prayersFailed = false;
              });
          } catch (_) {
            if (mounted) setState(() => _prayersFailed = true);
          }
        }(),
      ]);
    } finally {
      _fetching = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() => _now = widget.clock?.call() ?? DateTime.now());
      _refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockTimer?.cancel();
    _weatherTimer?.cancel();
    _client.close();
    for (final node in [
      ..._navFocus,
      ..._heroFocus,
      ..._headerFocus,
      _dockFocus,
      _allAppsFocus,
    ]) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح التطبيق أو الإعدادات')),
        );
    }
  }

  void _showApps(String title, List<App> apps) {
    showDialog<void>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 700,
            height: 360,
            child: apps.isEmpty
                ? const Center(child: Text('لا توجد تطبيقات في هذه القائمة'))
                : GridView.builder(
                    itemCount: apps.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                        ),
                    itemBuilder: (context, index) =>
                        _appTile(apps[index], autofocus: index == 0),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('رجوع'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _appTile(App app, {bool autofocus = false}) => GoldFocusTile(
    key: ValueKey(app.packageName),
    autofocus: autofocus,
    label: app.name,
    onPressed: () => _run(() => context.read<AppsService>().launchApp(app)),
    child: InstalledAppIcon(app: app),
  );

  List<App> _orderedDock(List<App> apps) {
    const priority = [
      ['apple', 'atve'],
      ['nuvio'],
      ['stremio'],
      ['shahid', 'mbc'],
      ['yacin'],
      ['videolan', 'vlc'],
      ['aiostream'],
      ['moviebox'],
    ];
    int rank(App app) {
      final value = '${app.name} ${app.packageName}'.toLowerCase();
      final i = priority.indexWhere((terms) => terms.any(value.contains));
      return i < 0 ? 100 : i;
    }

    final result = apps.where((a) => a.packageName != 'com.omeda.arc').toList();
    result.sort((a, b) {
      final value = rank(a).compareTo(rank(b));
      return value == 0 ? a.name.compareTo(b.name) : value;
    });
    return result;
  }

  Future<void> _openXtream(MediaKind kind) async {
    final service = context.read<XtreamService?>();
    if (service == null) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('اشتراك Xtream'),
          content: const Text('خدمة الاشتراك غير متاحة. أعد فتح التطبيق.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('رجوع'),
            ),
          ],
        ),
      );
      return;
    }
    await service.ready;
    if (!mounted) return;
    if (!service.configured && !await showXtreamAccount(context, service))
      return;
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => XtreamBrowserPage(service: service, kind: kind),
      ),
    );
  }

  void _navigate(int index, List<App> apps) {
    switch (index) {
      case 0:
        _heroFocus[0].requestFocus();
      case 1:
        _openXtream(MediaKind.live);
      case 2:
        _openXtream(MediaKind.movie);
      case 3:
        _openXtream(MediaKind.series);
      case 4:
        _showApps('الألعاب', apps.where((a) => a.isGame).toList());
      case 5:
        _showApps('جميع التطبيقات', apps);
      case 6:
        _settings();
    }
  }

  void _settings() =>
      showDialog<void>(context: context, builder: (_) => const SettingsPanel());
  String _number(dynamic value, {int decimals = 0}) =>
      value is num ? value.toStringAsFixed(decimals) : '—';
  String _temperature(dynamic value) => value is num
      ? value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1)
      : '—';
  String _prayerTime(String key) {
    if (_prayerDate != _date) return '—';
    final match = RegExp(r'^(\d{2}):(\d{2})').firstMatch('${_prayers?[key]}');
    if (match == null) return '—';
    final hour = int.parse(match[1]!) % 12;
    return '${(hour == 0 ? 12 : hour).toString().padLeft(2, '0')}:${match[2]}';
  }

  Future<void> _weatherDetails() async {
    var busy = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('طقس جدة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _weatherFailed
                    ? 'تعذر تحديث الطقس'
                    : _weather == null
                    ? 'جارٍ تحديث الطقس…'
                    : weatherDescription(
                        (_weather!['weather_code'] as num).toInt(),
                      ),
              ),
              Text('الحرارة: ${_temperature(_weather?['temperature_2m'])}°C'),
              Text('الرطوبة: ${_number(_weather?['relative_humidity_2m'])}%'),
              Text('الرياح: ${_number(_weather?['wind_speed_10m'])} كم/س'),
              const Text(
                'المصدر: Open-Meteo • توقيت الرياض',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('رجوع'),
            ),
            TextButton(
              autofocus: true,
              onPressed: busy
                  ? null
                  : () async {
                      update(() => busy = true);
                      await _refresh();
                      if (dialogContext.mounted) update(() => busy = false);
                    },
              child: Text(busy ? 'جارٍ التحديث…' : 'تحديث'),
            ),
          ],
        ),
      ),
    );
  }

  void _prayerDetails() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('مواقيت الصلاة في جدة'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final entry in const {
            'Fajr': 'الفجر',
            'Sunrise': 'الشروق',
            'Dhuhr': 'الظهر',
            'Asr': 'العصر',
            'Maghrib': 'المغرب',
            'Isha': 'العشاء',
          }.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(entry.value),
                  Text(
                    _prayerTime(entry.key),
                    textDirection: TextDirection.ltr,
                  ),
                ],
              ),
            ),
          Text(
            _prayersFailed ? 'تعذر تحديث المواقيت' : 'أم القرى • توقيت الرياض',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          autofocus: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('رجوع'),
        ),
      ],
    ),
  );

  KeyEventResult _headerKeys(KeyEvent event, int index) => referenceDirections(
    event,
    left: () => index == 0
        ? _navFocus[0].requestFocus()
        : _headerFocus[index - 1].requestFocus(),
    right: () => index < 6 ? _headerFocus[index + 1].requestFocus() : null,
    up: () {},
    down: () =>
        _heroFocus[index == 0
                ? 0
                : index == 1
                ? 1
                : 2]
            .requestFocus(),
  );

  Widget _place(Rect rect, Widget child, {Key? key}) => Positioned(
    key: key,
    left: rect.left,
    top: rect.top,
    width: rect.width,
    height: rect.height,
    child: child,
  );

  TextStyle _text(
    double size, {
    FontWeight weight = FontWeight.w700,
    Color color = Colors.white,
  }) => TextStyle(
    fontFamily: 'Cairo',
    fontSize: size,
    height: 1.12,
    fontWeight: weight,
    color: color,
  );

  Widget _weatherPanel() => ReferenceFocusable(
    focusNode: _headerFocus[0],
    label: 'طقس جدة وتحديث البيانات',
    onPressed: _weatherDetails,
    onKey: (event) => _headerKeys(event, 0),
    builder: (context, focused) => ReferenceGlass(
      radius: 25,
      focused: focused,
      child: Stack(
        children: [
          Positioned(
            left: 28,
            top: 10,
            child: Row(
              textDirection: TextDirection.ltr,
              children: [
                Text('جدة', style: _text(17)),
                const SizedBox(width: 4),
                const Icon(Icons.location_on, size: 16, color: referenceGold),
              ],
            ),
          ),
          Positioned(
            left: 27,
            top: 37,
            width: 124,
            height: 36,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '${_temperature(_weather?['temperature_2m'])}°C',
                textDirection: TextDirection.ltr,
                style: _text(30, weight: FontWeight.w800),
              ),
            ),
          ),
          Positioned(
            right: 7,
            top: 4,
            width: 91,
            height: 77,
            child: DesignAssetIcon(
              weatherAssetPath(
                (_weather?['weather_code'] as num?)?.toInt(),
                night:
                    _weather?['is_day'] == 0 ||
                    (_weather?['is_day'] == null &&
                        (_riyadhNow.hour < 6 || _riyadhNow.hour >= 18)),
              ),
              size: 89,
            ),
          ),
          const Positioned(
            left: 17,
            right: 17,
            top: 75,
            child: Divider(height: 1, color: Color(0x3FFFFFFF)),
          ),
          Positioned(
            left: 17,
            right: 12,
            bottom: 9,
            height: 21,
            child: Row(
              textDirection: TextDirection.ltr,
              children: [
                Expanded(
                  child: _stat(
                    Icons.air,
                    '${_number(_weather?['wind_speed_10m'])} كم/س',
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _stat(
                    Icons.water_drop_outlined,
                    '${_number(_weather?['relative_humidity_2m'])}%',
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _stat(
                    Icons.thermostat,
                    '${_number(_weather?['temperature_2m_max'])}° / ${_number(_weather?['temperature_2m_min'])}°',
                  ),
                ),
              ],
            ),
          ),
          if (_weatherFailed)
            const Positioned(
              left: 8,
              top: 8,
              child: Icon(Icons.cloud_off, size: 10, color: Color(0xFFFFD68A)),
            ),
        ],
      ),
    ),
  );

  Widget _stat(IconData icon, String value) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: Row(
      textDirection: TextDirection.ltr,
      children: [
        Icon(icon, size: 15, color: const Color(0xFFC7CDD7)),
        const SizedBox(width: 3),
        Text(
          value,
          style: _text(
            11,
            weight: FontWeight.w600,
            color: const Color(0xFFECEFF4),
          ),
        ),
      ],
    ),
  );

  Widget _prayerPanel() => ReferenceFocusable(
    focusNode: _headerFocus[1],
    label: 'مواقيت الصلاة',
    onPressed: _prayerDetails,
    onKey: (event) => _headerKeys(event, 1),
    builder: (context, focused) => ReferenceGlass(
      radius: 26,
      focused: focused,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 10, 13, 9),
        child: Column(
          children: [
            Row(
              textDirection: TextDirection.ltr,
              children: [
                const DesignAssetIcon(
                  'assets/prayer/icon_mosque.png',
                  size: 39,
                ),
                const Spacer(),
                Text('مواقيت الصلاة', style: _text(16)),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Row(
                children: [
                  for (final entry in const {
                    'Fajr': 'الفجر',
                    'Dhuhr': 'الظهر',
                    'Asr': 'العصر',
                    'Maghrib': 'المغرب',
                    'Isha': 'العشاء',
                  }.entries)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: ReferenceGlass(
                          radius: 10,
                          active:
                              _prayerDate == _date &&
                              entry.key == nextPrayerKey(_prayers ?? {}, _now),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 5,
                              horizontal: 2,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                FittedBox(
                                  child: Text(entry.value, style: _text(10.5)),
                                ),
                                FittedBox(
                                  child: Text(
                                    _prayerTime(entry.key),
                                    textDirection: TextDirection.ltr,
                                    style: _text(13.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _clockPanel() => ReferenceFocusable(
    focusNode: _headerFocus[6],
    label: 'الساعة والتاريخ',
    onPressed: () => _run(
      () => FLauncherChannel().launchActivityFromAction(
        'android.settings.DATE_SETTINGS',
      ),
    ),
    onKey: (event) => _headerKeys(event, 6),
    builder: (context, focused) => ReferenceGlass(
      radius: 20,
      focused: focused,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 7),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            FittedBox(
              child: Row(
                textDirection: TextDirection.ltr,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    DateFormat('hh:mm').format(_riyadhNow),
                    textDirection: TextDirection.ltr,
                    style: _text(30, weight: FontWeight.w800),
                  ),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      _riyadhNow.hour >= 12 ? 'م' : 'ص',
                      style: _text(14),
                    ),
                  ),
                ],
              ),
            ),
            FittedBox(
              child: Text(
                DateFormat('EEEE d MMMM yyyy', 'ar').format(_riyadhNow),
                style: _text(10, weight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _topButton(
    int index,
    String label,
    IconData icon,
    VoidCallback action, {
    bool busy = false,
    bool badge = false,
  }) => ReferenceFocusable(
    focusNode: _headerFocus[index],
    label: label,
    onPressed: action,
    onKey: (event) => _headerKeys(event, index),
    builder: (context, focused) => Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: ReferenceGlass(
            radius: 17,
            focused: focused,
            child: Center(
              child: busy
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: referenceGold,
                      ),
                    )
                  : Icon(
                      icon,
                      size: index == 5 ? 28 : 25,
                      color: const Color(0xFFE7EAF1),
                    ),
            ),
          ),
        ),
        if (badge)
          Positioned(
            top: -3,
            right: 1,
            child: Container(
              width: 12,
              height: 14,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('1', style: _text(8)),
            ),
          ),
      ],
    ),
  );

  Widget _hero(
    int index,
    String title,
    String subtitle,
    String art,
    List<App> apps, {
    int skew = 0,
    bool live = false,
  }) => ReferenceFocusable(
    focusNode: _heroFocus[index],
    label: title,
    onPressed: () => _openXtream(
      index == 0
          ? MediaKind.movie
          : index == 1
          ? MediaKind.series
          : MediaKind.live,
    ),
    onKey: (event) => referenceDirections(
      event,
      left: () => index == 0
          ? _navFocus[0].requestFocus()
          : _heroFocus[index - 1].requestFocus(),
      right: () => index < 2 ? _heroFocus[index + 1].requestFocus() : null,
      up: () =>
          _headerFocus[index == 0
                  ? 0
                  : index == 1
                  ? 1
                  : 6]
              .requestFocus(),
      down: () => _dockFocus.requestFocus(),
    ),
    builder: (context, focused) => ReferenceGlass(
      hero: true,
      skew: skew,
      radius: 27,
      focused: focused,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              art,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              cacheWidth:
                  MediaQuery.sizeOf(context).width *
                          MediaQuery.devicePixelRatioOf(context) >=
                      3000
                  ? 1024
                  : 512,
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.transparent,
                    Color(0x20000000),
                    Color(0x8D010307),
                  ],
                  stops: [0, .55, 1],
                ),
              ),
            ),
          ),
          Positioned(
            right: 69,
            bottom: 22,
            width: 153,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(title, style: _text(22, weight: FontWeight.w800)),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: _text(
                    13,
                    weight: FontWeight.w400,
                    color: const Color(0xFFDDDAD1),
                  ),
                ),
              ],
            ),
          ),
          const Positioned(right: 22, bottom: 29, child: ReferencePlayGlyph()),
          if (live)
            Positioned(
              right: 23,
              top: 43,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFED0613),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('مباشر', style: _text(10)),
                    const SizedBox(width: 4),
                    const Icon(Icons.circle, size: 5, color: Colors.white),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _navigation(List<App> apps) {
    const titles = [
      'الرئيسية',
      'البث المباشر',
      'الأفلام',
      'المسلسلات',
      'الألعاب',
      'التطبيقات',
      'الإعدادات',
    ];
    const icons = [
      Icons.home_outlined,
      Icons.live_tv_outlined,
      Icons.movie_filter_outlined,
      Icons.movie_outlined,
      Icons.sports_esports_outlined,
      Icons.grid_view_rounded,
      Icons.settings_outlined,
    ];
    return Stack(
      children: [
        const Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(painter: ReferenceSidebarPainter()),
          ),
        ),
        const Positioned(
          left: 64,
          top: 12,
          width: 100,
          height: 76,
          child: Image(
            image: AssetImage('assets/branding/logo_aervix.png'),
            fit: BoxFit.contain,
          ),
        ),
        Positioned(
          left: 13,
          top: 85,
          width: 188,
          height: 26,
          child: FittedBox(
            child: Text(
              'AERVIX TV',
              textDirection: TextDirection.ltr,
              style: _text(
                27,
                weight: FontWeight.w800,
                color: const Color(0xFFE5E6EC),
              ),
            ),
          ),
        ),
        Positioned(
          left: 30,
          top: 115,
          width: 158,
          height: 16,
          child: Center(
            child: Text(
              'ترفيه منزلي ذكي',
              style: _text(9.5, weight: FontWeight.w600),
            ),
          ),
        ),
        for (var i = 0; i < titles.length; i++)
          Positioned(
            left: 20,
            top: ReferenceLayout.navigationY[i],
            width: 180,
            height: 53,
            child: ReferenceFocusable(
              key: ValueKey('navigation-$i'),
              focusNode: _navFocus[i],
              autofocus: i == 0,
              label: titles[i],
              onPressed: () => _navigate(i, apps),
              onKey: (event) => referenceDirections(
                event,
                up: () => i > 0 ? _navFocus[i - 1].requestFocus() : null,
                down: () => i < 6 ? _navFocus[i + 1].requestFocus() : null,
                left: () {},
                right: () => i == 5
                    ? _dockFocus.requestFocus()
                    : _heroFocus[i == 1
                              ? 2
                              : i == 3
                              ? 1
                              : 0]
                          .requestFocus(),
              ),
              builder: (context, focused) => ReferenceGlass(
                radius: 14,
                focused: focused,
                active: i == 0,
                minimal: true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    textDirection: TextDirection.ltr,
                    children: [
                      i == 2
                          ? Image.asset(
                              'assets/entertainment/icon_film_reel.png',
                              width: 29,
                              height: 29,
                              color: const Color(0xFFDBDFE8),
                              colorBlendMode: BlendMode.srcIn,
                            )
                          : Icon(
                              icons[i],
                              size: 29,
                              color: const Color(0xFFDBDFE8),
                            ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(titles[i], style: _text(16.5)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<AppsService>();
    final apps = service.applications.where((a) => !a.hidden).toList();
    final dockApps = _orderedDock(apps);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _navFocus[0].requestFocus();
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final physicalWidth =
                  constraints.maxWidth * MediaQuery.devicePixelRatioOf(context);
              return MediaQuery.withClampedTextScaling(
                minScaleFactor: .85,
                maxScaleFactor: 1.15,
                child: Focus(
                  onKeyEvent: (_, event) {
                    if (event is KeyDownEvent &&
                        [
                          LogicalKeyboardKey.escape,
                          LogicalKeyboardKey.goBack,
                          LogicalKeyboardKey.gameButtonB,
                        ].contains(event.logicalKey)) {
                      _navFocus[0].requestFocus();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: ReferenceLayout.canvas.width,
                        height: ReferenceLayout.canvas.height,
                        child: DefaultTextStyle(
                          style: _text(16),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: RepaintBoundary(
                                  child: Image.asset(
                                    ReferenceLayout.wallpaper(physicalWidth),
                                    fit: BoxFit.cover,
                                    cacheWidth: physicalWidth >= 3000
                                        ? 3840
                                        : 1920,
                                    filterQuality: FilterQuality.medium,
                                  ),
                                ),
                              ),
                              _place(
                                ReferenceLayout.sidebar,
                                _navigation(apps),
                                key: const ValueKey('reference-sidebar'),
                              ),
                              _place(
                                ReferenceLayout.weather,
                                _weatherPanel(),
                                key: const ValueKey('reference-weather'),
                              ),
                              _place(
                                ReferenceLayout.prayer,
                                _prayerPanel(),
                                key: const ValueKey('reference-prayer'),
                              ),
                              _place(
                                ReferenceLayout.clock,
                                _clockPanel(),
                                key: const ValueKey('reference-clock'),
                              ),
                              _place(
                                const Rect.fromLTWH(891, 39, 44, 40),
                                _topButton(
                                  2,
                                  'إعدادات الشبكة',
                                  Icons.wifi,
                                  () =>
                                      _run(FLauncherChannel().openWifiSettings),
                                ),
                              ),
                              _place(
                                const Rect.fromLTWH(949, 39, 43, 40),
                                _topButton(
                                  3,
                                  'إعدادات بلوتوث',
                                  Icons.bluetooth,
                                  () => _run(
                                    () => FLauncherChannel()
                                        .launchActivityFromAction(
                                          'android.settings.BLUETOOTH_SETTINGS',
                                        ),
                                  ),
                                ),
                              ),
                              _place(
                                const Rect.fromLTWH(1006, 39, 43, 40),
                                kEnableSelfUpdater
                                    ? AervixUpdateButton(
                                        builder:
                                            (
                                              context,
                                              busy,
                                              available,
                                              action,
                                            ) => _topButton(
                                              4,
                                              'تحديثات التطبيق',
                                              Icons.notifications_none,
                                              action,
                                              busy: busy,
                                              badge: available,
                                            ),
                                      )
                                    : _topButton(
                                        4,
                                        'إعدادات الإشعارات',
                                        Icons.notifications_none,
                                        () => _run(
                                          () => FLauncherChannel()
                                              .launchActivityFromAction(
                                                'android.settings.NOTIFICATION_SETTINGS',
                                              ),
                                        ),
                                      ),
                              ),
                              _place(
                                const Rect.fromLTWH(1061, 39, 39, 40),
                                _topButton(
                                  5,
                                  'إعدادات الحساب والجهاز',
                                  Icons.person_outline,
                                  () => _run(FLauncherChannel().openSettings),
                                ),
                              ),
                              _place(
                                ReferenceLayout.movies,
                                _hero(
                                  0,
                                  'الأفلام',
                                  'عالم السينما',
                                  'assets/reference_ui/movies_art.png',
                                  apps,
                                  skew: -1,
                                ),
                                key: const ValueKey('reference-movies'),
                              ),
                              _place(
                                ReferenceLayout.series,
                                _hero(
                                  1,
                                  'المسلسلات',
                                  'عروض ومسلسلات',
                                  'assets/reference_ui/series_art.png',
                                  apps,
                                ),
                                key: const ValueKey('reference-series'),
                              ),
                              _place(
                                ReferenceLayout.live,
                                _hero(
                                  2,
                                  'البث المباشر',
                                  'قنوات مباشرة',
                                  'assets/reference_ui/live_art.png',
                                  apps,
                                  skew: 1,
                                  live: true,
                                ),
                                key: const ValueKey('reference-live'),
                              ),
                              _place(
                                ReferenceLayout.dock,
                                ReferenceDock(
                                  apps: dockApps,
                                  onLaunch: (app) =>
                                      _run(() => service.launchApp(app)),
                                  onAllApps: () =>
                                      _showApps('جميع التطبيقات', apps),
                                  onLeftBoundary: () =>
                                      _navFocus[0].requestFocus(),
                                  firstFocus: _dockFocus,
                                  allAppsFocus: _allAppsFocus,
                                  onUp: (x) {
                                    final distances = [
                                      (x - 400).abs(),
                                      (x - 733).abs(),
                                      (x - 1075).abs(),
                                    ];
                                    var nearest = 0;
                                    for (var i = 1; i < 3; i++) {
                                      if (distances[i] < distances[nearest])
                                        nearest = i;
                                    }
                                    _heroFocus[nearest].requestFocus();
                                  },
                                ),
                                key: const ValueKey('applications-band'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

String? nextPrayerKey(Map<String, dynamic> timings, DateTime instant) {
  final riyadh = instant.toUtc().add(const Duration(hours: 3));
  final minutes = riyadh.hour * 60 + riyadh.minute;
  const prayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
  for (final key in prayers) {
    final match = RegExp(r'^(\d{2}):(\d{2})').firstMatch('${timings[key]}');
    if (match == null) continue;
    final time = int.parse(match[1]!) * 60 + int.parse(match[2]!);
    if (time > minutes) return key;
  }
  return timings.containsKey('Fajr') ? 'Fajr' : null;
}

String weatherDescription(int code) {
  if (code == 0) return 'سماء صافية';
  if (code <= 3) return 'غائم جزئيًا';
  if (code <= 48) return 'ضباب';
  if (code <= 67 || (code >= 80 && code <= 82)) return 'أمطار';
  if (code >= 95) return 'عواصف رعدية';
  return 'طقس متغير';
}
