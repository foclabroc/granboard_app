import 'package:flutter/material.dart';

import '../game/cricket.dart';
import '../game/darts_game.dart';
import '../game/match.dart';
import '../game/practice.dart';
import '../game/x01.dart';
import 'theme.dart';
import '../format.dart';

/// Règles du 01 selon les réglages de la partie.
String x01Rules(X01Settings s) {
  final lines = <String>[
    'Chacun part de ${s.startScore} et retire ce qu\'il marque. Le premier '
        'à tomber pile à 0 gagne.',
    switch (s.inRule) {
      InRule.open => 'Début libre : toute fléchette compte.',
      InRule.double =>
        'Double In : il faut un double pour commencer à marquer.',
      InRule.master =>
        'Master In : il faut un double, un triple ou un bull pour commencer '
            'à marquer.',
    },
    switch (s.outRule) {
      OutRule.open => 'Fin libre : n\'importe quelle fléchette peut finir.',
      OutRule.double =>
        'Double Out : la dernière fléchette doit être un double.',
      OutRule.master =>
        'Master Out : la dernière fléchette doit être un double, un triple '
            'ou un bull.',
    },
    'Bust : si tu dépasses${s.outRule == OutRule.open ? '' : ' ou si tu ne peux plus finir'}, '
        'la manche est annulée et tu reviens au score du début de manche.',
    s.bullMode == BullMode.split
        ? 'Bull : 25 à l\'extérieur, 50 au centre.'
        : 'Bull : 50 partout (compte comme un double).',
    if (s.freeze)
      'Freeze : 2 équipes. Une équipe dont le total restant dépasse celui '
          'de l\'adversaire est gelée et ne peut pas finir.',
    if (s.roundLimit != null)
      'Limite de ${plural(s.roundLimit!, 'manche')} : ensuite, le plus petit reste gagne.',
  ];
  return lines.join('\n');
}

/// Règles du Cricket selon les réglages.
String cricketRules(CricketSettings s) => [
      s.variant.help,
      'Simple = 1 marque, double = 2, triple = 3.',
      if (s.teams) 'Équipes : marques et points sont communs à l\'équipe.',
      if (s.roundLimit != null)
        'Limite de ${plural(s.roundLimit!, 'manche')} : ensuite, '
            '${!s.variant.scoring ? 'le plus de marques gagne' : s.variant.cutThroat ? 'le plus petit score gagne (égalité : le plus de marques)' : 'le plus gros score gagne (égalité : le plus de marques)'}.',
    ].join('\n');

/// Règles d'un match.
String matchRules(MatchSettings s) =>
    'Série de ${s.legs} legs : le premier à ${s.winsNeeded} legs gagne le '
    'match. Le joueur qui commence change à chaque leg.';

/// Nom et règles de la partie en cours (pour un match : le match, puis le
/// leg en cours).
(String, String) rulesOf(DartsGame game) => switch (game) {
      MatchGame m => (
          'Match ${m.settings.legs} legs',
          '${matchRules(m.settings)}\n\n'
              '${rulesOf(m.leg).$1.toUpperCase()}\n${rulesOf(m.leg).$2}'
        ),
      PracticeGame g => (
          kPracticeInfo[g.settings.kind]!.name,
          kPracticeInfo[g.settings.kind]!.help
        ),
      CricketGame g => (g.settings.name, cricketRules(g.settings)),
      X01Game g => (g.settings.name, x01Rules(g.settings)),
      _ => (game.title, game.rulesLabel),
    };

/// Petite fenêtre « Règles ».
Future<void> showRules(BuildContext context, String title, String text) =>
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('RÈGLES · ${title.toUpperCase()}',
            style: Tv.title(22, color: Tv.gold)),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            child: Text(text,
                style: Tv.label(14, color: Tv.text).copyWith(height: 1.35)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );

/// Petit bouton « Règles » (réglages, partie).
class RulesButton extends StatelessWidget {
  final String title;
  final String text;
  const RulesButton({super.key, required this.title, required this.text});

  @override
  Widget build(BuildContext context) => TextButton.icon(
        style: TextButton.styleFrom(
          foregroundColor: Tv.goldLight,
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: const Size(0, 32),
        ),
        onPressed: () => showRules(context, title, text),
        icon: const Icon(Icons.help_outline, size: 16),
        label: Text('RÈGLES', style: Tv.title(13, color: Tv.goldLight)),
      );
}
