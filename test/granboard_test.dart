import 'package:flutter_test/flutter_test.dart';
import 'package:granboard_proto/granboard.dart';

BoardEvent _d(String s) => GranBoardDecoder.decode(s.codeUnits);

void main() {
  test('T20 = 60', () {
    final e = _d('3.4@') as HitEvent;
    expect(e.hit.number, 20);
    expect(e.hit.multiplier, 3);
    expect(e.hit.score, 60);
  });

  test('D16 est un double', () {
    final e = _d('11.6@') as HitEvent;
    expect(e.hit.score, 32);
    expect(e.hit.isDouble, isTrue);
  });

  test('Bull 50 compte comme double, bull 25 non', () {
    final inner = (_d('4.0@') as HitEvent).hit;
    final outer = (_d('8.0@') as HitEvent).hit;
    expect(inner.score, 50);
    expect(inner.isDouble, isTrue);
    expect(outer.score, 25);
    expect(outer.isDouble, isFalse);
  });

  test('Bouton', () {
    expect(_d('BTN@'), isA<ButtonEvent>());
  });

  test('Trame inconnue', () {
    expect(_d('99.9@'), isA<UnknownEvent>());
    expect(_d('n\'importe quoi'), isA<UnknownEvent>());
  });

  test('Les 82 zones sont toutes différentes', () {
    final seen = <String>{};
    for (final row in List.generate(12, (i) => i)) {
      for (final col in List.generate(7, (i) => i)) {
        final e = _d('$row.$col@');
        if (e is HitEvent) {
          expect(seen.add('${e.hit.ring}-${e.hit.number}'), isTrue,
              reason: '$row.$col en double');
        }
      }
    }
    expect(seen.length, 82);
  });
}
