import 'package:flauncher/providers/home_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'language and city persist without changing other preferences',
    () async {
      SharedPreferences.setMockInitialValues({'subscription-kept': 'yes'});
      final prefs = await SharedPreferences.getInstance();
      final settings = HomePreferences(prefs);
      expect(settings.language, 'ar');
      expect(settings.city.id, 'jeddah');
      await settings.setLanguage('en');
      await settings.setCity('riyadh');
      final restored = HomePreferences(prefs);
      expect(restored.locale.languageCode, 'en');
      expect(restored.city.latitude, '24.7136');
      expect(prefs.getString('subscription-kept'), 'yes');
      expect(() => restored.setCity('unknown'), throwsArgumentError);
      expect(() => restored.setLanguage('unknown'), throwsArgumentError);
    },
  );
}
