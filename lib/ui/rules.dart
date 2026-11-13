import 'package:flutter/material.dart';

import '../game/cricket.dart';
import '../game/darts_game.dart';
import '../game/match.dart';
import '../game/practice.dart';
import '../game/x01.dart';
import 'theme.dart';
import '../format.dart';

// Règles détaillées de tous les jeux, selon les réglages choisis.
// Mise en forme : « # TITRE » = intertitre, « - texte » = puce, le reste =
// paragraphe (voir [RulesText]).

const _marks = '- Simple = 1 marque, double = 2, triple = 3. Bull extérieur '
    '= 1 marque, centre = 2.';

String _bull(BullMode b) => b == BullMode.split
    ? 'Bull : 25 à l\'extérieur, 50 au centre.'
    : 'Bull : 50 partout (le 25 compte comme un double pour finir).';

// ─── 01 ───

/// Règles du 01 selon les réglages de la partie.
String x01Rules(X01Settings s) {
  final out = switch (s.outRule) {
    OutRule.open => 'n\'importe quelle fléchette',
    OutRule.double => 'un double (ou le centre du bull)',
    OutRule.master => 'un double, un triple ou le bull',
  };
  return [
    '# BUT',
    'Chacun part de ${s.startScore} et retire ce qu\'il marque. Le premier à '
        'tomber pile à 0 gagne${s.teamPlay ? ' pour son équipe' : ''}.',
    '# DÉROULEMENT',
    '- À tour de rôle, 3 fléchettes par manche. Le total de la manche est '
        'retiré de ton score.',
    '- Simple = la valeur du numéro, double (anneau extérieur) = × 2, triple '
        '(anneau du milieu) = × 3.',
    '- ${_bull(s.bullMode)}',
    '- Fléchette hors cible ou bouton RATÉ = 0. SUIVANT (ou le bouton de la '
        'cible) passe au joueur suivant : les fléchettes pas lancées comptent '
        'comme ratées.',
    '- ANNULER retire la dernière fléchette (ou le dernier SUIVANT).',
    '# DÉBUT',
    switch (s.inRule) {
      InRule.open => '- Début libre : toutes les fléchettes comptent tout de '
          'suite.',
      InRule.double => '- Double In : tant que tu n\'as pas touché un double, '
          'tes fléchettes ne comptent pas. Le double qui ouvre compte.',
      InRule.master => '- Master In : il faut un double, un triple ou un bull '
          'pour ouvrir. La fléchette qui ouvre compte.',
    },
    '# FIN',
    '- La fléchette qui t\'amène pile à 0 doit être $out.',
    if (s.outRule != OutRule.open)
      '- Il reste 1 : impossible de finir, c\'est un bust.',
    '- Quand une fin est possible, l\'appli affiche la combinaison conseillée '
        '(FIN) et la zone à viser sur la cible, avec d\'autres choix.',
    '# BUST',
    '- Si tu dépasses 0${s.outRule != OutRule.open ? ', s\'il te reste 1, ou si tu finis sur une mauvaise fléchette' : ''}'
        '${s.freeze ? ', ou si tu finis alors que ton équipe est gelée' : ''}'
        ' : BUST. Ta manche s\'arrête et ton score revient à celui du début '
        'de la manche.',
    if (s.freeze) ...[
      '# FREEZE (ÉQUIPES)',
      '- 2 équipes de même taille. On alterne : joueur 1 de l\'équipe A, '
          'joueur 1 de l\'équipe B, joueur 2 de A, joueur 2 de B…',
      '- Chaque joueur a son propre score. Le total de l\'équipe = la somme '
          'des scores de ses joueurs.',
      '- Une équipe dont le total est plus grand que celui de l\'adversaire '
          'est GELÉE : ses joueurs marquent toujours, mais ne peuvent pas '
          'finir (bust).',
      '- Le premier joueur qui finit fait gagner toute son équipe.',
    ],
    if (s.doubles) ...[
      '# DOUBLE (ÉQUIPES)',
      '- 2 équipes. On alterne : joueur 1 de l\'équipe A, joueur 1 de '
          'l\'équipe B, joueur 2 de A, joueur 2 de B…',
      '- Les coéquipiers partagent le MÊME score : ce que marque l\'un est '
          'retiré du score de l\'équipe.',
      '- Le joueur qui finit fait gagner son équipe. Chacun garde sa propre '
          'moyenne dans les stats.',
    ],
    if (s.roundLimit != null) ...[
      '# LIMITE DE MANCHES',
      '- Après ${plural(s.roundLimit!, 'manche')}, le plus petit score '
          'restant gagne${s.freeze ? ' (total de l\'équipe)' : ''}.',
    ],
  ].join('\n');
}

// ─── Cricket ───

String _variantRules(CricketVariant v) => switch (v) {
      CricketVariant.standard => '',
      CricketVariant.cutThroat => [
          '# CUT THROAT',
          '- Les points vont aux ADVERSAIRES : marquer sur un numéro que tu as '
              'fermé donne les points à chaque adversaire qui ne l\'a pas '
              'fermé.',
          '- Le PLUS PETIT score gagne : tout fermer avec un score plus petit '
              'ou égal à celui de chacun des autres.',
          '- À 3 joueurs ou plus, SPOILER s\'affiche quand un adversaire a '
              'tout fermé avec moins de points que toi.',
        ].join('\n'),
      CricketVariant.hidden => [
          '# CRICKET CACHÉ',
          '- 7 cibles tirées au hasard parmi 1 à 20 et le bull, cachées au '
              'départ.',
          '- Toucher un numéro caché le découvre pour tout le monde, et cette '
              'fléchette compte déjà ses marques.',
          '- Ensuite, règles du Cricket.',
        ].join('\n'),
      CricketVariant.hiddenCutThroat => [
          '# CUT THROAT CACHÉ',
          '- Les 7 cibles sont cachées comme au Cricket caché (une touche les '
              'découvre et compte).',
          '- Les points sont donnés aux adversaires comme au Cut Throat : le '
              'plus petit score gagne.',
        ].join('\n'),
      CricketVariant.wildcard => [
          '# WILDCARD',
          '- 6 numéros tirés au hasard entre 7 et 20, plus le bull.',
          '- À la fin de chaque manche, chaque numéro que personne n\'a encore '
              'marqué est retiré au sort (il peut retomber le même). Un numéro '
              'marqué au moins une fois ne bouge plus. Le bull ne change '
              'jamais.',
        ].join('\n'),
      CricketVariant.noScore => [
          '# NO SCORE',
          '- Pas de points : les marques en trop ne rapportent rien.',
          '- Le premier qui ferme tous les numéros gagne.',
        ].join('\n'),
      CricketVariant.tripleOnly => [
          '# TRIPLE ONLY',
          '- 20 à 15, sans le bull.',
          '- Seuls les triples comptent : un triple ferme le numéro d\'un coup. '
              'Simples et doubles ne marquent rien.',
          '- Un triple sur un numéro déjà fermé rapporte 3 × sa valeur (si un '
              'adversaire ne l\'a pas fermé).',
        ].join('\n'),
      CricketVariant.mickeyMouse => [
          '# MICKEY MOUSE',
          '- Cibles : 20 à 12, puis D (doubles), T (triples) et le bull.',
          '- D se marque avec n\'importe quel double dont le numéro ne sert à '
              'rien (pas une cible, ou fermé par tout le monde) : 1 marque. '
              'Pareil pour T avec un triple.',
          '- Une fois D ou T fermés, ces doubles / triples rapportent leur '
              'valeur en points.',
        ].join('\n'),
    };

/// Règles du Cricket selon les réglages.
String cricketRules(CricketSettings s) {
  final v = s.variant;
  final targets = switch (v) {
    CricketVariant.tripleOnly => '20, 19, 18, 17, 16 et 15',
    CricketVariant.mickeyMouse => '20 à 12, D, T et le bull',
    CricketVariant.hidden ||
    CricketVariant.hiddenCutThroat =>
      '7 numéros cachés',
    CricketVariant.wildcard => '6 numéros de 7 à 20 et le bull',
    _ => '20, 19, 18, 17, 16, 15 et le bull',
  };
  return [
    '# BUT',
    v == CricketVariant.noScore
        ? 'Fermer le premier tous les numéros : $targets.'
        : v.cutThroat
            ? 'Fermer tous les numéros ($targets) en ayant le plus petit score.'
            : 'Fermer tous les numéros ($targets) en ayant le plus gros score.',
    '# MARQUES',
    _marks,
    '- 3 marques ferment un numéro pour toi. Les autres numéros ne comptent '
        'pas.',
    '- Un numéro fermé par tout le monde est MORT (barré) : plus rien à y '
        'faire.',
    if (v.scoring) ...[
      '# POINTS',
      '- Les marques en plus sur un numéro que tu as fermé rapportent sa '
          'valeur à chaque fois (bull = 25), tant qu\'au moins un adversaire '
          'ne l\'a pas fermé.',
      '- Exemple : 20 fermé, triple 20 = 60 points.',
      if (!v.cutThroat)
        '- Fermer vite les numéros où l\'adversaire marque l\'empêche de '
            'continuer.',
    ],
    if (_variantRules(v).isNotEmpty) _variantRules(v),
    '# FIN',
    v == CricketVariant.noScore
        ? '- Le premier qui a tout fermé gagne tout de suite.'
        : v.cutThroat
            ? '- Tout fermé avec un score plus petit ou égal à celui de chacun '
                'des autres : victoire tout de suite. Sinon on continue.'
            : '- Tout fermé avec un score plus grand ou égal à celui de chacun '
                'des autres : victoire tout de suite. Sinon on continue à '
                'marquer pour passer devant.',
    if (s.roundLimit != null)
      '- Après ${plural(s.roundLimit!, 'manche')} : '
          '${!v.scoring ? 'le plus de marques gagne' : v.cutThroat ? 'le plus petit score gagne, à égalité le plus de marques' : 'le plus gros score gagne, à égalité le plus de marques'}.'
    else
      '- Pas de limite de manches.',
    if (s.teams) ...[
      '# ÉQUIPES',
      '- Les marques et les points sont communs à l\'équipe : ce que ferme un '
          'joueur est fermé pour ses coéquipiers.',
    ],
    '# PENDANT LA PARTIE',
    '- 3 fléchettes par tour. RATÉ = 0, SUIVANT passe au joueur suivant, '
        'ANNULER retire la dernière action.',
    '- MPR = moyenne de marques par manche.',
  ].join('\n');
}

// ─── Match ───

/// Règles d'un match (sans celles des legs).
String matchRules(MatchSettings s) => [
      '# BUT',
      'Gagner ${s.winsNeeded} legs avant les autres (match en ${s.legs} legs).',
      '# DÉROULEMENT',
      '- Chaque leg est une partie complète de 01 ou de Cricket, dans l\'ordre '
          'choisi : ${s.patternLabel} (CR = Cricket).',
      '- Le joueur qui commence change à chaque leg.',
      '- À la fin d\'un leg, LEG SUIVANT lance le suivant. Le match s\'arrête '
          'dès qu\'un joueur a ${s.winsNeeded} legs (les legs restants ne sont '
          'pas joués).',
      '- Chaque leg compte dans les statistiques de son jeu (moyenne pour le '
          '01, MPR pour le Cricket).',
      '- Sur un leg de 01, l\'annonceur dit « Match point » quand un joueur '
          'peut finir et gagner le match.',
    ].join('\n');

String _matchFull(MatchSettings s) => [
      matchRules(s),
      '# LEGS DE ${s.x01.name.toUpperCase()}',
      x01Rules(s.x01).replaceAll('# ', '## '),
      '# LEGS DE CRICKET',
      cricketRules(s.cricket).replaceAll('# ', '## '),
    ].join('\n');

/// Règles complètes d'un match (match + 01 + Cricket).
String matchFullRules(MatchSettings s) => _matchFull(s);

// ─── Entraînement et fête ───

String _goalLine(PracticeSettings s, String unit) => s.goalOrDefault == 0
    ? '- En 10 manches : le plus de $unit gagne.'
    : '- Le premier à ${s.goalOrDefault} $unit gagne tout de suite.';

/// Règles détaillées d'un jeu d'entraînement ou de fête.
String practiceRules(PracticeSettings s) {
  final i = s.info;
  final bull = s.bull == BullMode.fat
      ? 'Bull = 50 partout.'
      : 'Bull = 25 à l\'extérieur, 50 au centre.';
  final t = s.target == 25 ? 'le bull' : 'le ${s.target}';
  final List<String> body = switch (s.kind) {
    PracticeKind.countUp => [
        '# BUT',
        'Faire le plus gros total en ${plural(s.roundsOrDefault, 'manche')}.',
        '# POINTS',
        '- Chaque fléchette rapporte sa valeur : simple, double × 2, triple '
            '× 3. $bull',
        '- 33 manches = le défi des 99 fléchettes.',
        '- La moyenne aux 3 fléchettes s\'affiche pendant la partie.',
      ],
    PracticeKind.target20 => [
        '# BUT',
        'Toucher le 20 le plus souvent possible.',
        '# TOUCHES',
        '- Simple 20 = 1 touche, double 20 = 2, triple 20 = 3. Le reste ne '
            'compte pas.',
        _goalLine(s, 'touches'),
        '- Le pourcentage de réussite s\'affiche pendant la partie.',
      ],
    PracticeKind.targetBull => [
        '# BUT',
        'Toucher le bull le plus souvent possible.',
        '# TOUCHES',
        '- Bull extérieur (25) = 1 touche, centre (50) = 2.',
        _goalLine(s, 'touches'),
      ],
    PracticeKind.targetChoice => [
        '# BUT',
        'Toucher la cible de ton choix (1 à 20 ou bull).',
        '# TOUCHES',
        '- Simple = 1 touche, double = 2, triple = 3 (bull : 25 = 1, 50 = 2).',
        '- CHANGER : tu peux changer de cible au début de chacun de tes tours, '
            'avant ta 1re fléchette. Chaque joueur a sa cible.',
        '- Le premier à ${s.goalOrDefault} touches gagne tout de suite.',
      ],
    PracticeKind.targetHat => [
        '# BUT',
        'Réussir des HAT TRICKS sur $t.',
        '# RÈGLES',
        '- Hat trick = tes 3 fléchettes du tour dans $t (simple, double ou '
            'triple, peu importe).',
        '- Une seule fléchette à côté et le tour ne compte pas.',
        '- Le premier à ${plural(s.goalOrDefault, 'hat trick')} gagne. Pas de '
            'limite de manches.',
      ],
    PracticeKind.targetHorse => [
        '# BUT',
        'Réussir des WHITE HORSE.',
        '# RÈGLES',
        '- White Horse = 3 triples dans le même tour, sur 3 numéros DIFFÉRENTS '
            'parmi 15, 16, 17, 18, 19 et 20.',
        '- Les triples encore possibles s\'allument sur la cible.',
        '- Le premier à ${s.goalOrDefault} White Horse gagne. Pas de limite '
            'de manches.',
      ],
    PracticeKind.halfIt => [
        '# BUT',
        'Finir les 9 manches avec le plus gros score. Départ à 40.',
        '# MANCHES',
        '- 1 : le 15 · 2 : le 16 · 3 : n\'importe quel double · 4 : le 17 · '
            '5 : le 18 · 6 : n\'importe quel triple · 7 : le 19 · 8 : le 20 · '
            '9 : le bull.',
        '# POINTS',
        '- Chaque fléchette sur la cible de la manche ajoute sa valeur '
            '(double 16 = 32, triple 19 = 57…). $bull',
        '- Aucune touche dans la manche : ton score est divisé par 2 '
            '(arrondi en dessous).',
      ],
    PracticeKind.deltaShoot => [
        '# BUT',
        'Finir les 16 manches avec le plus gros score. Départ à 0.',
        '# MANCHES',
        '- 10, 11, 12, double ou triple, 13, 14, double, 15, 16, 17, triple, '
            '18, 19, 20, bull, double bull (centre).',
        '# POINTS',
        '- Chaque fléchette sur la cible de la manche ajoute sa valeur. $bull',
        '- Aucune touche dans la manche : score divisé par 2.',
      ],
    PracticeKind.rotation => [
        '# BUT',
        'Faire le tour de la cible : 1, 2, 3… jusqu\'au 20, puis 3 bulls.',
        '# RÈGLES',
        if (s.has('double'))
          '- Doubles seulement : il faut toucher le double de chaque numéro '
              '(le bull, n\'importe lequel).'
        else if (s.has('triple'))
          '- Triples seulement : il faut toucher le triple de chaque numéro '
              '(le bull, n\'importe lequel).'
        else
          '- Simple, double ou triple : toute touche sur le bon numéro le '
              'valide.',
        '- Chaque cible touchée rapporte son numéro (bull = 25) et tu passes '
            'à la suivante.',
        '- Touche avec la dernière fléchette du tour : 3 fléchettes de plus '
            '(autant de fois que tu continues à toucher).',
        '- 3e bull : fini. En moins de 8 manches, bonus de 100 par manche '
            'gagnée (fini en 5 manches = +300).',
        '# FIN',
        '- La partie s\'arrête dès qu\'un joueur a fini (ou après 20 manches) : '
            'le plus gros score gagne.',
      ],
    PracticeKind.shootForce => [
        '# BUT',
        'Le plus gros score en 8 manches, en touchant 1, 2, 3… jusqu\'au 20, '
            'puis le bull.',
        '# POINTS',
        '- Chaque touche sur ta cible vaut sa valeur (simple, double, triple) '
            '× ta SÉRIE : le nombre de touches d\'affilée, même d\'un tour sur '
            'l\'autre. Une fléchette ratée remet la série à 0.',
        '- Une touche fait passer au numéro suivant.',
        '- 3 triples dans le même tour : +3000.',
        '- Le bull à la fin : extérieur = 10 000, centre = 100 000, et tu as '
            'fini.',
      ],
    PracticeKind.oniren => [
        '# BUT',
        'Valider le plus de manches possible avec 3 vies.',
        '# RÈGLES',
        '- À chaque manche, un numéro est tiré au hasard (le même pour tout '
            'le monde).',
        '- Pour valider : au moins 2 simples ET 1 double ou triple sur ce '
            'numéro, dans le même tour.',
        '- Manche validée = +1. Manche ratée = une vie en moins. À 0 vie, tu '
            'es éliminé.',
        '- Jusqu\'à 99 manches. Le plus de manches validées gagne.',
      ],
    PracticeKind.crCountUp => [
        '# BUT',
        'Le plus gros score sur les numéros du Cricket, en 8 manches.',
        '# MANCHES',
        '- 1 : le 20 · 2 : le 19 · 3 : le 18 · 4 : le 17 · 5 : le 16 · '
            '6 : le 15 · 7 : le bull · 8 : au choix le 15, le 20 ou le bull.',
        '# POINTS',
        '- Seules les fléchettes sur le numéro de la manche comptent, à leur '
            'valeur (triple 20 = 60). $bull',
      ],
    PracticeKind.crMultiple => [
        '# BUT',
        'Le plus gros score en 7 manches : 20, 19, 18, 17, 16, 15, bull.',
        '# POINTS',
        '- Sur le numéro de la manche, la 1re fléchette compte × 1, la 2e '
            '× 2, la 3e × 3 (triple 20 en 3e fléchette = 180).',
        '- Manches 4 et 7 : 3 numéros bonus (entre 1 et 14) s\'ajoutent, '
            'affichés avec leur multiplicateur : × 2, × 4, × 6 à la manche 4, '
            '× 3, × 6, × 9 à la manche 7.',
        '- Rien touché dans la manche : -3 × la valeur du numéro (bull = '
            '-75).',
      ],
    PracticeKind.bobs27 => [
        '# BUT',
        'Garder le plus gros score après tous les doubles. Départ à 27.',
        '# RÈGLES',
        s.has('even')
            ? '- Une manche par double PAIR : D2, D4… D20, puis le double bull.'
            : '- Une manche par double : D1, D2… D20, puis le double bull.',
        '- Chaque touche du double ajoute sa valeur (D10 = +20, double bull '
            '= +50).',
        '- Aucune touche dans la manche : sa valeur est retirée (D10 raté = '
            '-20).',
        if (s.has('hard'))
          '- Hard : à 0 ou moins, tu es éliminé.'
        else
          '- Le score peut passer sous 0, on continue.',
      ],
    PracticeKind.checkout121 => [
        '# BUT',
        'Réussir des fins de plus en plus hautes, de 121 à 125.',
        '# RÈGLES',
        '- Tu as ${s.roundsOrDefault} fléchettes pour finir la cible pile à 0 '
            'en Double Out (la dernière fléchette sur un double ou le centre '
            'du bull).',
        '- Réussi : la cible monte de 1 (121 → 122…) et ta manche s\'arrête.',
        '- Raté (fléchettes épuisées) : la cible baisse de 1 (jamais sous '
            '121).',
        '- Dépasser, ou laisser 1 : BUST, retour au score du début de la '
            'manche et la manche s\'arrête (les fléchettes sont utilisées).',
        '# FIN',
        '- Le premier qui réussit 125 gagne. Sinon, après 30 manches, la '
            'plus haute cible gagne.',
      ],
    PracticeKind.spider => [
        '# BUT',
        'Abattre les 8 araignées en 15 manches, avec le plus gros score.',
        '# RÈGLES',
        '- Chaque araignée a un nombre (de plus en plus grand). Ramène-le pile '
            'à 0 avec tes fléchettes.',
        '- Dépasser 0 : TROP ! Le nombre revient à celui du début du tour et '
            'ton tour s\'arrête.',
        '# POINTS',
        '- Chaque fléchette qui compte ajoute sa valeur à ton score.',
        '- Araignée abattue : + son nombre, × 2 si la dernière fléchette est '
            'un double ou un triple.',
        '- COMBO : tour de 3 fléchettes sans aucune perdue = + le total du '
            'tour.',
        '- Les 8 abattues : +500 par manche restante, et tu as fini.',
      ],
    PracticeKind.pirates => [
        '# BUT',
        'Couler 3 navires en visant le bull, le plus vite possible.',
        '# RÈGLES',
        '- Seul le bull compte. '
            '${s.has('master') ? 'Master : seul le centre (50) compte.' : s.has('kids') ? 'Kids : tout le bull vaut 50.' : bull}',
        '- Chaque navire a 200 points de vie. Tes bulls lui retirent leur '
            'valeur et s\'ajoutent à ton score. Le reste passe au navire '
            'suivant.',
        '- 3 navires coulés : CHANCE AU TRÉSOR au tour suivant. Chaque bull '
            'ouvre un coffre : +300 (extérieur) ou +500 (centre).',
        '- Après la chance au trésor : bonus de vitesse de 100 par manche '
            'restante, et tu as fini.',
        '- ${s.has('kids') ? '12' : '15'} manches. Le plus gros score gagne.',
      ],
    // ─── Fête ───
    PracticeKind.funMission => [
        '# BUT',
        'Réussir des missions pour prendre les vies de l\'adversaire.',
        '# MISSIONS',
        '- À chaque tour, une mission tirée au hasard, jugée après tes 3 '
            'fléchettes. Exemples : un triple, un double, le bull, 60 points '
            'ou plus, moins de 30 sans rater, un numéro précis, 3 numéros '
            'différents, 2 fois le même numéro, un total pair sans rater, un '
            'numéro dans une plage, que des simples sans rater, un total de '
            '40 à 60.',
        '# À 2 JOUEURS',
        '- 4 vies chacun. Mission réussie : tu prends 1 vie à l\'adversaire. '
            'Mission ratée : rien ne se passe.',
        '- L\'adversaire à 0 vie : tu gagnes.',
        '# SEUL',
        '- Mission réussie +1 vie, ratée -1 vie. Atteins 8 vies pour gagner, '
            'à 0 c\'est perdu.',
        '- 30 manches au plus : ensuite, le plus de vies gagne.',
      ],
    PracticeKind.allFives => [
        '# BUT',
        'Atteindre pile ${s.goalOrDefault} points.',
        '# RÈGLES',
        '- Après tes 3 fléchettes, si le total du tour est un multiple de 5 '
            '(5, 10, 15…), tu marques total ÷ 5 (45 = 9 points). Sinon rien.',
        if (!s.has('miss'))
          '- Une fléchette hors cible ou ratée et le tour ne rapporte rien.'
        else
          '- Points même avec une fléchette ratée (option).',
        if (s.has('nodt'))
          '- Option : les doubles, triples et le centre du bull valent 0.',
        '- Dépasser ${s.goalOrDefault} : TROP, le tour ne compte pas.',
        '- Le premier à ${s.goalOrDefault} pile gagne.',
      ],
    PracticeKind.beyondTop => [
        '# BUT',
        'Battre à chaque tour le score du joueur d\'avant, et rester en vie.',
        '# RÈGLES',
        '- Le tout premier tour doit faire plus de 30. Ensuite, il faut faire '
            'plus que le total du tour qui vient d\'être joué.',
        '- Battu : 1 point par tranche de 10 au-dessus (battre 45 avec 72 = '
            '+2).',
        '- Pas battu (égalité comprise) : une vie en moins. 6 vies, à 0 tu es '
            'éliminé.',
        '- 10 manches, ou jusqu\'au dernier survivant. Les survivants passent '
            'devant, puis le plus de points.',
      ],
    PracticeKind.kickDown => [
        '# BUT',
        'Aller de 0 à ${s.goalOrDefault} pile, le premier.',
        '# RÈGLES',
        '- Chaque fléchette s\'ajoute à ton score.',
        '- KICK DOWN : si tu tombes exactement sur le score d\'un adversaire, '
            'il retombe à 0 !',
        '- OVER SCORE : dépasser ${s.goalOrDefault}'
            '${s.has('double') ? ', laisser 1, ou finir sans un double' : ''}'
            ' = retour au score du début de ton tour moins '
            '${s.has('prand') ? '50, 100, 150 ou 200 (au hasard)' : s.has('p150') ? '150' : '100'}'
            ' (jamais sous 0), et ton tour s\'arrête.',
        if (s.has('double'))
          '- Il faut finir sur un double (ou le centre du bull).',
        '- Le premier à ${s.goalOrDefault} gagne. 40 manches au plus.',
      ],
    PracticeKind.twoLine => [
        '# BUT',
        'Faire 2 lignes sur la grille ET avoir plus de points que l\'autre.',
        '# LA GRILLE',
        '- 5 × 5 cases : 20 numéros mélangés et 5 étoiles (les 4 coins et le '
            'centre) qui comptent pour les deux joueurs.',
        '- Une ligne = une rangée, une colonne ou une diagonale complète de '
            'tes cases (étoiles comprises).',
        '# PRENDRE ET MARQUER',
        '- Toucher un numéro libre : il est à toi (simple, double ou triple).',
        '- Toucher un de tes numéros : + sa valeur en points.',
        '- Toucher un numéro de l\'adversaire : un triple le prend tout de '
            'suite, un double le libère, un simple l\'abîme (½) et un 2e '
            'simple le libère.',
        '- 2 bulls dans le même tour : les numéros changent de place sur la '
            'grille.',
        '# FIN',
        '- 2 lignes avec plus de points que l\'adversaire : victoire tout de '
            'suite. Sinon, après 30 manches, le plus de lignes puis de points '
            'gagne.',
      ],
    PracticeKind.shanghai => [
        '# BUT',
        'Le plus gros score en ${plural(s.roundsOrDefault, 'manche')}, ou un '
            'SHANGHAI.',
        '# RÈGLES',
        '- Manche 1 = le 1, manche 2 = le 2… Seul le numéro de la manche '
            'compte.',
        '- Points = le numéro × 1, 2 ou 3 (simple, double, triple).',
        s.has('infinity')
            ? '- SHANGHAI (simple + double + triple du numéro dans le même tour) '
                '= bonus de numéro × 10, et on continue (option Infinity).'
            : '- SHANGHAI : simple + double + triple du numéro dans le même tour '
                '= victoire immédiate !',
        if (s.has('half'))
          '- Rien touché dans la manche : score divisé par 2 (option).',
      ],
    PracticeKind.hyperBull => [
        '# BUT',
        'Le plus gros score en 8 manches, en visant le centre.',
        '# POINTS',
        '- Toute la zone entre le bull et l\'anneau des triples = 50.',
        '- Bull extérieur = 75, centre = 100.',
        '- Le reste compte normalement (triples, simples extérieurs, '
            'doubles).',
        '- Maximum : 2400 (24 centres).',
      ],
    PracticeKind.hideAndSeek => [
        '# BUT',
        'Trouver les animaux cachés derrière les fenêtres, éviter le méchant.',
        '# RÈGLES',
        '- 12 fenêtres numérotées. Derrière : 6 animaux gentils (10 à 170 '
            'points), 1 méchant (-150), le reste est vide.',
        '- Touche le numéro d\'une fenêtre fermée pour l\'ouvrir : simple = '
            '20, double = 100, triple = 150, + l\'animal trouvé.',
        '- Bull : un méchant de plus se cache derrière une fenêtre fermée vide '
            '(5 méchants au plus).',
        '# FIN DE TOUR',
        '- 3 animaux trouvés dans le tour : +200.',
        '- Aucun animal : -100.',
        '- Aucune fenêtre ouverte : score divisé par 2.',
        '# FIN',
        '- Quand les 6 animaux sont trouvés, ou après 10 manches : le plus '
            'gros score gagne.',
      ],
    PracticeKind.killer => [
        '# BUT',
        'Être le dernier en vie.',
        '# DEVENIR KILLER',
        '- Chacun reçoit un numéro au hasard (affiché).',
        '- Touche le tien pour gagner des vies : ${s.has('double') ? 'seuls les doubles comptent (1 vie)' : s.has('triple') ? 'seuls les triples comptent (1 vie)' : 'simple 1, double 2, triple 3'}, '
            '3 vies au plus.',
        s.has('onehit')
            ? '- Killer en une touche : 1 vie suffit pour devenir KILLER.'
            : '- À 3 vies, tu deviens KILLER.',
        '# ATTAQUER',
        '- Un KILLER qui touche le numéro d\'un adversaire lui retire autant '
            'de vies. Un joueur à 0 vie touché encore une fois est éliminé.',
        '- Attention : un KILLER qui touche son propre numéro perd des vies.',
        '- Sous le nombre de vies requis, on n\'est plus KILLER.',
        '- Le bull ne compte pas. 40 manches au plus : ensuite, le plus de '
            'vies gagne.',
      ],
    PracticeKind.treasureHunt => [
        '# BUT',
        'Le plus gros trésor en 10 manches (1 à 4 joueurs).',
        '# CREUSER',
        '- Chaque numéro touché cache une surprise (un même numéro creusé '
            'encore donne autre chose) :',
        '- Trésors : 1 à 5 coffres (100 chacun), diamant (+1000), lingot d\'or '
            '(ton score × 2).',
        '- Pièges : crâne blanc (-100), violet (-300), rouge (-500), grenade '
            '(-1000).',
        '- Bouclier : te protège du prochain piège.',
        '- Couteau et épée : volent 300 ou 600 au joueur qui a le plus de '
            'points.',
        '- Le bull cache un crâne : ton tour s\'arrête et tu passes le '
            'suivant.',
        '# MANCHES SPÉCIALES',
        '- Manches 3, 6 et 9 : trésors et pièges × 2.',
        '- Manches 4, 7 et 10 : effets inversés (les trésors font perdre, les '
            'pièges font gagner, le lingot divise par 2, les vols rendent).',
      ],
    PracticeKind.ticTacToe => [
        '# BUT',
        'Aligner ${s.has('big') ? '4' : '3'} cases sur la grille (morpion), '
            'à 1 ou 2 joueurs.',
        '# RÈGLES',
        '- Grille de ${s.has('big') ? '4 × 4' : '3 × 3'} numéros tirés au '
            'hasard. Joueur 1 = X, joueur 2 = O.',
        '- Pour prendre une case : ${s.has('mark8') ? '8' : '4'} marques sur '
            'son numéro (simple 1, double 2, triple 3). Chacun compte ses '
            'propres marques.',
        '- Une case prise est à toi pour toujours. La toucher encore te '
            'rapporte sa valeur en points.',
        '- Une ligne complète (rangée, colonne, diagonale) : victoire tout de '
            'suite.',
        '- Grille pleine ou 25 manches sans ligne : le plus de points gagne.',
      ],
    PracticeKind.baseball => [
        '# BUT',
        'Marquer le plus de points (runs) en 9 manches.',
        '# RÈGLES',
        '- Manche 1 = le 1, manche 2 = le 2… jusqu\'au 9.',
        '- Simple = 1 point, double = 2, triple = 3. Les autres numéros ne '
            'comptent pas.',
        '- Égalité en tête après 9 manches : manches en plus (10, 11, 12) '
            'jusqu\'à ce qu\'un joueur passe devant.',
      ],
    PracticeKind.golf => [
        '# BUT',
        'Le moins de coups sur ${s.roundsOrDefault} trous.',
        '# RÈGLES',
        '- Trou 1 = le 1, trou 2 = le 2… Tu lances 3 fléchettes par trou.',
        '- Seule ta MEILLEURE fléchette compte : triple = 1 coup (birdie), '
            'double = 2, simple = 3, rien sur le numéro = 5.',
        '- Le plus petit total gagne.',
      ],
    PracticeKind.scram => [
        '# BUT',
        'Marquer le plus de points pendant que l\'autre ferme les numéros '
            '(2 joueurs).',
        '# RÈGLES',
        '- Numéros : 20, 19, 18, 17, 16, 15 et le bull.',
        '- 1re partie : le joueur 1 est le FERMEUR. Une seule touche sur un '
            'numéro ouvert le ferme. Le joueur 2 est le MARQUEUR : ses touches '
            'sur les numéros encore ouverts rapportent leur valeur.',
        '- Tout est fermé : on échange les rôles, tout est rouvert.',
        '- Fin de la 2e partie : le plus gros total gagne.',
      ],
    PracticeKind.football => [
        '# BUT',
        'Le premier à ${s.goalOrDefault} buts.',
        '# RÈGLES',
        '- Touche le bull pour prendre le ballon (même s\'il est à '
            'l\'adversaire).',
        '- Avec le ballon, chaque double est un BUT.',
        '- Un tour avec le ballon sans marquer : le ballon est perdu (sauf si '
            'tu viens de le prendre dans ce tour).',
        '- 40 manches au plus : ensuite, le plus de buts gagne.',
      ],
    PracticeKind.hotPotato => [
        '# BUT',
        'Ne pas garder la bombe : le dernier survivant gagne.',
        '# RÈGLES',
        '- Une bombe est posée sur un numéro, avec une mèche de 3 à 6 '
            'fléchettes. Seul celui qui a la bombe lance.',
        '- Touche son numéro : la bombe passe au joueur suivant, sur un autre '
            'numéro avec une nouvelle mèche.',
        '- Chaque fléchette à côté raccourcit la mèche. Mèche finie : BOUM, '
            'une vie en moins, et une nouvelle bombe part chez le suivant.',
        '- 3 vies chacun, à 0 tu es éliminé.',
      ],
    PracticeKind.catMouse => [
        '# BUT',
        'Souris : t\'échapper en arrivant au bull. Chat : rattraper la souris.',
        '# RÔLES',
        '- Le 1er joueur est la SOURIS, le 2e le CHAT.',
        '- La souris part avec ${s.goalOrDefault} cases d\'avance (elle vise '
            'directement le ${s.goalOrDefault + 1}), le chat part du 1.',
        '# AVANCER',
        '- Chacun vise sa case : le 1, puis le 2… jusqu\'au 20, puis le bull.',
        '- Simple = 1 case, double = 2 cases, triple = 3 cases (sans dépasser '
            'le 20 : le bull est obligatoire). On peut avancer plusieurs fois '
            'dans le même tour.',
        '# FIN',
        '- Le chat arrive sur la case de la souris (ou la dépasse) : ATTRAPÉE, '
            'le chat gagne tout de suite.',
        '- La souris touche le bull : elle s\'échappe et gagne.',
        '- Après 20 manches, la souris gagne si elle court toujours.',
      ],
    PracticeKind.paint => [
        '# BUT',
        'Avoir le plus de zones peintes à ta couleur à la fin des '
            '${s.roundsOrDefault} manches.',
        '# LES ZONES',
        '- La cible est découpée en 61 zones : pour chaque numéro, le '
            'simple (intérieur et extérieur ensemble), le double et le '
            'triple, plus le bull (25 et 50 ensemble).',
        '# PEINDRE',
        '- Ta fléchette peint la zone touchée à ta couleur.',
        '- Zone d\'un adversaire : tu la lui prends (ZONE PRISE), sauf si '
            'elle est protégée.',
        '- Zone déjà à toi : elle devient protégée (bord renforcé) ; plus '
            'personne ne peut la prendre.',
        '- Une fléchette ratée ne peint rien.',
        '# SCORE',
        '- 1 point par zone peinte, quelle que soit sa taille : un petit '
            'triple vaut autant qu\'un gros simple.',
        '- Égalité : les joueurs à égalité gagnent ensemble.',
      ],
    PracticeKind.bowling => [
        '# BUT',
        'Faire le plus gros score en 10 frames, comme au bowling (300 au '
            'maximum).',
        '# LES QUILLES',
        '- 10 quilles debout au début de chaque frame.',
        '- Une fléchette fait tomber ses points ÷ 6 quilles (arrondi) : '
            'T20 ou T19 = 10 (strike), T18 = 9, bull 50 = 8, D20 = 7, 25 = 4, '
            '20 simple = 3, 5 simple = 1.',
        '- On ne fait pas tomber plus de quilles qu\'il n\'en reste debout.',
        '# LES FRAMES',
        '- 2 fléchettes par frame. Strike (les 10 quilles avec la 1re) : le '
            'frame s\'arrête.',
        '- Spare : les 10 quilles tombées avec les 2 fléchettes.',
        '- 10e frame : après un strike ou un spare, une 3e fléchette (les '
            'quilles sont relevées).',
        '# SCORE',
        '- Frame normal : les quilles tombées.',
        '- Spare : 10 + les quilles de la boule suivante.',
        '- Strike : 10 + les quilles des 2 boules suivantes.',
        '- 12 strikes de suite = 300.',
      ],
    PracticeKind.timeAttack => [
        '# BUT',
        'Finir ${s.goalOrDefault} le plus vite possible.',
        '# CHRONO',
        '- Ton chrono tourne pendant tes tours : de ton « suivant » (ou ta 1re '
            'fléchette au tout début) jusqu\'à ta dernière fléchette du tour.',
        '- Le temps pour aller chercher tes fléchettes ne compte pas : appuie '
            'sur « suivant » quand tu es prêt.',
        '# RÈGLES',
        s.has('single')
            ? '- Single Out : n\'importe quelle fléchette peut finir.'
            : '- Double Out : il faut finir sur un double (ou le centre du bull).',
        '- Bust (dépasser, ${s.has('single') ? '' : 'rester à 1, '}finir sur une '
            'mauvaise fléchette) : retour au score du début de la manche, et le '
            'tour s\'arrête.',
        '- La fin conseillée s\'affiche et s\'allume sur la cible.',
        '- À plusieurs : chacun son chrono, le meilleur temps gagne. 60 manches '
            'au plus.',
        '# STATS',
        '- Ton meilleur temps est gardé et classé (onglet entraînement des '
            'classements).',
      ],
  };
  return [
    ...body,
    if (i.party && (i.minPlayers > 1 || i.maxPlayers < 8)) ...[
      '# JOUEURS',
      i.minPlayers == i.maxPlayers
          ? '- ${i.minPlayers} joueurs.'
          : '- De ${i.minPlayers} à ${i.maxPlayers} joueurs.',
    ],
  ].join('\n');
}

/// Nom et règles de la partie en cours (pour un match : le match, puis les
/// legs).
(String, String) rulesOf(DartsGame game) => switch (game) {
      MatchGame m => ('Match ${m.settings.legs} legs', _matchFull(m.settings)),
      PracticeGame g => (
          kPracticeInfo[g.settings.kind]!.name,
          practiceRules(g.settings)
        ),
      CricketGame g => (g.settings.name, cricketRules(g.settings)),
      X01Game g => (g.settings.name, x01Rules(g.settings)),
      _ => (game.title, game.rulesLabel),
    };

/// Texte de règles mis en forme (« # » intertitre, « ## » sous-titre,
/// « - » puce).
class RulesText extends StatelessWidget {
  final String text;
  const RulesText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final body = Tv.label(15, color: Tv.text).copyWith(height: 1.35);
    final children = <Widget>[];
    for (final raw in text.split('\n')) {
      final l = raw.trimRight();
      if (l.isEmpty) continue;
      if (l.startsWith('## ')) {
        children.add(Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 2),
          child: Text(l.substring(3), style: Tv.title(15, color: Tv.goldLight)),
        ));
      } else if (l.startsWith('# ')) {
        children.add(Padding(
          padding: EdgeInsets.only(top: children.isEmpty ? 0 : 14, bottom: 4),
          child: Text(l.substring(2), style: Tv.title(18, color: Tv.gold)),
        ));
      } else if (l.startsWith('- ')) {
        children.add(Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 7, right: 8),
                child: Container(
                    width: 5,
                    height: 5,
                    decoration:
                        BoxDecoration(color: Tv.gold, shape: BoxShape.circle)),
              ),
              Expanded(child: Text(l.substring(2), style: body)),
            ],
          ),
        ));
      } else {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(l, style: body),
        ));
      }
    }
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}

/// Fenêtre « Règles » (feuille du bas, qui défile).
Future<void> showRules(BuildContext context, String title, String text) =>
    showAppSheet<void>(
      context,
      builder: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('RÈGLES · ${title.toUpperCase()}',
                style: Tv.title(22, color: Tv.goldLight)),
            const SizedBox(height: 10),
            RulesText(text),
          ],
        ),
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
