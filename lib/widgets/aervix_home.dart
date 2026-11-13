import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart' show DateFormat;
import 'settings/settings_panel.dart';
import 'design_asset_icon.dart';
import 'premium_glass.dart';
import 'installed_app_icon.dart';
import 'aervix_update_button.dart';
import 'reference_chrome.dart';
import 'reference_dock.dart';
import '../providers/dock_favourites.dart';
import 'dock_favourites_editor.dart';
import 'dock_app_actions.dart';
import '../xtream/models.dart';
import '../xtream/xtream_service.dart';
import '../xtream/account_dialog.dart';
import '../xtream/browser_page.dart';
import '../xtream/player_page.dart';
import '../xtream/sports_guide.dart';
import '../build_flags.dart';
import 'package:provider/provider.dart';
import '../flauncher_channel.dart';
import '../models/app.dart';
import '../providers/apps_service.dart';
import '../providers/network_service.dart';
import '../providers/home_preferences.dart';

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
  String _hijriLabel = 'التاريخ الهجري —';
  String _hijriEnglishLabel = 'Hijri date —';
  String? _hijriDate;
  VoidCallback? _updateAction;
  final _allAppsFocus = FocusNode(debugLabel: 'all-apps');
  String? _prayerDate;
  bool _weatherFailed = false;
  bool _prayersFailed = false;
  bool _fetching = false;
  final _navFocus = List.generate(
    5,
    (i) => FocusNode(debugLabel: 'navigation-$i'),
  );
  final _headerFocus = List.generate(
    10,
    (i) => FocusNode(debugLabel: 'header-$i'),
  );
  final _dockFocus = FocusNode(debugLabel: 'dock-first');
  final _lastSlotFocus = FocusNode(debugLabel: 'dock-last');
  List<SportsProgramme> _sports = [];
  int _sportsIndex = 0, _sportsRevision = -1, _requestedSportsRevision = -1;
  bool _loadingSports = false, _sportsFailed = false;
  bool _openingCatalogue = false, _openingSports = false;
  FocusNode? _lastDockFocus;
  HomePreferences? _homePreferences;
  bool _pendingRefresh = false;
  int _locationGeneration = 0;
  String _cityId = 'jeddah';
  HomeCity get _city => _homePreferences?.city ?? HomePreferences.cities.first;
  bool get _english => _homePreferences?.language == 'en';
  String _l(String ar, String en) => _english ? en : ar;
  DateTime get _riyadhNow => _now.toUtc().add(const Duration(hours: 3));

  @override
  void initState() {
    super.initState();
    _now = widget.clock?.call() ?? DateTime.now();
    _client = widget.client ?? http.Client();
    WidgetsBinding.instance.addObserver(this);
    _homePreferences = context.read<HomePreferences?>();
    _cityId = _city.id;
    _homePreferences?.addListener(_preferencesChanged);
    _refresh();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      setState(() => _now = widget.clock?.call() ?? DateTime.now());
      if (_prayerDate != _date) _refresh();
    });
    _weatherTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      _refresh();
      _loadSports();
    });
  }

  String get _date => DateFormat(
    'dd-MM-yyyy',
  ).format(_now.toUtc().add(const Duration(hours: 3)));

  void _preferencesChanged() {
    if (!mounted) return;
    if (_cityId != _city.id) {
      _cityId = _city.id;
      _locationGeneration++;
      _weather = null;
      _prayers = null;
      _prayerDate = null;
      _hijriDate = null;
      _weatherFailed = false;
      _prayersFailed = false;
      unawaited(_refresh());
    }
    setState(() {});
  }

  Future<void> _refresh() async {
    if (_fetching) {
      _pendingRefresh = true;
      return;
    }
    _fetching = true;
    final date = _date;
    final generation = _locationGeneration;
    final city = _city;
    try {
      await Future.wait([
        () async {
          try {
            final response = await _client
                .get(
                  Uri.https('api.open-meteo.com', '/v1/forecast', {
                    'latitude': city.latitude,
                    'longitude': city.longitude,
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
            if (mounted && generation == _locationGeneration)
              setState(() {
                _weather = current;
                _weatherFailed = false;
              });
          } catch (_) {
            if (mounted && generation == _locationGeneration)
              setState(() => _weatherFailed = true);
          }
        }(),
        () async {
          if (_prayerDate == date && !_prayersFailed) return;
          try {
            final response = await _client
                .get(
                  Uri.https('api.aladhan.com', '/v1/timings/$date', {
                    'latitude': city.latitude,
                    'longitude': city.longitude,
                    'method': '4',
                    'timezonestring': 'Asia/Riyadh',
                  }),
                )
                .timeout(const Duration(seconds: 12));
            if (response.statusCode != 200)
              throw const FormatException('prayers');
            final data = jsonDecode(response.body)['data'];
            final timings = Map<String, dynamic>.from(data['timings'] as Map);
            if (mounted && generation == _locationGeneration)
              setState(() {
                _prayers = timings;
                final hijri = data['date']?['hijri'];
                _hijriLabel = hijri is Map
                    ? '${hijri['day']} ${hijri['month']?['ar'] ?? ''} ${hijri['year']} هـ'
                    : 'التاريخ الهجري —';
                _hijriEnglishLabel = hijri is Map
                    ? '${hijri['day']} ${hijri['month']?['en'] ?? hijri['month']?['number'] ?? ''} ${hijri['year']} AH'
                    : 'Hijri date —';
                _hijriDate = date;
                _prayerDate = date;
                _prayersFailed = false;
              });
          } catch (_) {
            if (mounted && generation == _locationGeneration)
              setState(() => _prayersFailed = true);
          }
        }(),
      ]);
    } finally {
      _fetching = false;
      if (_pendingRefresh && mounted) {
        _pendingRefresh = false;
        unawaited(_refresh());
      }
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
    _homePreferences?.removeListener(_preferencesChanged);
    for (final node in [
      ..._navFocus,
      ..._headerFocus,
      _dockFocus,
      _lastSlotFocus,
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

  bool _editingDock = false;
  Future<void> _editDock() async {
    if (_editingDock) return;
    final store = context.read<DockFavourites?>();
    if (store == null) return;
    final apps = _orderedDock(
      context.read<AppsService>().applications.where((a) => !a.hidden).toList(),
    );
    _editingDock = true;
    try {
      await editDockFavourites(context, store, apps);
    } finally {
      _editingDock = false;
    }
    if (mounted) (_lastDockFocus ?? _dockFocus).requestFocus();
  }

  Future<void> _appOptions(App app) async {
    if (_editingDock) return;
    final store = context.read<DockFavourites?>();
    if (store == null) return;
    final service = context.read<AppsService>();
    final returnFocus = FocusManager.instance.primaryFocus;
    _editingDock = true;
    try {
      await editDockApp(context, app, store, service);
    } finally {
      _editingDock = false;
    }
    if (mounted && returnFocus?.context != null)
      returnFocus!.requestFocus();
    else if (mounted && ModalRoute.of(context)?.isCurrent == true)
      _dockFocus.requestFocus();
  }

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

  Future<void> _openXtream(
    MediaKind kind, {
    bool search = false,
    bool sports = false,
  }) async {
    if (_openingCatalogue) return;
    _openingCatalogue = true;
    try {
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
          builder: (_) => XtreamBrowserPage(
            service: service,
            kind: kind,
            focusSearch: search,
            sportsOnly: sports,
          ),
        ),
      );
    } finally {
      _openingCatalogue = false;
    }
  }

  void _navigate(int index, List<App> apps) {
    switch (index) {
      case 0:
        _openXtream(MediaKind.live, sports: true);
      case 1:
        _openXtream(MediaKind.live);
      case 2:
        _openXtream(MediaKind.movie);
      case 3:
        _openXtream(MediaKind.series);
      case 4:
        _allApps();
    }
  }

  void _settings() => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(_l('الإعدادات', 'Settings')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_homePreferences != null) ...[
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _chooseLanguage();
              },
              child: Text(_l('لغة الواجهة', 'Interface language')),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _chooseCity();
              },
              child: Text(
                _l('المدينة للطقس والصلاة', 'Weather and prayer city'),
              ),
            ),
          ],
          TextButton(
            autofocus: true,
            onPressed: () {
              Navigator.pop(dialogContext);
              showDialog<void>(
                context: context,
                builder: (_) => const SettingsPanel(),
              );
            },
            child: Text(
              _l('إعدادات الواجهة والجهاز', 'Interface and device settings'),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final service = context.read<XtreamService?>();
              if (service != null) await showXtreamAccount(context, service);
            },
            child: Text(
              _l('تعديل اشتراك Xtream Codes', 'Xtream Codes account'),
            ),
          ),
          if (_updateAction != null)
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _updateAction!();
              },
              child: Text(_l('تحديث التطبيق', 'App update')),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('رجوع'),
          ),
        ],
      ),
    ),
  );
  Future<void> _chooseLanguage() async {
    final language = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('اللغة / Language'),
        children: [
          for (final code in ['ar', 'en'])
            TextButton(
              autofocus: code == (_homePreferences?.language ?? 'ar'),
              onPressed: () => Navigator.pop(context, code),
              child: Text(code == 'ar' ? 'العربية' : 'English'),
            ),
        ],
      ),
    );
    if (language != null) await _homePreferences?.setLanguage(language);
  }

  Future<void> _chooseCity() async {
    final city = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(_l('المدينة', 'City')),
        children: [
          for (final city in HomePreferences.cities)
            TextButton(
              autofocus: city.id == _city.id,
              onPressed: () => Navigator.pop(context, city.id),
              child: Text(_english ? city.en : city.ar),
            ),
        ],
      ),
    );
    if (city != null) await _homePreferences?.setCity(city);
  }

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
          title: Text(
            '${_l('طقس', 'Weather')} ${_english ? _city.en : _city.ar}',
          ),
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
      title: Text(
        '${_l('مواقيت الصلاة في', 'Prayer times in')} ${_english ? _city.en : _city.ar}',
      ),
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
    height: 1.18,
    fontWeight: weight,
    color: color,
  );
  String _westernDigits(String text) => String.fromCharCodes(
    text.runes.map(
      (r) => r >= 0x660 && r <= 0x669
          ? r - 0x660 + 48
          : r >= 0x6F0 && r <= 0x6F9
          ? r - 0x6F0 + 48
          : r,
    ),
  );
  String _translate(String text) {
    if (!_english) return text;
    final labels = {
      'البث المباشر': 'Live TV',
      'الأفلام': 'Movies',
      'المسلسلات': 'TV Series',
      'جميع التطبيقات': 'All apps',
      'التطبيقات': 'Apps',
      'مباريات اليوم': 'Today matches',
      'الفجر': 'Fajr',
      'الظهر': 'Dhuhr',
      'العصر': 'Asr',
      'المغرب': 'Maghrib',
      'العشاء': 'Isha',
      'تعذر التحديث': 'Update unavailable',
      'جارٍ التحديث': 'Updating…',
      'سماء صافية': 'Clear sky',
      'غائم جزئيًا': 'Partly cloudy',
      'ضباب': 'Fog',
      'أمطار': 'Rain',
      'عواصف رعدية': 'Thunderstorms',
      'طقس متغير': 'Variable weather',
      'التاريخ الهجري —': 'Hijri date —',
      'مواقيت الصلاة - ${_city.ar}': 'Prayer Times - ${_city.en}',
      _city.ar: _city.en,
    };
    return labels[text] ??
        text
            .replaceFirst('الرطوبة', 'Humidity')
            .replaceFirst('الرياح', 'Wind')
            .replaceFirst('كم/س', 'km/h');
  }

  Widget _fit(String text, double size, {Color color = Colors.white}) =>
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          _westernDigits(_translate(text)),
          textDirection: _english ? TextDirection.ltr : TextDirection.rtl,
          style: _text(size, color: color),
        ),
      );
  KeyEventResult _headerKeys(KeyEvent event, int index) {
    final row = index == 0 || index == 1 || index == 9
        ? [1, 0, 9]
        : [7, 5, 8, 4, 3, 6];
    final i = row.indexOf(index);
    return referenceDirections(
      event,
      left: () =>
          _headerFocus[row[(i - 1 + row.length) % row.length]].requestFocus(),
      right: () => index == 9
          ? _navFocus[0].requestFocus()
          : _headerFocus[row[(i + 1) % row.length]].requestFocus(),
      up: () => _headerFocus[7].requestFocus(),
      down: () => index == 0 || index == 1 || index == 9
          ? _dockFocus.requestFocus()
          : _navFocus[2].requestFocus(),
    );
  }

  Widget _plainPanel(
    int index,
    String label,
    VoidCallback activate,
    Widget child,
  ) => ReferenceFocusable(
    focusNode: _headerFocus[index],
    label: label,
    onPressed: activate,
    onKey: (e) => _headerKeys(e, index),
    builder: (_, focused) =>
        focused ? PremiumGlass(focused: true, child: child) : child,
  );
  Widget _panel(int index, String label, VoidCallback activate, Widget child) =>
      ReferenceFocusable(
        focusNode: _headerFocus[index],
        label: label,
        onPressed: activate,
        onKey: (e) => _headerKeys(e, index),
        builder: (_, focused) => PremiumGlass(focused: focused, child: child),
      );

  Widget _weatherPanel() => _panel(
    0,
    'طقس جدة وتحديث البيانات',
    _weatherDetails,
    Padding(
      padding: const EdgeInsets.all(15),
      child: Row(
        textDirection: TextDirection.ltr,
        children: [
          DesignAssetIcon(
            weatherAssetPath(
              (_weather?['weather_code'] as num?)?.toInt(),
              night: _weather?['is_day'] == 0,
            ),
            size: 60,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(child: _fit(_city.ar, 16)),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.location_on,
                      size: 15,
                      color: referenceGold,
                    ),
                  ],
                ),
                _fit('${_temperature(_weather?['temperature_2m'])}°C', 28),
                _fit(
                  _weatherFailed
                      ? 'تعذر التحديث'
                      : _weather == null
                      ? 'جارٍ التحديث'
                      : weatherDescription(
                          (_weather!['weather_code'] as num).toInt(),
                        ),
                  12,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _fit(
                  'الرطوبة ${_number(_weather?['relative_humidity_2m'])}%',
                  13,
                ),
                const SizedBox(height: 12),
                _fit('الرياح ${_number(_weather?['wind_speed_10m'])} كم/س', 12),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  Widget _prayerPanel() => _panel(
    1,
    'مواقيت الصلاة',
    _prayerDetails,
    Padding(
      padding: const EdgeInsets.all(15),
      child: Column(
        children: [
          Row(
            textDirection: TextDirection.ltr,
            children: [
              const DesignAssetIcon('assets/prayer/icon_mosque.png', size: 34),
              const SizedBox(width: 12),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _fit('مواقيت الصلاة - ${_city.ar}', 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              textDirection: TextDirection.ltr,
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
                      child: PremiumGlass(
                        radius: 14,
                        focused:
                            _prayerDate == _date &&
                            entry.key == nextPrayerKey(_prayers ?? {}, _now),
                        child: Padding(
                          padding: const EdgeInsets.all(5),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Expanded(child: _fit(entry.value, 10.5)),
                              Expanded(child: _fit(_prayerTime(entry.key), 13)),
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
  );
  void _dateDetails() => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(_l('التاريخ والوقت', 'Date and time')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _westernDigits(
              DateFormat(
                'EEEE d MMMM yyyy',
                _english ? 'en' : 'ar',
              ).format(_riyadhNow),
            ),
          ),
          Text(
            _hijriDate == _date
                ? (_english ? _hijriEnglishLabel : _hijriLabel)
                : _l('التاريخ الهجري —', 'Hijri date —'),
          ),
        ],
      ),
      actions: [
        TextButton(
          autofocus: true,
          onPressed: () {
            Navigator.pop(dialogContext);
            _run(
              () => FLauncherChannel().launchActivityFromAction(
                'android.settings.DATE_SETTINGS',
              ),
            );
          },
          child: Text(_l('إعدادات الوقت والتاريخ', 'Date and time settings')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(_l('رجوع', 'Back')),
        ),
      ],
    ),
  );
  Widget _topButton(
    int index,
    String label,
    IconData icon,
    VoidCallback action, {
    bool badge = false,
  }) => ReferenceFocusable(
    key: ValueKey('status-$index'),
    focusNode: _headerFocus[index],
    label: label,
    onPressed: action,
    onKey: (e) => _headerKeys(e, index),
    builder: (_, focused) => AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: focused ? referenceGold : Colors.transparent),
        color: focused ? const Color(0xA6000000) : Colors.transparent,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(icon, size: 27, color: Colors.white),
          if (badge)
            const Positioned(
              top: 5,
              right: 5,
              child: Icon(Icons.circle, size: 7, color: referenceGold),
            ),
        ],
      ),
    ),
  );
  Widget _clockPanel() => _plainPanel(
    6,
    _l('الساعة والتاريخ', 'Clock and date'),
    _dateDetails,
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: FittedBox(
              child: Row(
                textDirection: TextDirection.ltr,
                children: [
                  Text(
                    DateFormat('hh:mm').format(_riyadhNow),
                    textDirection: TextDirection.ltr,
                    style: _text(32),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    _riyadhNow.hour >= 12 ? _l('م', 'PM') : _l('ص', 'AM'),
                    style: _text(17),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 3),
          Expanded(
            child: _fit(
              DateFormat(
                'EEEE d MMMM yyyy',
                _english ? 'en' : 'ar',
              ).format(_riyadhNow),
              11,
            ),
          ),
        ],
      ),
    ),
  );

  static const _menuOrder = [2, 3, 1, 0, 4];
  KeyEventResult _menuKeys(KeyEvent event, int index) {
    final position = _menuOrder.indexOf(index);
    return referenceDirections(
      event,
      up: () => position == 0
          ? _headerFocus[6].requestFocus()
          : _navFocus[_menuOrder[position - 1]].requestFocus(),
      down: () => position == 4
          ? _lastSlotFocus.requestFocus()
          : _navFocus[_menuOrder[position + 1]].requestFocus(),
      left: () => _headerFocus[position < 2 ? 7 : 9].requestFocus(),
      right: () {},
    );
  }

  Widget _media(int index, String title, IconData icon) => ReferenceFocusable(
    key: ValueKey('navigation-$index'),
    focusNode: _navFocus[index],
    autofocus: index == 2,
    label: _translate(title),
    onPressed: () => _navigate(index, []),
    onKey: (event) => _menuKeys(event, index),
    builder: (_, focused) => PremiumGlass(
      focused: focused,
      radius: 38,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          textDirection: TextDirection.ltr,
          children: [
            SizedBox(
              width: 20,
              child: focused
                  ? const Icon(
                      Icons.chevron_left,
                      textDirection: TextDirection.ltr,
                      size: 28,
                      color: referenceGold,
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(child: _fit(title, 21)),
            const SizedBox(width: 12),
            Icon(icon, size: 31, color: referenceGold),
          ],
        ),
      ),
    ),
  );

  Future<void> _searchCatalogues() async {
    final kind = await showDialog<MediaKind>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(_l('البحث في الاشتراك', 'Search subscription')),
        children: [
          for (final kind in [
            MediaKind.movie,
            MediaKind.series,
            MediaKind.live,
          ])
            TextButton(
              autofocus: kind == MediaKind.movie,
              onPressed: () => Navigator.pop(context, kind),
              child: Text(_translate(kind.label)),
            ),
        ],
      ),
    );
    if (kind != null && mounted) await _openXtream(kind, search: true);
  }

  Future<void> _loadSports() async {
    final service = context.read<XtreamService?>();
    if (service == null || !service.configured || _loadingSports) return;
    final revision = service.accountRevision;
    _requestedSportsRevision = revision;
    setState(() {
      _loadingSports = true;
      _sportsFailed = false;
    });
    try {
      final guide = await service.sportsGuide(now: _now);
      if (mounted)
        setState(() {
          _sports = guide;
          _sportsRevision = revision;
          _sportsIndex = 0;
        });
    } catch (_) {
      if (mounted) setState(() => _sportsFailed = true);
    } finally {
      if (mounted) setState(() => _loadingSports = false);
    }
  }

  List<SportsProgramme> get _currentSports {
    final service = context.read<XtreamService?>();
    if (service == null || service.accountRevision != _sportsRevision)
      return [];
    return _sports
        .where((p) => service.isSports(p.channel) && p.end.isAfter(_now))
        .toList();
  }

  void _cycleSports(int delta) {
    final entries = _currentSports;
    if (entries.isEmpty) return;
    setState(() => _sportsIndex = (_sportsIndex + delta) % entries.length);
  }

  Future<void> _openSportsProgramme() async {
    if (_openingSports) return;
    _openingSports = true;
    try {
      final entries = _currentSports;
      final service = context.read<XtreamService?>();
      if (entries.isEmpty || service == null) {
        await _openXtream(MediaKind.live, sports: true);
        return;
      }
      final event = entries[_sportsIndex % entries.length];
      final playlist = service
          .items(MediaKind.live)
          .where(service.isSports)
          .toList();
      final index = playlist.indexWhere((item) => item.id == event.channel.id);
      if (index < 0) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => XtreamPlayerPage(
            service: service,
            playlist: playlist,
            index: index,
            currentPlaylist: () =>
                service.items(MediaKind.live).where(service.isSports).toList(),
          ),
        ),
      );
    } finally {
      _openingSports = false;
    }
  }

  Widget _sportsPanel() {
    final entries = _currentSports;
    final programme = entries.isEmpty
        ? null
        : entries[_sportsIndex % entries.length];
    return ReferenceFocusable(
      focusNode: _headerFocus[9],
      label: _l('مباريات اليوم', 'Today matches'),
      onPressed: _openSportsProgramme,
      onLongPress: _loadSports,
      onKey: (event) => referenceDirections(
        event,
        left: () => entries.length > 1
            ? _cycleSports(-1)
            : _headerFocus[0].requestFocus(),
        right: () =>
            entries.length > 1 ? _cycleSports(1) : _navFocus[0].requestFocus(),
        up: () => _headerFocus[7].requestFocus(),
        down: _lastSlotFocus.requestFocus,
      ),
      builder: (_, focused) => PremiumGlass(
        focused: focused,
        accent: true,
        radius: 28,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                textDirection: TextDirection.ltr,
                children: [
                  const Icon(
                    Icons.sports_soccer,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 7),
                  Expanded(child: _fit('مباريات اليوم', 17)),
                  if (programme?.liveAt(_now) == true)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _fit(_l('مباشر الآن', 'LIVE'), 10),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: programme == null
                    ? Center(
                        child: _fit(
                          _loadingSports
                              ? _l('جارٍ تحديث الجدول…', 'Updating schedule…')
                              : _sportsFailed
                              ? _l('تعذر تحديث الجدول', 'Schedule unavailable')
                              : _l(
                                  'لا توجد مباريات معلنة في دليل الاشتراك',
                                  'No matches listed by your subscription',
                                ),
                          12,
                        ),
                      )
                    : Row(
                        textDirection: TextDirection.ltr,
                        children: [
                          GestureDetector(
                            onTap: () => _cycleSports(-1),
                            child: const Icon(
                              Icons.chevron_left,
                              textDirection: TextDirection.ltr,
                              color: referenceGold,
                              size: 24,
                            ),
                          ),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      programme.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: _text(14),
                                    ),
                                  ),
                                ),
                                _fit(
                                  '${DateFormat('HH:mm').format(programme.start.toUtc().add(const Duration(hours: 3)))} · ${programme.channel.name}',
                                  11,
                                  color: Colors.white70,
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _cycleSports(1),
                            child: const Icon(
                              Icons.chevron_right,
                              textDirection: TextDirection.ltr,
                              color: referenceGold,
                              size: 24,
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
  }

  Future<void> _allApps() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(_l('جميع التطبيقات', 'All apps')),
          content: SizedBox(
            width: 820,
            height: 420,
            child: Consumer<AppsService>(
              builder: (context, service, _) => GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  childAspectRatio: 1.15,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: service.applications.where((a) => !a.hidden).length,
                itemBuilder: (context, i) {
                  final app = service.applications
                      .where((a) => !a.hidden)
                      .toList()[i];
                  return ReferenceFocusable(
                    autofocus: i == 0,
                    label: app.name,
                    onPressed: () => _run(() => service.launchApp(app)),
                    onLongPress: () => _appOptions(app),
                    builder: (_, focused) => PremiumGlass(
                      focused: focused,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          InstalledAppIcon(app: app, size: 56),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              app.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _text(12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('رجوع'),
            ),
          ],
        ),
      ),
    );
    if (mounted) _allAppsFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<AppsService>();
    final network = context.watch<NetworkService?>();
    final subscription = context.watch<XtreamService?>();
    if (subscription?.configured == true &&
        _requestedSportsRevision != subscription!.accountRevision &&
        !_loadingSports)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadSports();
      });
    final ordered = _orderedDock(
      service.applications.where((a) => !a.hidden).toList(),
    );
    final favourites = context.watch<DockFavourites?>();
    final dockApps = favourites?.visible(ordered) ?? ordered.take(7).toList();
    if (favourites != null && !favourites.initialized && service.initialized)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) favourites.seed(ordered).catchError((Object _) {});
      });
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _navFocus[2].requestFocus();
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
                        const [
                          LogicalKeyboardKey.escape,
                          LogicalKeyboardKey.goBack,
                          LogicalKeyboardKey.gameButtonB,
                        ].contains(event.logicalKey)) {
                      _navFocus[2].requestFocus();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: 1280,
                        height: 720,
                        child: DefaultTextStyle(
                          style: _text(16),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: RepaintBoundary(
                                  child: Image.asset(
                                    ReferenceLayout.wallpaper(physicalWidth),
                                    fit: BoxFit.cover,
                                    filterQuality: FilterQuality.medium,
                                  ),
                                ),
                              ),
                              const Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0x22020912),
                                        Color(0x00020912),
                                        Color(0x22000000),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              _place(
                                const Rect.fromLTWH(40, 24, 240, 44),
                                Row(
                                  textDirection: TextDirection.ltr,
                                  children: [
                                    const DesignAssetIcon(
                                      'assets/branding/logo_aervix.png',
                                      size: 36,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          'AERVIX TV',
                                          style: _text(24).copyWith(
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                key: const ValueKey('aervix-brand'),
                              ),
                              _place(
                                ReferenceLayout.clock,
                                _clockPanel(),
                                key: const ValueKey('reference-clock'),
                              ),
                              _place(
                                const Rect.fromLTWH(760, 22, 36, 36),
                                _topButton(
                                  7,
                                  _l('البحث', 'Search'),
                                  Icons.search,
                                  _searchCatalogues,
                                ),
                              ),
                              _place(
                                const Rect.fromLTWH(814, 22, 36, 36),
                                _topButton(
                                  5,
                                  _l('الإعدادات', 'Settings'),
                                  Icons.settings_outlined,
                                  _settings,
                                ),
                              ),
                              _place(
                                const Rect.fromLTWH(868, 22, 36, 36),
                                kEnableSelfUpdater
                                    ? AervixUpdateButton(
                                        builder:
                                            (context, busy, available, action) {
                                              _updateAction = action;
                                              return _topButton(
                                                8,
                                                _l('التحديثات', 'Updates'),
                                                Icons.notifications_none,
                                                action,
                                                badge: available,
                                              );
                                            },
                                      )
                                    : _topButton(
                                        8,
                                        _l('الإشعارات', 'Notifications'),
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
                                const Rect.fromLTWH(922, 22, 36, 36),
                                _topButton(
                                  4,
                                  _l('إعدادات بلوتوث', 'Bluetooth settings'),
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
                                const Rect.fromLTWH(976, 22, 36, 36),
                                _topButton(
                                  3,
                                  network == null
                                      ? _l('إعدادات الشبكة', 'Network settings')
                                      : network.hasInternetAccess
                                      ? _l('الشبكة متصلة', 'Connected')
                                      : _l('الشبكة غير متصلة', 'Disconnected'),
                                  network?.networkType == NetworkType.Wired
                                      ? Icons.settings_ethernet
                                      : network?.hasInternetAccess == false
                                      ? Icons.wifi_off
                                      : Icons.wifi,
                                  () =>
                                      _run(FLauncherChannel().openWifiSettings),
                                ),
                              ),
                              _place(
                                ReferenceLayout.movies,
                                _media(
                                  2,
                                  'الأفلام',
                                  Icons.movie_creation_outlined,
                                ),
                                key: const ValueKey('reference-movies'),
                              ),
                              _place(
                                ReferenceLayout.series,
                                _media(3, 'المسلسلات', Icons.tv_outlined),
                                key: const ValueKey('reference-series'),
                              ),
                              _place(
                                ReferenceLayout.live,
                                _media(1, 'البث المباشر', Icons.wifi_tethering),
                                key: const ValueKey('reference-live'),
                              ),
                              _place(
                                ReferenceLayout.sports,
                                _media(0, 'مباريات اليوم', Icons.sports_soccer),
                                key: const ValueKey('reference-sports'),
                              ),
                              _place(
                                ReferenceLayout.apps,
                                _media(4, 'التطبيقات', Icons.grid_view_rounded),
                                key: const ValueKey('reference-apps'),
                              ),
                              _place(
                                ReferenceLayout.prayer,
                                _prayerPanel(),
                                key: const ValueKey('reference-prayer'),
                              ),
                              _place(
                                ReferenceLayout.weather,
                                _weatherPanel(),
                                key: const ValueKey('reference-weather'),
                              ),
                              _place(
                                ReferenceLayout.sportsPanel,
                                _sportsPanel(),
                                key: const ValueKey('reference-sports-panel'),
                              ),
                              _place(
                                ReferenceLayout.dock,
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(64),
                                    border: Border.all(
                                      color: const Color(0xCCE8D2B3),
                                      width: 2,
                                    ),
                                    gradient: const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0xCC5C5350),
                                        Color(0xEB08090D),
                                        Color(0xCA312516),
                                      ],
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x99D8A13E),
                                        blurRadius: 17,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                                key: const ValueKey('applications-band'),
                              ),
                              _place(
                                ReferenceLayout.appSlots,
                                ReferenceDock(
                                  apps: dockApps,
                                  compactIcons: true,
                                  showNames: true,
                                  slotGap: 30,
                                  onLaunch: (app) =>
                                      _run(() => service.launchApp(app)),
                                  onEdit: _editDock,
                                  onAppOptions: _appOptions,
                                  firstFocus: _dockFocus,
                                  lastFocus: _lastSlotFocus,
                                  onAppFocused: (node) => _lastDockFocus = node,
                                  onLeftBoundary: _allAppsFocus.requestFocus,
                                  onRightBoundary: () =>
                                      _navFocus[4].requestFocus(),
                                  onUp: (_) => _headerFocus[9].requestFocus(),
                                ),
                              ),
                              _place(
                                const Rect.fromLTWH(98, 568, 94, 86),
                                ReferenceFocusable(
                                  key: const ValueKey('all-applications'),
                                  focusNode: _allAppsFocus,
                                  label: _l('جميع التطبيقات', 'All apps'),
                                  onPressed: _allApps,
                                  onKey: (e) => referenceDirections(
                                    e,
                                    left: () {},
                                    right: _dockFocus.requestFocus,
                                    up: () => _headerFocus[1].requestFocus(),
                                    down: () {},
                                  ),
                                  builder: (_, focused) => PremiumGlass(
                                    focused: focused,
                                    radius: 25,
                                    child: const Center(
                                      child: Icon(
                                        Icons.grid_view_rounded,
                                        size: 38,
                                      ),
                                    ),
                                  ),
                                ),
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
