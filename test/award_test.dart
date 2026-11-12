import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:granboard_proto/granboard.dart';
import 'package:granboard_proto/ui/award.dart';

const t20 = DartHit(20, 3, Ring.triple);
const t19 = DartHit(19, 3, Ring.triple);
const t18 = DartHit(18, 3, Ring.triple);
const d16 = DartHit(16, 2, Ring.double);
const s20 = DartHit(20, 1, Ring.singleOuter);
const bull = DartHit(25, 2, Ring.innerBull);
const outer = DartHit(25, 1, Ring.outerBull);

void main() {
  test('Coups réussis du 01', () {
    Award? x(List<DartHit?> d) => awardOf(d,
        total: d.whereType<DartHit>().fold<int>(0, (a, h) => a + h.score));
    expect(x([t20, t20, t20]), Award.ton80);
    expect(x([t20, t20, t19]), Award.highTon); // 177
    expect(x([t20, t19, t18]), Award.highTon); // 171, pas de White Horse en 01
    expect(x([t20, t20, s20]), Award.lowTon); // 140
    expect(x([t20, s20, s20]), Award.lowTon); // 100
    expect(x([t19, s20, s20]), isNull); // 97
    expect(x([bull, bull, bull]), Award.threeInTheBlack);
    expect(x([bull, outer, bull]), Award.hatTrick);
    expect(x([t19, t19, t19]), Award.threeInABed); // 171 mais même triple
    expect(x([d16, d16, d16]), Award.threeInABed);
    expect(x([s20, s20, s20]), isNull);
    expect(x([t20, t20, null]), Award.lowTon); // 120 en 2 fléchettes
    expect(x([t20, t20]), isNull); // manche pas finie
  });

  test('Coups réussis sans total (Cricket, entraînement)', () {
    expect(awardOf([t20, t20, t20]), Award.threeInABed);
    expect(awardOf([t20, t19, t18], whiteHorse: true), Award.whiteHorse);
    expect(awardOf([t20, t19, t18]), isNull);
    expect(awardOf([t20, t20, t19], whiteHorse: true), isNull);
    expect(awardOf([outer, outer, outer]), Award.hatTrick);
    expect(awardOf([t20, null, t20]), isNull);
  });

  test('Animations d\'une fléchette : triple 20, bull, double bull', () {
    expect(HitClip.of(t20), HitClip.triple20);
    expect(HitClip.of(bull), HitClip.doubleBull);
    expect(HitClip.of(outer), HitClip.bull);
    expect(HitClip.of(t19), isNull);
    expect(HitClip.of(s20), isNull);
    expect(HitClip.of(null), isNull);
    final used = <String>{};
    for (final c in HitClip.values) {
      for (var seed = 0; seed < 20; seed++) {
        final f = c.randomAsset(Random(seed));
        expect(File(f).existsSync(), isTrue, reason: f);
        used.add(f);
      }
    }
    expect(used.length, 6);
  });

  test('Chaque coup a ses animations dans assets/awards', () {
    final used = <String>{};
    for (final a in Award.values) {
      for (var seed = 0; seed < 40; seed++) {
        final f = a.randomAsset(Random(seed));
        expect(File(f).existsSync(), isTrue, reason: f);
        used.add(f);
      }
    }
    // Toutes les vidéos fournies servent, au hasard
    final all = Directory('assets/awards')
        .listSync()
        .map((f) => f.path)
        .where((p) => p.endsWith('.mp4'))
        .toSet();
    expect(used, all);
  });
}
