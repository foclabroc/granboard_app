import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granboard_proto/board_service.dart';
import 'package:granboard_proto/game/bot.dart';
import 'package:granboard_proto/game/personas.dart';
import 'package:granboard_proto/game/x01.dart';
import 'package:granboard_proto/granboard.dart';
import 'package:granboard_proto/media.dart';
import 'package:granboard_proto/players.dart';
import 'package:granboard_proto/rank.dart';
import 'package:granboard_proto/ui/setup_page.dart';
import 'package:granboard_proto/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_server.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FakeServer().install();
    await PlayerStore.instance.load();
    await BoardService.instance.init();
    await PersonaRecords.instance.load();
  });

  test('9 personnages du plus faible au plus fort, portraits présents', () {
    expect(kPersonas.length, 9);
    for (var i = 1; i < kPersonas.length; i++) {
      expect(kPersonas[i].note, greaterThan(kPersonas[i - 1].note));
    }
    expect(rankOf(kPersonas.first.note).label, 'C');
    expect(rankOf(kPersonas.last.note).label, 'GM');
    expect(personaOf('guest-bot-sarah')?.name, 'Sarah');
    expect(personaOf('guest-bot1'), isNull);
    expect(isBotId('guest-bot-sarah'), isTrue);
    expect(PlayerStore.instance.ratingOf('guest-bot-boss'), 20);
    for (final p in kPersonas) {
      expect(MediaStore.instance.soundOf(p.playerId), 'bot_${p.id}');
      expect(File('assets/sounds/turn/bot_${p.id}.ogg').existsSync(), isTrue,
          reason: p.id);
    }
  });

  test(
      'Niveau fixe : le Boss vise bien mieux qu\'Enzo, quels que soient '
      'les humains', () {
    X01Game game(String bot) => X01Game(const X01Settings(), [
          const X01Player(id: 'guest-1', name: 'Moi'),
          X01Player(id: bot, name: 'B')
        ])
          ..throwDart(null)
          ..throwDart(null)
          ..throwDart(null)
          ..next();
    final (enzo, _) = Bot.target(game('guest-bot-enzo'), (_) => 15);
    final (boss, _) = Bot.target(game('guest-bot-boss'), (_) => 1);
    expect(enzo, closeTo(bandValue(2, kPprBounds), .01));
    expect(boss, closeTo(bandValue(20, kPprBounds), .01));
    expect(boss, greaterThan(enzo * 2.5));
  });

  test('Bilan et progression : battre un personnage débloque le suivant',
      () async {
    final rec = PersonaRecords.instance;
    expect(rec.unlocked(kPersonas[0]), isTrue);
    expect(rec.unlocked(kPersonas[1]), isFalse);
    X01Game finished({required bool humanWins}) {
      final g = X01Game(const X01Settings(startScore: 101, roundLimit: 1), [
        const X01Player(id: 'guest-1', name: 'Moi'),
        const X01Player(id: 'guest-bot-enzo', name: 'Enzo'),
      ]);
      // manche unique : le plus petit reste gagne
      if (humanWins) {
        g.throwDart(const DartHit(20, 3, Ring.triple));
      } else {
        g.throwDart(null);
      }
      g.next();
      if (humanWins) {
        g.throwDart(null);
      } else {
        g.throwDart(const DartHit(20, 3, Ring.triple));
      }
      g.next();
      return g;
    }

    await rec.record(finished(humanWins: false));
    expect(rec.of('enzo'), (0, 1));
    expect(rec.unlocked(kPersonas[1]), isFalse);
    await rec.record(finished(humanWins: true));
    expect(rec.of('enzo'), (1, 1));
    expect(rec.unlocked(kPersonas[1]), isTrue);
    expect(rec.unlocked(kPersonas[2]), isFalse);
    await rec.load(); // relu des réglages
    expect(rec.of('enzo'), (1, 1));
  });

  testWidgets('Ajouter des joueurs › Adversaires : galerie, verrou, ajout',
      (t) async {
    t.view.physicalSize = const Size(2160, 1080);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    await t.pumpWidget(
        MaterialApp(theme: Tv.theme(), home: const SetupPage(kind: 'x01')));
    await t.pumpAndSettle();
    await t.ensureVisible(find.byKey(const ValueKey('players-add')));
    await t.tap(find.byKey(const ValueKey('players-add')));
    await t.pumpAndSettle();
    await t.ensureVisible(find.byKey(const ValueKey('add-persona')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('add-persona')));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.byKey(const ValueKey('persona-boss')), findsOneWidget);
    // Chloé verrouillée : AJOUTER grisé
    await t.tap(find.byKey(const ValueKey('persona-chloe')));
    await t.pump();
    expect(find.textContaining('Bats d\'abord Enzo'), findsOneWidget);
    expect(
        t
            .widget<FilledButton>(find.byKey(const ValueKey('persona-add')))
            .onPressed,
        isNull);
    await t.tap(find.byKey(const ValueKey('persona-enzo')));
    await t.pump();
    await t.ensureVisible(find.byKey(const ValueKey('persona-add')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('persona-add')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('in-guest-bot-enzo')), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
