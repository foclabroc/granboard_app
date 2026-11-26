import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granboard_proto/audio.dart';
import 'package:granboard_proto/game/practice.dart';
import 'package:granboard_proto/game/x01.dart';
import 'package:granboard_proto/granboard.dart';
import 'package:granboard_proto/ui/arcade/zombies_scene.dart';

void main() {
  testWidgets('Zombies : ambiance en boucle et bruitages des évènements',
      (tester) async {
    final g = PracticeGame(const PracticeSettings(PracticeKind.zombies), [
      const X01Player(id: 'guest-1', name: 'A'),
      const X01Player(id: 'guest-2', name: 'B')
    ]);
    final audio = AudioService.instance;
    await tester.pumpWidget(MaterialApp(
        home: SizedBox(
            width: 600,
            height: 340,
            child: ZombiesScene(game: g, colorOf: (_) => Colors.red))));
    expect(audio.loopAsset, 'sounds/zombies/zb_music.ogg');
    expect(find.textContaining('VAGUE 1'), findsOneWidget);
    // abattre le premier zombie
    final (horde, _) = zombiesState(g);
    final z = horde.first;
    g.throwDart(DartHit(
        z.n,
        z.m,
        z.n == 25
            ? (z.m == 2 ? Ring.innerBull : Ring.outerBull)
            : [
                Ring.singleInner,
                Ring.singleInner,
                Ring.double,
                Ring.triple
              ][z.m]));
    audio.playedFiles.clear();
    await tester.pumpWidget(MaterialApp(
        home: SizedBox(
            width: 600,
            height: 340,
            child: ZombiesScene(game: g, colorOf: (_) => Colors.red))));
    await tester.pump(const Duration(milliseconds: 300));
    expect(audio.playedFiles.any((f) => f.contains('zombies/zb_')), isTrue);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox());
    expect(audio.loopAsset, isNull);
  });
}
