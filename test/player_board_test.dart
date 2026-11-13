import 'package:flutter_test/flutter_test.dart';
import 'package:granboard_proto/media.dart';
import 'package:granboard_proto/players.dart';
import 'package:granboard_proto/ui/dartboard.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_server.dart';

void main() {
  test('Cible par joueur : sur le serveur, retrouvée sur un autre téléphone',
      () async {
    SharedPreferences.setMockInitialValues({});
    FakeServer().install();
    MediaStore.instance.debugClear();
    await PlayerStore.instance.load();
    await PlayerStore.instance.register('Foc', '1234');
    final p = PlayerStore.instance.players.first;
    final b = PlayerBoards.instance;
    expect(b.of(p.key), isNull);
    await b.set(p, BoardSkin.neon);
    expect(b.of(p.key), BoardSkin.neon);
    expect(b.all, {p.key: 'neon'});

    // autre téléphone : cache vide, relu au serveur
    MediaStore.instance.debugClear();
    expect(b.of(p.key), isNull);
    await MediaStore.instance.ensure([p.key]);
    expect(b.of(p.key), BoardSkin.neon);

    await b.set(p, null);
    expect(b.of(p.key), isNull);

    // TV : ce qu'envoie le téléphone passe avant
    b.applyRemote({'9': 'ice'}, 'ice');
    expect(b.of('9'), BoardSkin.ice);
    expect(b.idle, BoardSkin.ice);
    b.applyRemote({}, null);
    expect(b.idle, isNull);
  });
}
