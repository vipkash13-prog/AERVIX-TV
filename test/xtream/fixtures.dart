import 'dart:convert';
import 'package:flauncher/xtream/account_store.dart';
import 'package:flauncher/xtream/models.dart';
import 'package:flauncher/xtream/xtream_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemoryAccountStore implements AccountStore {
  XtreamAccount? account;
  bool rejectWrite = false;
  MemoryAccountStore(this.account);
  @override
  Future<XtreamAccount?> read() async => account;
  @override
  Future<void> write(XtreamAccount value) async {
    if (rejectWrite) throw StateError('storage');
    account = value;
  }
}

class CatalogueFixture {
  final actions = <String>[];
  bool newlyAdult = false, unavailable = false;
  final account = XtreamAccount.input(
    'https://fixture.test/base',
    'fixture-user',
    'fixture-password',
  );
  late final store = MemoryAccountStore(account);
  late SharedPreferences preferences;
  late XtreamService service;
  Object response(String action) {
    if (action == 'get_vod_info')
      return {
        'info': {'name': 'Movie', 'adult': false},
      };
    if (action == 'auth')
      return {
        'user_info': {'auth': 1, 'status': 'Active'},
      };
    if (action.endsWith('categories'))
      return [
        {'category_id': '1', 'category_name': 'العامة', 'parent_id': 0},
        {'category_id': '2', 'category_name': 'Adult XXX', 'parent_id': 0},
        {'category_id': '3', 'category_name': 'Hidden child', 'parent_id': 2},
      ];
    if (action == 'get_series_info')
      return {
        'info': {'name': 'Series'},
        'episodes': {
          '2': [
            {
              'id': 202,
              'episode_num': 2,
              'season': 2,
              'title': 'الثانية',
              'container_extension': 'mkv',
            },
          ],
          '1': [
            {'id': 102, 'episode_num': 2, 'season': 1, 'title': 'الثانية'},
            {'id': 101, 'episode_num': 1, 'season': 1, 'title': 'الأولى'},
            {'id': 103, 'episode_num': 3, 'title': 'XXX', 'is_adult': 1},
          ],
        },
      };
    final idKey = action == 'get_series' ? 'series_id' : 'stream_id';
    return [
      {
        idKey: 1,
        'name': newlyAdult ? 'XXX renamed' : 'الأولى',
        'category_id': '1',
        'num': 1,
      },
      {idKey: 2, 'name': 'الثانية', 'category_id': '1', 'num': 2},
      {idKey: 3, 'name': 'الثالثة', 'category_id': '1', 'num': 3},
      {idKey: 4, 'name': 'concealed title', 'category_id': '2', 'num': 4},
      {idKey: 5, 'name': 'concealed child', 'category_id': '3', 'num': 5},
      {idKey: 6, 'name': 'Porn name', 'category_id': '1', 'num': 6},
      {
        idKey: 7,
        'name': 'flagged',
        'category_id': '1',
        'num': 7,
        'is_adult': true,
      },
    ];
  }

  Future<void> init({bool emptyAccount = false}) async {
    SharedPreferences.setMockInitialValues({'existing_setting': 'preserve'});
    preferences = await SharedPreferences.getInstance();
    if (emptyAccount) store.account = null;
    service = XtreamService(
      store,
      preferences,
      client: MockClient((request) async {
        final action = request.url.queryParameters['action'] ?? 'auth';
        actions.add(action);
        return http.Response(
          unavailable ? 'unavailable' : jsonEncode(response(action)),
          unavailable ? 503 : 200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    await service.ready;
  }
}
