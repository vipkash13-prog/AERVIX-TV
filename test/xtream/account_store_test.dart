import 'package:flauncher/xtream/account_store.dart';
import 'package:flauncher/xtream/models.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'account is reused from secure storage, without writing credentials to launcher preferences',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({'existing_setting': true});
      final prefs = await SharedPreferences.getInstance();
      final store = SecureAccountStore(prefs);
      expect(await store.read(), isNull);
      final account = XtreamAccount.input(
        'https://fixture.test',
        'test-user',
        'test-password',
      );
      await store.write(account);
      expect(
        (await SecureAccountStore(prefs).read())!.password,
        account.password,
      );
      expect(prefs.getKeys(), {'existing_setting'});
    },
  );
  test(
    'explicit legacy Xtream keys import without clearing subscription or settings',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({
        'xtream_host': 'https://fixture.test',
        'xtream_username': 'test-user',
        'xtream_password': 'test-password',
        'existing_setting': 42,
      });
      final prefs = await SharedPreferences.getInstance();
      expect((await SecureAccountStore(prefs).read())!.username, 'test-user');
      expect(
        (await const FlutterSecureStorage().read(key: SecureAccountStore.key)),
        isNotNull,
      );
      expect(prefs.getInt('existing_setting'), 42);
      expect(prefs.getString('xtream_password'), 'test-password');
    },
  );
}
