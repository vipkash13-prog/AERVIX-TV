import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeCity {
  final String id, ar, en, latitude, longitude;
  const HomeCity(this.id, this.ar, this.en, this.latitude, this.longitude);
}

class HomePreferences extends ChangeNotifier {
  static const cities = [
    HomeCity('jeddah', 'جدة', 'Jeddah', '21.4858', '39.1925'),
    HomeCity('riyadh', 'الرياض', 'Riyadh', '24.7136', '46.6753'),
    HomeCity('makkah', 'مكة المكرمة', 'Makkah', '21.4225', '39.8262'),
    HomeCity('madinah', 'المدينة المنورة', 'Madinah', '24.4672', '39.6024'),
    HomeCity('dammam', 'الدمام', 'Dammam', '26.4207', '50.0888'),
  ];
  final SharedPreferences preferences;
  HomePreferences(this.preferences);
  String get language =>
      preferences.getString('aervix.home.language') == 'en' ? 'en' : 'ar';
  Locale get locale => Locale(language);
  HomeCity get city => cities.firstWhere(
    (c) => c.id == preferences.getString('aervix.home.city'),
    orElse: () => cities.first,
  );
  Future<void> setLanguage(String language) async {
    if (!['ar', 'en'].contains(language))
      throw ArgumentError('Unsupported language');
    if (!await preferences.setString('aervix.home.language', language))
      throw StateError('Unable to save language');
    notifyListeners();
  }

  Future<void> setCity(String id) async {
    if (!cities.any((c) => c.id == id)) throw ArgumentError('Unsupported city');
    if (!await preferences.setString('aervix.home.city', id))
      throw StateError('Unable to save city');
    notifyListeners();
  }
}
