import 'package:flauncher/models/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Android game metadata is runtime-only and old packages default to false',
    () {
      final native = <String, dynamic>{
        'packageName': 'installed.game',
        'name': 'Game',
        'version': '1',
        'sideloaded': false,
      };
      expect(App.fromSystem(native).isGame, isFalse);
      expect(App.fromSystem({...native, 'isGame': true}).isGame, isTrue);
      expect(
        App(
          packageName: 'old.package',
          name: 'Existing',
          version: '1',
          hidden: false,
        ).isGame,
        isFalse,
      );
    },
  );
}
