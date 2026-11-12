import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app.dart';

class DockFavourites extends ChangeNotifier {
  static const limit = 7;
  static const storageKey = 'aervix.dock.favourites.v1';
  final SharedPreferences preferences;
  List<String>? _packages;
  int _revision = 0;
  DockFavourites(this.preferences) {
    if (preferences.containsKey(storageKey))
      _packages = _clean(preferences.getStringList(storageKey) ?? []);
  }
  int get revision => _revision;
  bool get initialized => _packages != null;
  List<String> _clean(List<String> ids) => ids
      .where((id) => id.isNotEmpty && id != 'com.omeda.arc')
      .toSet()
      .take(limit)
      .toList();
  List<App> visible(List<App> defaults) {
    final available = {
      for (final app in defaults)
        if (!app.hidden && app.packageName != 'com.omeda.arc')
          app.packageName: app,
    };
    return (_packages ?? available.keys.take(limit))
        .where(available.containsKey)
        .map((id) => available[id]!)
        .toList();
  }

  Future<void> seed(List<App> defaults) async {
    if (initialized) return;
    await save(
      defaults
          .where((a) => !a.hidden)
          .take(limit)
          .map((a) => a.packageName)
          .toList(),
    );
  }

  Future<void> save(List<String> ids) async {
    final clean = _clean(ids);
    if (!await preferences.setStringList(storageKey, clean))
      throw StateError('Unable to save favourites');
    _packages = clean;
    _revision++;
    notifyListeners();
  }
}
