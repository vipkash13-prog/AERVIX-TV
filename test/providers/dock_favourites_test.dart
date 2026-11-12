import 'package:flauncher/models/app.dart';
import 'package:flauncher/providers/dock_favourites.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<App> installedApps() => List.generate(
  10,
  (i) => App(
    packageName: 'installed.$i',
    name: 'TV $i',
    version: '1',
    hidden: false,
  ),
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'seven default favourites are pinned and persist in user-defined order',
    () async {
      SharedPreferences.setMockInitialValues({'existing': 'preserved'});
      final prefs = await SharedPreferences.getInstance();
      final store = DockFavourites(prefs);
      final apps = installedApps();
      expect(store.visible(apps).length, 7);
      await store.seed(apps);
      await store.save(['installed.6', 'installed.1', 'installed.0']);
      final restored = DockFavourites(prefs);
      expect(restored.visible(apps).map((a) => a.packageName), [
        'installed.6',
        'installed.1',
        'installed.0',
      ]);
      expect(prefs.getString('existing'), 'preserved');
    },
  );
  test(
    'removal, empty favourites and hidden/uninstalled packages do not auto-fill',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = DockFavourites(prefs);
      final apps = installedApps();
      await store.seed(apps);
      await store.save(['installed.0', 'installed.2']);
      apps[0].hidden = true;
      expect(store.visible(apps).map((a) => a.packageName), ['installed.2']);
      expect(
        store.visible(
          apps.where((a) => a.packageName != 'installed.2').toList(),
        ),
        isEmpty,
      );
      await store.save([]);
      await DockFavourites(prefs).seed(apps);
      expect(DockFavourites(prefs).visible(apps), isEmpty);
    },
  );
  test(
    'duplicates, own launcher and more than seven entries are excluded',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = DockFavourites(prefs);
      await store.save([
        'com.omeda.arc',
        'installed.0',
        'installed.0',
        ...List.generate(10, (i) => 'installed.$i'),
      ]);
      expect(store.visible(installedApps()).length, 7);
      expect(prefs.getStringList(DockFavourites.storageKey)!.toSet().length, 7);
      expect(
        prefs.getStringList(DockFavourites.storageKey),
        isNot(contains('com.omeda.arc')),
      );
    },
  );
}
