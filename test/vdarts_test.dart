import 'package:flutter_test/flutter_test.dart';
import 'package:granboard_proto/board_service.dart';
import 'package:granboard_proto/granboard.dart';
import 'package:granboard_proto/vdarts.dart';

List<int> ascii(String s) => s.codeUnits;

/// Paire brouillée d'une fléchette, telle qu'envoyée par la cible.
List<int> pair(int n, Ring r, {bool alt = false}) =>
    Vdarts.pairFor(n, r, altKey: alt)!;

String labelOf(List<BoardEvent> e) => e.map((x) => x.label).join(', ');

void main() {
  group('Noms et familles', () {
    test('modèles reconnus', () {
      expect(Vdarts.isVdarts('VDarts H4L'), isTrue);
      expect(Vdarts.isVdarts('GRANBOARD'), isFalse);
      expect(Vdarts.isVdarts(null), isFalse);
      expect(Vdarts.model('VDarts-H4L'), 'VDarts H4L');
      expect(Vdarts.model('VDARTS H3N'), 'VDarts H3L');
      expect(Vdarts.model('VDarts XYZ'), 'VDarts');
      expect(Vdarts.family('VDarts H4L'), VdartsFamily.h4);
      expect(Vdarts.family('VDartsBLE 1234'), VdartsFamily.h4);
      expect(Vdarts.family('VDarts H3L'), VdartsFamily.h3);
      expect(Vdarts.family('VDarts MINI+'), VdartsFamily.h3);
      expect(Vdarts.family('VDARTS-BLE2010B'), VdartsFamily.h3);
      expect(Vdarts.family('VDarts_H2L'), VdartsFamily.h2);
      expect(Vdarts.family('VDarts H2'), VdartsFamily.h2);
      expect(Vdarts.family('VDarts XYZ'), VdartsFamily.unknown);
      expect(Vdarts.isH3l('VDarts H3L'), isTrue);
      expect(Vdarts.isH3l('VDarts H3'), isFalse);
    });
  });

  group('Décodage', () {
    test('la matrice couvre les 82 zones', () {
      final zones = {
        for (final z in Vdarts.matrix.values) '${z.$1}/${z.$2.name}'
      };
      expect(zones.length, 82);
    });

    test('zones confirmées par une capture de DartMate', () {
      expect(Vdarts.hitAt(3, 4)!.label, '20');
      expect(Vdarts.hitAt(3, 6)!.ring, Ring.singleOuter);
      expect(Vdarts.hitAt(3, 0)!.label, 'D20');
      expect(Vdarts.hitAt(3, 5)!.label, 'T20');
      expect(Vdarts.hitAt(10, 1)!.label, 'T19');
      expect(Vdarts.hitAt(6, 6)!.label, 'D19');
      expect(Vdarts.hitAt(6, 1)!.label, '25');
      expect(Vdarts.hitAt(4, 1)!.label, 'BULL');
      expect(Vdarts.hitAt(2, 2)!.label, 'T10');
      expect(Vdarts.hitAt(4, 4)!.label, 'D10');
      expect(Vdarts.hitAt(2, 5)!.label, 'T1');
      expect(Vdarts.hitAt(2, 0)!.label, 'D1');
    });

    test('trames binaires, avec les 2 clés', () {
      final d = VdartsDecoder();
      expect(labelOf(d.accept(pair(20, Ring.triple))), 'T20 (60)');
      expect(labelOf(d.accept(pair(20, Ring.triple, alt: true))), 'T20 (60)');
      expect(labelOf(d.accept(pair(25, Ring.innerBull))), 'BULL (50)');
      expect(labelOf(d.accept(pair(25, Ring.outerBull, alt: true))), '25 (25)');
      // 2 fléchettes dans la même notification
      expect(
          labelOf(d.accept([...pair(1, Ring.double), ...pair(5, Ring.triple)])),
          'D1 (2), T5 (15)');
      // « A1 » brouillé par la clé 0xC9 = ligne 0, colonne 0 = D4
      expect(labelOf(d.accept([65 ^ 0xC9, 49 ^ 0xC9])), 'D4 (8)');
      expect(labelOf(d.accept([65 ^ 0xD2, 49 ^ 0xD2])), 'D4 (8)');
    });

    test('bouton, trames de service et trame inconnue', () {
      final d = VdartsDecoder();
      expect(d.accept([0x9F, 0xE7]).single, isA<ButtonEvent>());
      expect(d.accept([0x84, 0xFC]).single, isA<ButtonEvent>());
      expect(d.accept(ascii('AT')), isEmpty);
      expect(d.accept(ascii('VD')), isEmpty);
      expect(d.accept([0xE2, 0x36]), isEmpty);
      expect(d.accept([0x80, 0x81]).single, isA<UnknownEvent>());
      expect(d.accept([0x80]).single, isA<UnknownEvent>());
    });

    test('texte « MAT » et « BTN », même coupé en 2 notifications', () {
      final d = VdartsDecoder();
      expect(labelOf(d.accept(ascii('MAT 3 5 1\r\n'))), 'T20 (60)');
      expect(d.accept(ascii('MAT 6 ')), isEmpty);
      expect(labelOf(d.accept(ascii('1 1\n'))), '25 (25)');
      expect(d.accept(ascii('BTN 1 1\n')).single, isA<ButtonEvent>());
      expect(d.accept(ascii('BTN@')).single, isA<ButtonEvent>());
      expect(d.accept(ascii('HELLO\n')).single, isA<UnknownEvent>());
    });

    test('capteur de bordure : hors cible, sauf juste après une fléchette', () {
      var now = 1000;
      final d = VdartsDecoder(clock: () => now);
      List<int> sensor(int level) => [156, (156 ^ 78) ^ (97 + level)];
      expect(d.accept(sensor(5)).single, isA<MissEvent>());
      now += 100;
      expect(d.accept(sensor(5)), isEmpty, reason: 'même signal, 100 ms');
      now += 500;
      expect(d.accept(sensor(1)), isEmpty, reason: 'signal trop faible');
      d.accept(pair(20, Ring.triple));
      now += 150;
      expect(d.accept(sensor(9)), isEmpty, reason: 'vibration de la fléchette');
      now += 300;
      expect(d.accept([135, (135 ^ 78) ^ (97 + 9)]).single, isA<MissEvent>());
    });
  });

  group('Ouverture', () {
    testWidgets('H4 : séquence officielle après l\'abonnement', (t) async {
      final sent = <List<int>>[];
      final link = VdartsLink(
        family: VdartsFamily.h4,
        h3l: false,
        write: (b, {bool h2 = false}) async => sent.add(b),
        gameplay: (_) {},
      );
      link.start();
      await t.pump(const Duration(seconds: 3));
      expect(sent.length, 10);
      expect(sent[0], ascii('OK'));
      expect(sent[1], ascii('VD'));
      expect(sent[2], [0xC9, 0x36]);
      expect(sent[3], [38, 37, 38, 97, 38, 0, 38, 30]);
      expect(sent.last, [38, 43, 38, 25, 38, 4, 38, 1]);
      link.close();
      await t.pump(const Duration(seconds: 5));
    });

    testWidgets('H3L : ouverture quand la cible n\'envoie que « AT »',
        (t) async {
      final sent = <List<int>>[];
      final got = <List<int>>[];
      final link = VdartsLink(
        family: VdartsFamily.h3,
        h3l: true,
        write: (b, {bool h2 = false}) async => sent.add(b),
        gameplay: got.add,
      );
      await link.start();
      expect(sent, isEmpty);
      link.onNotification(ascii('AT'));
      await t.pump(const Duration(seconds: 1));
      expect(sent, [
        ascii('OK'),
        ascii('VD'),
        [0xC9, 0x36]
      ]);
      link.onNotification(ascii('AT'));
      link.onNotification(ascii('AT'));
      await t.pump(const Duration(seconds: 3));
      expect(sent.length, 13, reason: '3 + séquence complète');
      link.onNotification(pair(20, Ring.triple));
      expect(got.single, pair(20, Ring.triple));
      link.close();
      await t.pump(const Duration(seconds: 5));
    });

    testWidgets('H2 : RS, OK, VD, clé, réglages puis fléchettes', (t) async {
      final sent = <List<int>>[];
      final h2Flags = <bool>[];
      final got = <List<int>>[];
      final link = VdartsLink(
        family: VdartsFamily.h2,
        h3l: false,
        write: (b, {bool h2 = false}) async {
          sent.add(b);
          h2Flags.add(h2);
        },
        gameplay: got.add,
      );
      link.start();
      await t.pump(const Duration(milliseconds: 900));
      expect(sent, [
        [32, 32, 82, 83],
        ascii('OK'),
        ascii('VD'),
      ]);
      expect(h2Flags.every((f) => f), isTrue);
      link.onNotification(ascii('AT')); // la cible répond
      await t.pump(const Duration(milliseconds: 10));
      expect(sent.last, [0xC9, 0x36]);
      link.onNotification(ascii('VD')); // confirmation
      await t.pump(const Duration(seconds: 1));
      expect(sent.length, 4 + 6);
      expect(sent.last, [38, 37, 38, 97, 38, 12, 38, 160]);
      // Fléchette négociée : « D1 » = ligne 0 colonne 0 avec la clé 0xC9
      final dart = [65 ^ 201, 49 ^ 201];
      link.onNotification(dart);
      expect(got.single, dart);
      expect(labelOf(VdartsDecoder().accept(got.single)), 'D4 (8)');
      link.close();
      await t.pump(const Duration(seconds: 5));
    });

    testWidgets('H2 : 3 essais puis arrêt si la cible ne répond pas',
        (t) async {
      var writes = 0;
      final logs = <String>[];
      final link = VdartsLink(
        family: VdartsFamily.h2,
        h3l: false,
        write: (b, {bool h2 = false}) async => writes++,
        gameplay: (_) {},
        log: logs.add,
      );
      link.start();
      await t.pump(const Duration(seconds: 20));
      expect(writes, 9, reason: '3 × (RS, OK, VD)');
      expect(logs.last, contains('arrêt'));
      link.close();
      await t.pump(const Duration(seconds: 5));
    });

    testWidgets('H2 déjà active : aucune négociation', (t) async {
      final sent = <List<int>>[];
      final got = <List<int>>[];
      final link = VdartsLink(
        family: VdartsFamily.h2,
        h3l: false,
        write: (b, {bool h2 = false}) async => sent.add(b),
        gameplay: got.add,
      );
      link.onNotification(pair(20, Ring.triple));
      link.onGameFrame();
      link.start();
      await t.pump(const Duration(seconds: 3));
      expect(sent, isEmpty);
      link.onNotification(pair(19, Ring.triple));
      expect(got.length, 2);
      link.close();
      await t.pump(const Duration(seconds: 5));
    });
  });

  test('BoardService : une VDarts envoie des fléchettes aux jeux', () async {
    final s = BoardService.instance;
    s.debugUseVdarts('VDarts H3');
    final events = <BoardEvent>[];
    final sub = s.events.listen(events.add);
    s.injectFrame(pair(20, Ring.triple));
    s.injectFrame(ascii('AT'));
    s.injectFrame([0x9F, 0xE7]);
    await Future<void>.delayed(Duration.zero);
    expect(s.isVdarts, isTrue);
    expect(labelOf(events), 'T20 (60), BOUTON');
    await sub.cancel();
    await s.disconnect();
    expect(s.isVdarts, isFalse);
  });
}
