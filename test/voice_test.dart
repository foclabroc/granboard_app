import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:granboard_proto/ui/game_fx.dart';
import 'package:granboard_proto/voice.dart';

void main() {
  final bank = VoiceBank(
      (jsonDecode(File('assets/voice/index.json').readAsStringSync()) as Map)
          .cast<String, String>());
  final names = ['Foc', 'Sophie', 'Invité 1'];

  /// Résumé d'un découpage : « # » = voix enregistrée, sinon le texte lu
  /// par la synthèse vocale.
  String plan(String text) => bank
      .plan(text, names)
      .map((p) => p.clip != null ? '#' : p.text!)
      .join('|');

  test('Mots : ponctuation, signes', () {
    expect(
        voiceTokens('Bust ! Équipe gelée.'), ['bust', '!', 'équipe', 'gelée']);
    expect(voiceTokens('bonus +50 -3 ÷ 2 12/20 cache-cache'), [
      'bonus',
      'plus',
      '50',
      'moins',
      '3',
      'divisé',
      'par',
      '2',
      '12',
      'sur',
      '20',
      'cache',
      'cache'
    ]);
  });

  test('Chaque fichier de l\'index existe', () {
    for (final f in bank.index.values) {
      expect(File('assets/voice/$f').existsSync(), isTrue, reason: f);
    }
  });

  test('Annonces du 01 et du Cricket : tout est enregistré sauf les pseudos',
      () {
    for (var n = 0; n <= 180; n++) {
      expect(plan('$n'), '#');
      if (n >= 100) expect(plan('$n !'), '#');
      if (n >= 2 && n <= 170) expect(plan('Foc, il te reste $n'), 'Foc|#');
    }
    // Après 3 fléchettes : ce qu'il reste (01 de 901 compris)
    for (var n = 1; n <= 901; n++) {
      expect(plan('triple 20, Il reste $n'), '#|#', reason: '$n');
    }
    expect(plan('Cent quatre-vingts ! Il reste 321'), '#|#');
    expect(bank.plan('140 !').single.clip, bank.index['140 !']);
    expect(bank.plan('140').single.clip, bank.index['140']);
    expect(plan('Cent quatre-vingts !'), '#');
    expect(plan('Bust ! Équipe gelée.'), '#');
    expect(plan('Bust !'), '#');
    expect(plan('501. Foc, à toi.'), '#|Foc|#');
    expect(plan('Freeze 301. Invité 1, à toi.'), '#|Invité 1|#');
    expect(plan('Sophie, ton équipe est gelée'), 'Sophie|#');
    expect(plan('Foc, à toi. Il te reste 32'), 'Foc|#|#');
    expect(plan('Foc, à toi. Ton équipe est gelée'), 'Foc|#|#');
    expect(plan('Foc, à toi. Spoiler'), 'Foc|#|#');
    expect(plan('Foc, à toi. cible double 16'), 'Foc|#|#');
    expect(plan('Foc, à toi. prends des numéros'), 'Foc|#|#');
    expect(plan('Sophie'), 'Sophie');
    expect(plan('7 marques !'), '#');
    expect(plan('Bull découvert !'), '#');
    expect(plan('Team Cut Throat caché. Foc, à toi.'), '#|Foc|#');
    expect(plan('Foc, spoiler'), 'Foc|#');
    expect(
        plan('Partie gagnée ! Victoire de Foc et Sophie !'), '#|Foc|#|Sophie');
    expect(plan('Fin de la partie. Victoire de Équipe A : Foc et Sophie.'),
        '#|#|Foc|#|Sophie');
    expect(plan('Match en 5 legs. Leg 1, 501. Foc, à toi.'), '#|#|Foc|#');
    expect(plan('Medley en 5 legs. Leg 1, 501. Foc, à toi.'), '#|#|Foc|#');
    expect(plan('Leg 3, Cricket. Sophie, à toi.'), '#|#|Sophie|#');
    expect(plan('Leg pour Foc ! 2 à 1.'), '#|Foc|#');
    expect(plan('Jeu, set et match ! Victoire de Sophie !'), '#|Sophie');
    expect(plan('Sophie te défie'), 'Sophie|#');
    expect(plan('Nouvelle cible : bull'), '#');
  });

  test('Entraînement et fête', () {
    expect(plan('Foc, cible double 16'), 'Foc|#');
    expect(plan('Foc, cible bull'), 'Foc|#');
    expect(plan('mission réussie. Sophie, un triple'), '#|Sophie|#');
    expect(plan('araignée abattue +50'), '#|#|#');
    expect(plan('Fin de l\'entraînement. Score : 12/20.'), '#|#|#|#');
    expect(plan('SOPHIE éliminé !'.toLowerCase()), 'sophie|#');
    // Passage inconnu : lu d'un bloc par la synthèse vocale
    expect(plan('Foc, zone mystère 42'), 'Foc|zone mystère 42');
  });

  test('Commentaires et fléchettes annoncées : tout est enregistré', () {
    bool allClips(String t) => bank.plan(t, names).every((p) => p.clip != null);
    for (var n = 1; n <= 20; n++) {
      for (final t in ['$n', 'triple $n', 'double $n']) {
        expect(allClips(t), isTrue, reason: t);
      }
    }
    for (final t in [
      'raté',
      'bull',
      '25',
      'triple 20, 140 !',
      'double 5, 46',
      'raté, Aucun point',
      'triple 19, 6 marques !',
      '15, 15 découvert !',
      'Il te reste 40, double 20',
      'Il te reste 170, triple 20, triple 20, bull',
      'Il te reste 61, 25, double 18',
      'Deuxième 180 de la soirée',
      'Dixième 180 de la soirée',
      'Encore un 180',
      'Match point',
      'Plus que 15 et bull',
      'Plus que 20',
      'Fin à 121. Plus haute fin de la soirée. Partie gagnée ! Victoire de',
      'Fin à 100. Leg pour',
    ]) {
      expect(allClips(t), isTrue, reason: '${plan(t)} ← $t');
    }
    expect(
        plan('Troisième 180 de la soirée. Match point. Foc, à toi. '
            'Il te reste 32, double 16'),
        '#|#|Foc|#|#|#');
  });

  test('Chambrage, Bowling, Paint : tout est enregistré', () {
    for (final t in [...kLowTeases, ...kBustTeases, ...kZeroMarkTeases]) {
      expect(plan(t), isNot(contains(RegExp('[a-z]'))), reason: t);
      expect(plan('Bust !, $t'), isNot(contains(RegExp('[a-z]'))), reason: t);
      expect(plan('il reste 41, $t'), isNot(contains(RegExp('[a-z]'))),
          reason: t);
    }
    for (final t in ['strike !', 'spare !', 'zone prise', 'protégée']) {
      expect(plan(t), '#', reason: t);
    }
  });
}
