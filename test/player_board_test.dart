import 'package:flutter_test/flutter_test.dart';
import 'package:granboard_proto/ui/dartboard.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('Cible par joueur : gardée, relue, reçue par la TV', () async {
    SharedPreferences.setMockInitialValues({});
    final b = PlayerBoards.instance;
    expect(b.of('7'), isNull);
    await b.set('7', BoardSkin.neon);
    expect(b.of('7'), BoardSkin.neon);
    expect(b.all, {'7': 'neon'});
    await b.load();
    expect(b.of('7'), BoardSkin.neon);
    await b.set('7', null);
    expect(b.of('7'), isNull);

    // TV : ce qu'envoie le téléphone passe avant
    b.applyRemote({'9': 'ice'}, 'ice');
    expect(b.of('9'), BoardSkin.ice);
    expect(b.idle, BoardSkin.ice);
    b.applyRemote({}, null);
    expect(b.idle, isNull);
  });
}
