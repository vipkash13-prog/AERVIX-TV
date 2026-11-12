import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

abstract class AccountStore {
  Future<XtreamAccount?> read();
  Future<void> write(XtreamAccount account);
}

class SecureAccountStore implements AccountStore {
  final FlutterSecureStorage storage;
  final SharedPreferences preferences;
  static const key = 'aervix.xtream.account.v1';
  SecureAccountStore(
    this.preferences, {
    this.storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    ),
  });
  @override
  Future<XtreamAccount?> read() async {
    final saved = await storage.read(key: key);
    if (saved != null) return XtreamAccount.decode(saved);
    // Explicit legacy Xtream keys only. Do not guess unrelated launcher settings.
    final serialized = preferences.getString('xtream_account');
    XtreamAccount? account;
    if (serialized != null) {
      account = XtreamAccount.decode(serialized);
    } else {
      final host =
          preferences.getString('xtream_host') ??
          preferences.getString('xtream_url');
      final user = preferences.getString('xtream_username');
      final pass = preferences.getString('xtream_password');
      if (host != null && user != null && pass != null)
        account = XtreamAccount.input(host, user, pass);
    }
    if (account != null) await write(account);
    return account;
  }

  @override
  Future<void> write(XtreamAccount account) =>
      storage.write(key: key, value: account.encode());
}
