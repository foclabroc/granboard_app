import 'package:flutter_test/flutter_test.dart';
import 'package:granboard_proto/game/x01.dart';
import 'package:granboard_proto/granboard.dart';
import 'package:granboard_proto/players.dart';
import 'package:granboard_proto/server.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_server.dart';
import 'package:granboard_proto/rank.dart';

X01Game finishedGame(List<X01Player> players) {
  final g = X01Game(const X01Settings(startScore: 301, roundLimit: 1), players);
  for (var i = 0; i < players.length; i++) {
    g.throwDart(const DartHit(20, 3, Ring.triple));
    g.next();
  }
  return g;
}

void main() {
  late FakeServer server;
  final store = PlayerStore.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    server = FakeServer()..install();
    await store.load();
  });

  test('Création, pseudo pris, connexion et mauvais code', () async {
    final foc = await store.register('Foc', '1234');
    expect(store.players.single.name, 'Foc');
    expect(() => store.register('foc', '0000'),
        throwsA(isA<ApiError>().having((e) => e.code, 'code', 'taken')));
    expect(() => store.login('Foc', '9999'),
        throwsA(isA<ApiError>().having((e) => e.code, 'code', 'pin')));
    // Reconnexion du même compte : pas de doublon, nouveau jeton
    final oldToken = foc.token;
    final again = await store.login('FOC', '1234');
    expect(store.players.length, 1);
    expect(identical(again, foc), isTrue);
    expect(again.token, isNot(oldToken));
  });

  test('Comptes mémorisés après redémarrage', () async {
    await store.register('Foc', '1234');
    await store.load();
    expect(store.players.single.name, 'Foc');
  });

  test('Partie envoyée, invités exclus', () async {
    final foc = await store.register('Foc', '1234');
    final g = finishedGame([
      X01Player(id: foc.key, name: foc.name),
      const X01Player(id: 'guest-1', name: 'Invité 1', team: 1),
    ]);
    expect(await store.recordX01(g), isTrue);
    final sent = server.games.values.single;
    expect((sent['players'] as List).length, 1);
    expect(((sent['players'] as List).single as Map)['token'], foc.token);
    expect(store.pending, isEmpty);
  });

  test('Hors ligne : la partie attend puis part au retour du réseau', () async {
    final foc = await store.register('Foc', '1234');
    server.offline = true;
    final g = finishedGame([X01Player(id: foc.key, name: foc.name)]);
    expect(await store.recordX01(g), isFalse);
    expect(store.pending.length, 1);
    // Survit à un redémarrage
    await store.load();
    expect(store.pending.length, 1);
    server.offline = false;
    expect(await store.flush(), isTrue);
    expect(store.pending, isEmpty);
    expect(server.games.length, 1);
  });

  test('Session expirée : le joueur est à reconnecter, la partie attend',
      () async {
    final foc = await store.register('Foc', '1234');
    server.sessions.clear(); // session supprimée côté serveur
    final g = finishedGame([X01Player(id: foc.key, name: foc.name)]);
    expect(await store.recordX01(g), isFalse);
    expect(store.byId(foc.key)!.expired, isTrue);
    expect(store.pending.length, 1);
    await store.login('Foc', '1234'); // reconnexion → envoi
    await store.flush();
    expect(store.pending, isEmpty);
    expect(server.games.length, 1);
  });

  test('Rangs façon GranBoard', () {
    expect(ratingClass(1), 'C');
    expect(ratingClass(4.56), 'CC');
    expect(ratingClass(12), 'AA');
    expect(ratingClass(20), 'GM');
    // Même calcul que gb__band (SQL)
    expect(bandRating(43.42, kPprBounds), 3.68);
    expect(bandRating(1.88, kMprBounds), 5.4);
    expect(bandRating(150, kPprBounds), 20);
    expect(nextRank(4.56)!.label, 'B');
    expect(nextRank(20), isNull);
    expect(rankProgress(5), closeTo(0.5, 1e-9));
  });
}
