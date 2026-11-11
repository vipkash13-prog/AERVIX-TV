import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart' show DateFormat;
import 'settings/settings_panel.dart';
import 'gold_focus_tile.dart';
import 'design_asset_icon.dart';
import 'aervix_update_button.dart';
import '../build_flags.dart';
import 'package:provider/provider.dart';
import '../flauncher_channel.dart';
import '../models/app.dart';
import '../providers/apps_service.dart';

export 'gold_focus_tile.dart';

/// A static background and inexpensive focus effects keep TV rendering light.
class AervixHome extends StatefulWidget {
  final http.Client? client;
  const AervixHome({super.key, this.client});
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

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? http.Client();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
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
                        'temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m',
                    'timezone': 'Asia/Riyadh',
                  }),
                )
                .timeout(const Duration(seconds: 12));
            if (response.statusCode != 200)
              throw const FormatException('weather');
            final current = Map<String, dynamic>.from(
              jsonDecode(response.body)['current'] as Map,
            );
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
      setState(() => _now = DateTime.now());
      _refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockTimer?.cancel();
    _weatherTimer?.cancel();
    _client.close();
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

  @override
  Widget build(BuildContext context) {
    final service = context.watch<AppsService>();
    final apps = service.applications.where((app) => !app.hidden).toList();
    final favorites = service.categories
        .where((c) => c.name == 'Favorites')
        .expand((c) => c.applications)
        .where((app) => !app.hidden)
        .toList();
    final nextPrayer = nextPrayerKey(_prayers ?? {}, _now);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: LayoutBuilder(
          builder: (context, constraints) => SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: 1600,
                height: 900,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: Image.asset(
                          'assets/backgrounds/jeddah_background_fhd.png',
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Image.asset(
                          'assets/backgrounds/background_overlay.png',
                          cacheWidth: 32,
                          fit: BoxFit.fill,
                          filterQuality: FilterQuality.low,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 165,
                      child: IgnorePointer(
                        child: Image.asset(
                          'assets/backgrounds/gold_waves_bottom.png',
                          fit: BoxFit.fitWidth,
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
                              Color(0x44000000),
                              Colors.transparent,
                              Color(0xEE000000),
                            ],
                            stops: [0, .42, 1],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 22,
                      left: 35,
                      child: Row(
                        textDirection: TextDirection.ltr,
                        children: const [
                          Text(
                            'AERVIX TV',
                            style: TextStyle(
                              fontSize: 37,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 24,
                      right: 35,
                      child: Row(
                        children: [
                          if (kEnableSelfUpdater) ...[
                            const SizedBox(
                              width: 74,
                              height: 66,
                              child: AervixUpdateButton(),
                            ),
                            const SizedBox(width: 18),
                          ],
                          SizedBox(
                            width: 74,
                            height: 66,
                            child: GoldFocusTile(
                              showLabel: false,
                              label: 'إعدادات بلوتوث',
                              onPressed: () => _run(
                                () =>
                                    FLauncherChannel().launchActivityFromAction(
                                      'android.settings.BLUETOOTH_SETTINGS',
                                    ),
                              ),
                              child: const DesignAssetIcon(
                                'assets/topbar/icon_bluetooth.png',
                                size: 36,
                              ),
                            ),
                          ),
                          const SizedBox(width: 18),
                          SizedBox(
                            width: 74,
                            height: 66,
                            child: GoldFocusTile(
                              showLabel: false,
                              label: 'إعدادات الإشعارات',
                              onPressed: () => _run(
                                () =>
                                    FLauncherChannel().launchActivityFromAction(
                                      'android.settings.NOTIFICATION_SETTINGS',
                                    ),
                              ),
                              child: const DesignAssetIcon(
                                'assets/topbar/icon_notifications.png',
                                size: 36,
                              ),
                            ),
                          ),
                          const SizedBox(width: 18),
                          SizedBox(
                            width: 74,
                            height: 66,
                            child: GoldFocusTile(
                              showLabel: false,
                              label: 'تحديث',
                              onPressed: _refresh,
                              child: const DesignAssetIcon(
                                'assets/topbar/icon_refresh.png',
                                size: 36,
                              ),
                            ),
                          ),
                          const SizedBox(width: 18),
                          SizedBox(
                            width: 74,
                            height: 66,
                            child: GoldFocusTile(
                              showLabel: false,
                              label: 'الجهاز',
                              onPressed: () =>
                                  _run(FLauncherChannel().openSettings),
                              child: const DesignAssetIcon(
                                'assets/topbar/icon_display.png',
                                size: 36,
                              ),
                            ),
                          ),
                          const SizedBox(width: 18),
                          SizedBox(
                            width: 74,
                            height: 66,
                            child: GoldFocusTile(
                              showLabel: false,
                              label: 'الإعدادات',
                              onPressed: () => showDialog<void>(
                                context: context,
                                builder: (_) => const SettingsPanel(),
                              ),
                              child: const DesignAssetIcon(
                                'assets/topbar/icon_settings_top.png',
                                size: 36,
                              ),
                            ),
                          ),
                          const SizedBox(width: 18),
                          SizedBox(
                            width: 74,
                            height: 66,
                            child: GoldFocusTile(
                              showLabel: false,
                              label: 'Wi-Fi',
                              onPressed: () =>
                                  _run(FLauncherChannel().openWifiSettings),
                              child: const DesignAssetIcon(
                                'assets/topbar/icon_wifi.png',
                                size: 36,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 30,
                      top: 116,
                      width: 350,
                      child: _fitInformation(
                        width: 350,
                        key: const ValueKey('left-information'),
                        child: Column(
                          children: [
                            _panel(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      DateFormat('hh:mm a', 'ar').format(_now),
                                      textDirection: TextDirection.ltr,
                                      style: const TextStyle(
                                        fontSize: 53,
                                        height: 1.1,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    DateFormat(
                                      'EEE d MMMM yyyy',
                                      'ar',
                                    ).format(_now),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 22),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            _panel(
                              frame: 'assets/cards/card_weather.png',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'جدة  •  الطقس',
                                    style: TextStyle(
                                      fontSize: 25,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      DesignAssetIcon(
                                        weatherAssetPath(
                                          (_weather?['weather_code'] as num?)
                                              ?.toInt(),
                                          night:
                                              _now
                                                      .toUtc()
                                                      .add(
                                                        const Duration(
                                                          hours: 3,
                                                        ),
                                                      )
                                                      .hour <
                                                  6 ||
                                              _now
                                                      .toUtc()
                                                      .add(
                                                        const Duration(
                                                          hours: 3,
                                                        ),
                                                      )
                                                      .hour >=
                                                  18,
                                        ),
                                        size: 78,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            _weather == null
                                                ? '— °C'
                                                : '${_weather!['temperature_2m']}°C',
                                            textDirection: TextDirection.ltr,
                                            style: const TextStyle(
                                              fontSize: 45,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _weatherFailed
                                        ? 'تعذر تحديث الطقس'
                                        : _weather == null
                                        ? 'جارٍ تحديث الطقس…'
                                        : weatherDescription(
                                            (_weather!['weather_code'] as num)
                                                .toInt(),
                                          ),
                                    style: const TextStyle(fontSize: 23),
                                  ),
                                  const Divider(color: Colors.white24),
                                  Text(
                                    _weather == null
                                        ? 'Open-Meteo'
                                        : 'رطوبة ${_weather!['relative_humidity_2m']}%   •   رياح ${_weather!['wind_speed_10m']} كم/س',
                                    style: const TextStyle(fontSize: 17),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      right: 30,
                      top: 116,
                      width: 320,
                      child: _fitInformation(
                        width: 320,
                        key: const ValueKey('prayer-information'),
                        child: _panel(
                          frame: 'assets/cards/card_prayer.png',
                          child: Column(
                            children: [
                              const Row(
                                children: [
                                  DesignAssetIcon(
                                    'assets/prayer/icon_mosque.png',
                                    size: 34,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'مواقيت الصلاة',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 25,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              for (final entry in const {
                                'Fajr': 'الفجر',
                                'Sunrise': 'الشروق',
                                'Dhuhr': 'الظهر',
                                'Asr': 'العصر',
                                'Maghrib': 'المغرب',
                                'Isha': 'العشاء',
                              }.entries)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 7,
                                    horizontal: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        _prayerDate == _date &&
                                            entry.key == nextPrayer
                                        ? const Color(0x443C2B10)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color:
                                          _prayerDate == _date &&
                                              entry.key == nextPrayer
                                          ? aervixGold
                                          : Colors.transparent,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          entry.value,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 23),
                                        ),
                                      ),
                                      Text(
                                        _prayerDate == _date
                                            ? '${_prayers?[entry.key] ?? '—'}'
                                                  .split(' ')
                                                  .first
                                            : '—',
                                        textDirection: TextDirection.ltr,
                                        style: const TextStyle(
                                          fontSize: 23,
                                          color: aervixGold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              Text(
                                _prayersFailed
                                    ? 'تعذر تحديث المواقيت'
                                    : 'جدة • أم القرى • توقيت الرياض',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 30,
                      right: 30,
                      top: 525,
                      height: 172,
                      key: const ValueKey('applications-band'),
                      child: !service.initialized
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: aervixGold,
                              ),
                            )
                          : apps.isEmpty
                          ? const Center(
                              child: Text(
                                'لا توجد تطبيقات مثبتة قابلة للتشغيل',
                                style: TextStyle(fontSize: 25),
                              ),
                            )
                          : ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.all(10),
                              itemCount: apps.length,
                              separatorBuilder: (_, index) =>
                                  const SizedBox(width: 18),
                              itemBuilder: (_, index) => SizedBox(
                                width: 150,
                                child: _appTile(
                                  apps[index],
                                  autofocus: index == 0,
                                ),
                              ),
                            ),
                    ),
                    Positioned(
                      left: 30,
                      right: 30,
                      bottom: 42,
                      height: 130,
                      child: Row(
                        children: [
                          _category('جميع التطبيقات', Icons.apps, apps),
                          const SizedBox(width: 18),
                          _category('المفضلة', Icons.star_border, favorites),
                          const SizedBox(width: 18),
                          _category(
                            'الرياضة',
                            Icons.sports_soccer,
                            _matching(apps, ['sport', 'yacin', 'كورة', 'رياض']),
                          ),
                          const SizedBox(width: 18),
                          _category(
                            'البث المباشر',
                            Icons.live_tv,
                            _matching(apps, ['iptv', 'shahid', 'tv', 'تلفاز']),
                          ),
                          const SizedBox(width: 18),
                          _category(
                            'المسلسلات',
                            Icons.tv,
                            _matching(apps, [
                              'stremio',
                              'nuvio',
                              'stream',
                              'shahid',
                              'netflix',
                              'movie',
                              'harbor',
                            ]),
                          ),
                          const SizedBox(width: 18),
                          _category(
                            'الأفلام',
                            Icons.movie_outlined,
                            _matching(apps, [
                              'stremio',
                              'nuvio',
                              'stream',
                              'shahid',
                              'netflix',
                              'movie',
                              'harbor',
                            ]),
                          ),
                        ],
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
  }

  List<App> _matching(List<App> apps, List<String> terms) => apps.where((app) {
    final value = '${app.name} ${app.packageName}'.toLowerCase();
    return terms.any(value.contains);
  }).toList();

  Widget _category(String label, IconData icon, List<App> apps) => Expanded(
    child: GoldFocusTile(
      label: label,
      onPressed: () => _showApps(label, apps),
      wide: true,
      child: DesignAssetIcon(_categoryAsset(icon), size: 64),
    ),
  );

  static final Map<IconData, String> _categoryArtwork = {
    Icons.apps: 'assets/categories/icon_apps.png',
    Icons.star_border: 'assets/categories/icon_favorites.png',
    Icons.sports_soccer: 'assets/categories/icon_sports.png',
    Icons.live_tv: 'assets/categories/icon_live_tv.png',
    Icons.tv: 'assets/categories/icon_series.png',
    Icons.movie_outlined: 'assets/categories/icon_movies.png',
  };
  String _categoryAsset(IconData icon) =>
      _categoryArtwork[icon] ?? 'assets/categories/icon_apps.png';

  Widget _fitInformation({
    required double width,
    required Widget child,
    Key? key,
  }) => SizedBox(
    key: key,
    width: width,
    height: 400,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.topCenter,
      child: SizedBox(width: width, child: child),
    ),
  );

  Widget _panel({
    required Widget child,
    String frame = 'assets/cards/card_glass_dark.png',
  }) => Container(
    padding: const EdgeInsets.all(26),
    decoration: BoxDecoration(
      color: const Color(0xED0C121C),
      borderRadius: BorderRadius.circular(28),
      image: DecorationImage(
        image: ExactAssetImage(frame, scale: 4),
        fit: BoxFit.fill,
        centerSlice: frame.endsWith('card_prayer.png')
            ? const Rect.fromLTRB(22.5, 25, 77.5, 115)
            : const Rect.fromLTRB(30, 25, 170, 85),
        filterQuality: FilterQuality.low,
      ),
    ),
    child: child,
  );
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

class InstalledAppIcon extends StatefulWidget {
  final App app;
  const InstalledAppIcon({super.key, required this.app});
  @override
  State<InstalledAppIcon> createState() => _InstalledAppIconState();
}

class _InstalledAppIconState extends State<InstalledAppIcon> {
  late Future<Uint8List> _icon;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _icon = context.read<AppsService>().getAppIcon(widget.app.packageName);
  }

  @override
  void didUpdateWidget(covariant InstalledAppIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.app != widget.app)
      _icon = context.read<AppsService>().getAppIcon(widget.app.packageName);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: _icon,
    builder: (_, snapshot) {
      final bytes = snapshot.data;
      if (bytes == null || bytes.isEmpty)
        return const Icon(Icons.apps, size: 52);
      // The platform returns the actual installed package icon, cached by AppsService.
      return Image.memory(
        bytes,
        width: 72,
        height: 72,
        fit: BoxFit.contain,
        errorBuilder: (_, error, stack) => const Icon(Icons.apps, size: 52),
      );
    },
  );
}
