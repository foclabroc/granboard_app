import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio.dart';
import '../media.dart';
import '../game/cricket.dart';
import '../game/darts_game.dart';
import '../game/match.dart';
import '../game/practice.dart';
import '../game/x01.dart';
import '../granboard.dart';
import 'award.dart';
import 'setup_page.dart' show kTeamNames;
import 'theme.dart';
import 'turn_banner.dart';

/// Sons, annonces et animations d'une partie, partagés par le téléphone et
/// l'écran TV (qui rejoue les actions reçues du téléphone).
class GameFx {
  final AudioService audio;
  final GlobalKey<GameSplashState> splash;
  final bool haptics;
  GameFx(this.splash, {this.haptics = true}) : audio = AudioService.instance;

  void _show(String text, Color color, {bool big = false}) =>
      splash.currentState?.show(text, color, big: big);

  /// Animation plein écran d'un coup réussi (elle a son propre son). Faux
  /// si elle ne peut pas être jouée : on garde alors l'annonce habituelle.
  bool _award(Award? award) =>
      award != null && AwardPlayer.play(splash.currentContext, award);

  void _haptic(bool heavy) {
    if (!haptics) return;
    heavy ? HapticFeedback.heavyImpact() : HapticFeedback.lightImpact();
  }

  /// Son du tour du joueur en cours (s'il en a un), puis l'annonce.
  void _turn(DartsGame game, String text, [int ms = 250, bool next = true]) {
    if (_lead.isNotEmpty) {
      text = '${_lead.join('. ')}. $text';
      _lead.clear();
    }
    final id = game.currentPlayer.id;
    final media = MediaStore.instance;
    audio.turnCue(text,
        sound: media.soundOf(id), voice: media.voiceOf(id), ms: ms, next: next);
  }

  /// Les pseudos sont lus par la synthèse vocale, le reste par la voix
  /// enregistrée.
  void _names(DartsGame game) =>
      audio.names = [for (final p in game.players) p.name];

  // ─── Commentaires ───

  /// Phrases à dire avant la prochaine annonce du tour (180 de la soirée,
  /// match point…).
  final _lead = <String>[];

  /// 180 et meilleure fin de la soirée (remis à zéro après 6 h sans 180).
  static int session180 = 0;
  static int sessionBestCheckout = 0;
  static DateTime _sessionAt = DateTime.now();
  static void _session() {
    if (DateTime.now().difference(_sessionAt) > const Duration(hours: 6)) {
      session180 = 0;
      sessionBestCheckout = 0;
    }
    _sessionAt = DateTime.now();
  }

  static const _ordinals = [
    '', '', 'Deuxième', 'Troisième', 'Quatrième', 'Cinquième', 'Sixième', //
    'Septième', 'Huitième', 'Neuvième', 'Dixième',
  ];

  /// Une fléchette dite à voix haute : « triple 20 », « double 16 », « 5 »,
  /// « bull », « 25 », « raté » (vide si l'annonce des fléchettes est coupée
  /// ou si une animation `HitClip` joue pour cette fléchette).
  String _call(DartHit? hit) {
    // Triple 20, bull, double bull : l'animation et son son suffisent
    if (!audio.dartCalls || _clip != null) return '';
    if (hit == null) return 'raté';
    return switch (hit.ring) {
      Ring.innerBull => 'bull',
      Ring.outerBull => '25',
      Ring.triple => 'triple ${hit.number}',
      Ring.double => 'double ${hit.number}',
      _ => '${hit.number}',
    };
  }

  /// « [fléchette], [annonce] » ou l'un des deux.
  static String _join(String a, String b) =>
      a.isEmpty ? b : (b.isEmpty ? a : '$a, $b');

  /// Fin conseillée lisible : « triple 20, double 20 ».
  static String _route(List<String> labels) => labels
      .map((l) => l == 'BULL'
          ? 'bull'
          : l.startsWith('T')
              ? 'triple ${l.substring(1)}'
              : l.startsWith('D')
                  ? 'double ${l.substring(1)}'
                  : l)
      .join(', ');

  /// Un 180 : compté pour la soirée, annoncé au tour suivant à partir du 2e.
  void _count180() {
    _session();
    session180++;
    final n = session180;
    if (n < 2) return;
    _lead.add(n < _ordinals.length
        ? '${_ordinals[n]} 180 de la soirée'
        : 'Encore un 180');
  }

  /// Fin à 100 ou plus : « Fin à 121 », et record de la soirée.
  String _checkoutNote(X01Game g) {
    if (g.winners.isEmpty) return '';
    final c = g.stateOf(g.winners.first).checkout ?? 0;
    if (c < 100) return '';
    _session();
    final best = c > sessionBestCheckout;
    if (best) sessionBestCheckout = c;
    return best && c >= 100
        ? 'Fin à $c. Plus haute fin de la soirée. '
        : 'Fin à $c. ';
  }

  void start(DartsGame game) {
    _names(game);
    final title = game is MatchGame
        ? 'Match en ${game.settings.legs} legs. Leg 1, ${game.leg.title}'
        : game.title;
    _turn(game, '$title. ${game.currentPlayer.name}, à toi.', 400, false);
  }

  /// Après une action du journal (écran TV qui rejoue la partie).
  void afterAction(DartsGame game, String entry) {
    if (entry == 'n') {
      afterAnyNext(game);
    } else {
      final hits = game.turnHits;
      afterAnyDart(game, hits.isEmpty ? null : hits.last);
    }
  }

  /// Animation courte de la fléchette en cours (triple 20, bull, double
  /// bull) : son bruitage habituel est remplacé par le son de la vidéo.
  HitClip? _clip;

  /// La vidéo de la fléchette a son propre son : l'annonce de la manche
  /// (total, marques) attend qu'elle soit finie.
  int get _wait => _clip == null ? 0 : 1300;

  /// Après une fléchette, quel que soit le jeu.
  void afterAnyDart(DartsGame game, DartHit? hit, {bool outerRing = false}) {
    AwardPlayer.stop();
    TurnBanner.hide();
    _names(game);
    _clip = AwardPlayer.enabled ? HitClip.of(hit) : null;
    _afterDart(game, hit, outerRing: outerRing);
    final clip = _clip;
    _clip = null;
    // Pas par-dessus un coup de manche (ton, hat trick…), une victoire ou
    // un bust, qui ont leur propre annonce
    if (clip == null || AwardPlayer.active || game.finished) return;
    if (game is MatchGame && game.betweenLegs) return;
    final leg = game is MatchGame ? game.leg : game;
    if (leg is X01Game && leg.currentTurn.isBust) return;
    AwardPlayer.playAsset(splash.currentContext, clip.randomAsset(),
        opacity: 0.92);
  }

  void _afterDart(DartsGame game, DartHit? hit, {bool outerRing = false}) {
    switch (game) {
      case X01Game g:
        afterDart(g, hit, outerRing: outerRing);
      case CricketGame g:
        afterCricketDart(g, hit, outerRing: outerRing);
      case PracticeGame g:
        _hitSound(hit, outerRing: outerRing);
        if (g.finished) {
          win(g);
          return;
        }
        _haptic(false);
        final note = g.currentTurn.note;
        final key = '${g.turns.length}:$note';
        final hits = g.turnHits;
        final call = _call(hit);
        final quiet = note == null || key == _lastNote;
        // Jeux à rebours : à la 3e fléchette, ce qu'il reste à faire
        final left = hits.length == 3 && quiet ? _practiceLeft(g) : null;
        if (left != null && left > 0) {
          audio.sayLater(_join(call, 'Il reste $left'), 400 + _wait);
        } else if (call.isNotEmpty && quiet) {
          audio.sayLater(call, 150 + _wait);
        }
        if (hits.length == 3 &&
            _award(awardOf(hits,
                whiteHorse: g.settings.kind == PracticeKind.targetHorse ||
                    g.settings.kind == PracticeKind.crCountUp))) {
          _lastNote = key;
          return;
        }
        if (note == null || key == _lastNote) return;
        _lastNote = key;
        if (_badNote(note)) {
          audio.play(Sfx.bust);
          audio.sayLater(_speakable(note), 250);
          _show(note.split(' :').first, Tv.red);
        } else if (_bigNote(note)) {
          audio.play(Sfx.crowd);
          audio.sayLater(_speakable(note), 300);
          _show(note.split(' +').first.split(' :').first, Tv.gold);
        } else {
          audio.sayLater(_speakable(note), 250);
        }
      case MatchGame m:
        if (m.finished) {
          _hitSound(hit, outerRing: outerRing);
          win(m);
        } else if (m.betweenLegs) {
          _hitSound(hit, outerRing: outerRing);
          _legWon(m);
        } else {
          _afterDart(m.leg, hit, outerRing: outerRing);
        }
    }
  }

  /// Après « joueur suivant », quel que soit le jeu.
  void afterAnyNext(DartsGame game) {
    AwardPlayer.stop();
    _names(game);
    _afterNext(game);
    // Bandeau « au tour de … » (pas en solo, ni entre 2 legs ou à la fin)
    if (game.finished || game.players.length < 2) return;
    if (game is MatchGame && game.betweenLegs) return;
    final p = game.currentPlayer;
    TurnBanner.show(splash.currentContext,
        id: p.id,
        name: p.name,
        sub: game is MatchGame && game.leg.actionLog.isEmpty
            ? 'LEG ${game.legNumber} · AU TOUR DE'
            : null);
  }

  void _afterNext(DartsGame game) {
    switch (game) {
      case X01Game g:
        afterNext(g);
      case CricketGame g:
        afterCricketNext(g);
      case PracticeGame g:
        if (g.finished) {
          win(g);
          return;
        }
        final prev = g.turns.length > 1 ? g.turns[g.turns.length - 2] : null;
        final note = prev?.note;
        final key = '${g.turns.length - 1}:$note';
        final before =
            note != null && key != _lastNote ? '${_speakable(note)}. ' : '';
        if (note != null) _lastNote = key;
        final cible = g.settings.info.party ? '' : 'cible ';
        _turn(g,
            '$before${g.currentPlayer.name}, à toi. $cible${_speakable(g.targetLabel)}');
      case MatchGame m:
        if (m.finished) {
          win(m);
        } else if (m.betweenLegs) {
          _legWon(m); // limite de manches atteinte
        } else if (m.leg.actionLog.isEmpty) {
          _turn(
              m,
              'Leg ${m.legNumber}, ${m.leg.title}. '
              '${m.currentPlayer.name}, à toi.',
              300);
        } else {
          final leg = m.leg;
          if (m.legWinsOf(m.current) == m.settings.winsNeeded - 1 &&
              leg is X01Game &&
              leg.checkoutOptions.isNotEmpty) {
            _lead.add('Match point');
          }
          _afterNext(leg);
        }
    }
  }

  String? _lastNote;

  /// Jeux où l'on descend vers 0 ou monte vers un objectif pile : ce qu'il
  /// reste au joueur en cours (null pour les autres jeux).
  static int? _practiceLeft(PracticeGame g) {
    final st = g.stateOf(g.current);
    return switch (g.settings.kind) {
      PracticeKind.checkout121 || PracticeKind.spider => st.v['rem'],
      PracticeKind.kickDown => g.settings.goalOrDefault - st.score,
      _ => null,
    };
  }

  static bool _badNote(String n) =>
      n == 'BUST' ||
      n.startsWith('TROP') ||
      n.startsWith('OVER') ||
      n.startsWith('LE MÉCHANT') ||
      n.startsWith('GRENADE') ||
      n.startsWith('CRÂNE') ||
      n.contains('ÉLIMINÉ');

  /// Notes de manche qui méritent une annonce animée.
  static bool _bigNote(String n) =>
      n.startsWith('HAT') ||
      n.startsWith('WHITE') ||
      n.startsWith('ARAIGNÉE') ||
      n.startsWith('TOUTES') ||
      n.startsWith('NAVIRE') ||
      n.startsWith('3 TRIPLES') ||
      n.startsWith('RÉUSSI') ||
      n.startsWith('BONUS') ||
      n.startsWith('KICK') ||
      n.startsWith('SHANGHAI') ||
      n.startsWith('MISSION RÉUSSIE') ||
      n.startsWith('ANIMAL') ||
      n.contains('KILLER') ||
      n.startsWith('ALIGNÉ') ||
      n.contains('MÉLANGÉS') ||
      n.startsWith('DIAMANT') ||
      n.startsWith('LINGOT') ||
      n.contains('REPRIS');

  /// Texte lisible par l'annonceur.
  static String _speakable(String s) => s
      .replaceAll('÷ 2', 'divisé par deux')
      .replaceAll('BULL', 'bull')
      .replaceAll(RegExp(r'\(.*?\)'), '')
      .replaceAllMapped(RegExp(r'\bD(\d+)'), (m) => 'double ${m[1]}')
      .replaceAllMapped(RegExp(r'\bT(\d+)'), (m) => 'triple ${m[1]}')
      .toLowerCase();

  void _legWon(MatchGame m) {
    _haptic(true);
    audio.play(Sfx.win);
    final names = m.leg.winners.map((i) => m.leg.players[i].name).join(' et ');
    final score = [
      for (var i = 0; i < m.players.length; i++) '${m.legWinsOf(i)}'
    ].join(' à ');
    final leg = m.leg;
    final fin = leg is X01Game ? _checkoutNote(leg) : '';
    audio.sayLater('${fin}Leg pour $names ! $score.', 700);
    _show('LEG ${m.legNumber}', Tv.gold, big: true);
  }

  void _hitSound(DartHit? hit, {bool outerRing = false}) {
    if (_clip != null) return;
    if (hit != null) {
      audio.play(hit.isBull
          ? Sfx.bull
          : hit.multiplier == 3
              ? Sfx.triple
              : hit.multiplier == 2
                  ? Sfx.double
                  : Sfx.hit);
    } else if (outerRing) {
      audio.play(Sfx.hit);
    }
  }

  /// Après une fléchette acceptée ([hit] null = ratée).
  void afterDart(X01Game game, DartHit? hit, {bool outerRing = false}) {
    final turn = game.currentTurn;
    if (game.finished) {
      win(game);
      return;
    }
    if (turn.isBust) {
      _haptic(true);
      audio.play(Sfx.bust);
      audio.sayLater(
          turn.bust == BustReason.frozen ? 'Bust ! Équipe gelée.' : 'Bust !',
          250);
      _show('BUST', Tv.red);
      return;
    }
    _haptic(false);
    _hitSound(hit, outerRing: outerRing);
    final call = _call(hit);
    if (turn.darts.length == 3) {
      final total = turn.total;
      // Après les 3 fléchettes : ce qu'il reste à faire (pas le total)
      final left = 'Il reste ${game.currentState.remaining}';
      if (total == 180) _count180();
      if (_award(awardOf(game.turnHits, total: total))) {
        _haptic(true);
      } else if (total == 180) {
        audio.play(Sfx.crowd);
        audio.sayLater('Cent quatre-vingts ! $left', 500);
        _show('180', Tv.gold, big: true);
      } else if (total >= 100) {
        audio.play(Sfx.ton);
        audio.sayLater(_join(call, left), 400 + _wait);
        _show('$total', Tv.gold);
      } else {
        audio.sayLater(_join(call, left), 400 + _wait);
      }
    } else if (call.isNotEmpty) {
      audio.sayLater(call, 150 + _wait);
    }
  }

  /// Après « joueur suivant ».
  void afterNext(X01Game game) {
    if (game.finished) {
      win(game);
      return;
    }
    final p = game.currentPlayer;
    final s = game.currentState;
    var text = '${p.name}, à toi';
    if (game.isFrozen(game.current)) {
      text += '. Ton équipe est gelée';
    } else if (s.opened && s.remaining <= 170) {
      text += '. Il te reste ${s.remaining}';
      final opts = game.checkoutOptions;
      if (opts.isNotEmpty) text += ', ${_route(opts.first)}';
    }
    _turn(game, text);
  }

  // ─── Cricket ───

  void afterCricketDart(CricketGame game, DartHit? hit,
      {bool outerRing = false}) {
    if (game.finished) {
      _hitSound(hit, outerRing: outerRing);
      win(game);
      return;
    }
    _haptic(false);
    _hitSound(hit, outerRing: outerRing);
    final t = game.currentTurn;
    final last = t.darts.isEmpty ? null : t.darts.last;
    final call = _call(hit);
    if (last != null && last.revealed) {
      final n = last.hit!.isBull ? 'Bull' : '${last.hit!.number}';
      audio.sayLater(_join(t.darts.length == 3 ? '' : call, '$n découvert !'),
          250 + _wait);
    } else if (t.darts.length < 3 && call.isNotEmpty) {
      audio.sayLater(call, 150 + _wait);
    }
    if (t.darts.length == 3) {
      final m = t.marks;
      final triples = {
        for (final d in t.darts)
          if (d.hit?.ring == Ring.triple && d.marks > 0) d.hit!.number
      };
      if (_award(m == 9 && triples.length == 3
          ? Award.whiteHorse
          : awardOf(game.turnHits))) {
        _haptic(true);
      } else if (m == 9 && triples.length == 3) {
        audio.play(Sfx.crowd);
        audio.sayLater('White horse !', 500);
        _show('WHITE HORSE', Tv.gold, big: true);
      } else if (m >= 5) {
        audio.play(Sfx.ton);
        audio.sayLater(_join(call, '$m marques !'), 400 + _wait);
      } else {
        audio.sayLater(
            _join(
                call,
                m == 0
                    ? 'Aucune marque'
                    : m == 1
                        ? 'Une marque'
                        : '$m marques'),
            400 + _wait);
      }
    }
  }

  void afterCricketNext(CricketGame game) {
    if (game.finished) {
      win(game);
      return;
    }
    var text = '${game.currentPlayer.name}, à toi';
    final side = game.sideOf(game.current);
    if (game.isSpoiler(side)) text += '. Spoiler';
    // Plus que 1 ou 2 numéros à fermer : on les dit
    final left = [
      for (var i = 0; i < game.targets.length; i++)
        if (!game.closedBy(side, i) && !game.dead(i)) game.targets[i]
    ];
    if (left.isNotEmpty &&
        left.length <= 2 &&
        left.every((t) => t.revealed && t.number <= 25)) {
      text +=
          '. Plus que ${left.map((t) => t.number == 25 ? 'bull' : '${t.number}').join(' et ')}';
    }
    _turn(game, text);
  }

  void win(DartsGame game) {
    _haptic(true);
    audio.play(Sfx.win);
    Timer(const Duration(milliseconds: 600), () => audio.play(Sfx.crowd));
    final names = game.winners.map((i) => game.players[i].name).join(' et ');
    final teams = switch (game) {
      X01Game g => g.settings.teamPlay,
      CricketGame g => g.settings.teams,
      _ => false,
    };
    if (game is PracticeGame) {
      final names = game.winners.map((i) => game.players[i].name).join(' et ');
      final byGoal = game.endReason == PracticeEnd.goal;
      audio.sayLater(
          game.players.length == 1
              ? 'Fin de l\'entraînement. Score : ${game.scoreText(0)}.'
              : '${byGoal ? 'Objectif atteint ! ' : 'Fin de la partie. '}Victoire de $names !',
          900);
      _show(byGoal ? 'VICTOIRE' : 'FIN', Tv.gold, big: true);
      return;
    }
    if (game is MatchGame) {
      final names = game.winners.map((i) => game.players[i].name).join(' et ');
      audio.sayLater('Jeu, set et match ! Victoire de $names !', 900);
      _show('MATCH', Tv.gold, big: true);
      return;
    }
    final team = teams && game.winners.isNotEmpty
        ? '${kTeamNames[game.players[game.winners.first].team]} : '
        : '';
    final byClose = switch (game) {
      X01Game g => g.endReason == EndReason.checkout,
      CricketGame g => g.endReason == CricketEnd.closed,
      _ => false,
    };
    if (byClose) {
      final fin = game is X01Game ? _checkoutNote(game) : '';
      audio.sayLater('${fin}Partie gagnée ! Victoire de $team$names !', 900);
      _show('VICTOIRE', Tv.gold, big: true);
    } else {
      audio.sayLater('Fin de la partie. Victoire de $team$names.', 700);
      _show('FIN', Tv.gold, big: true);
    }
  }
}

// ─── Annonce animée (180, BUST, VICTOIRE) ───

class GameSplash extends StatefulWidget {
  const GameSplash({super.key});
  @override
  State<GameSplash> createState() => GameSplashState();
}

class GameSplashState extends State<GameSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600));
  String _text = '';
  Color _color = Tv.gold;
  bool _big = false;

  void show(String text, Color color, {bool big = false}) {
    setState(() {
      _text = text;
      _color = color;
      _big = big;
    });
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final v = _c.value;
        if (v == 0 || v == 1) return const SizedBox.shrink();
        final scale = Curves.elasticOut.transform((v * 2.2).clamp(0, 1));
        final opacity = v < 0.75 ? 1.0 : (1 - (v - 0.75) / 0.25);
        return Opacity(
          opacity: opacity.clamp(0, 1),
          child: Container(
            color: Colors.black.withValues(alpha: 0.35 * opacity),
            alignment: Alignment.center,
            child: Transform.scale(
              scale: 0.4 + 0.6 * scale,
              child: Transform.rotate(
                angle: -0.06,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    border: Border.all(color: _color, width: 4),
                    boxShadow: [
                      BoxShadow(
                          color: _color.withValues(alpha: 0.6), blurRadius: 40)
                    ],
                  ),
                  child: FittedBox(
                    child: Text(
                      _text,
                      style: Tv.title(_big ? 120 : 90, color: _color)
                          .copyWith(letterSpacing: 4),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
