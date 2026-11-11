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
import 'setup_page.dart' show kTeamNames;
import 'theme.dart';

/// Sons, annonces et animations d'une partie, partagés par le téléphone et
/// l'écran TV (qui rejoue les actions reçues du téléphone).
class GameFx {
  final AudioService audio;
  final GlobalKey<GameSplashState> splash;
  final bool haptics;
  GameFx(this.splash, {this.haptics = true}) : audio = AudioService.instance;

  void _show(String text, Color color, {bool big = false}) =>
      splash.currentState?.show(text, color, big: big);

  void _haptic(bool heavy) {
    if (!haptics) return;
    heavy ? HapticFeedback.heavyImpact() : HapticFeedback.lightImpact();
  }

  /// Son du tour du joueur en cours (s'il en a un), puis l'annonce.
  void _turn(DartsGame game, String text, [int ms = 250, bool next = true]) {
    final id = game.currentPlayer.id;
    final media = MediaStore.instance;
    audio.turnCue(text,
        sound: media.soundOf(id), voice: media.voiceOf(id), ms: ms, next: next);
  }

  void start(DartsGame game) {
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

  /// Après une fléchette, quel que soit le jeu.
  void afterAnyDart(DartsGame game, DartHit? hit, {bool outerRing = false}) {
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
          afterAnyDart(m.leg, hit, outerRing: outerRing);
        }
    }
  }

  /// Après « joueur suivant », quel que soit le jeu.
  void afterAnyNext(DartsGame game) {
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
            '$before${g.currentPlayer.name}, $cible${_speakable(g.targetLabel)}');
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
          afterAnyNext(m.leg);
        }
    }
  }

  String? _lastNote;

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
    audio.sayLater('Leg pour $names ! $score.', 700);
    _show('LEG ${m.legNumber}', Tv.gold, big: true);
  }

  void _hitSound(DartHit? hit, {bool outerRing = false}) {
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
    if (turn.darts.length == 3) {
      final total = turn.total;
      if (total == 180) {
        audio.play(Sfx.crowd);
        audio.sayLater('Cent quatre-vingts !', 500);
        _show('180', Tv.gold, big: true);
      } else if (total >= 100) {
        audio.play(Sfx.ton);
        audio.sayLater('$total !', 400);
        _show('$total', Tv.gold);
      } else {
        audio.sayLater(total == 0 ? 'Aucun point' : '$total', 400);
      }
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
    var text = p.name;
    if (game.isFrozen(game.current)) {
      text += ', ton équipe est gelée';
    } else if (s.opened && s.remaining <= 170) {
      text += ', il te reste ${s.remaining}';
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
    if (last != null && last.revealed) {
      final n = last.hit!.isBull ? 'Bull' : '${last.hit!.number}';
      audio.sayLater('$n découvert !', 250);
    }
    if (t.darts.length == 3) {
      final m = t.marks;
      final triples = {
        for (final d in t.darts)
          if (d.hit?.ring == Ring.triple && d.marks > 0) d.hit!.number
      };
      if (m == 9 && triples.length == 3) {
        audio.play(Sfx.crowd);
        audio.sayLater('White horse !', 500);
        _show('WHITE HORSE', Tv.gold, big: true);
      } else if (m >= 5) {
        audio.play(Sfx.ton);
        audio.sayLater('$m marques !', 400);
      } else {
        audio.sayLater(
            m == 0
                ? 'Aucune marque'
                : m == 1
                    ? 'Une marque'
                    : '$m marques',
            400);
      }
    }
  }

  void afterCricketNext(CricketGame game) {
    if (game.finished) {
      win(game);
      return;
    }
    var text = game.currentPlayer.name;
    if (game.isSpoiler(game.sideOf(game.current))) text += ', spoiler';
    _turn(game, text);
  }

  void win(DartsGame game) {
    _haptic(true);
    audio.play(Sfx.win);
    Timer(const Duration(milliseconds: 600), () => audio.play(Sfx.crowd));
    final names = game.winners.map((i) => game.players[i].name).join(' et ');
    final teams = switch (game) {
      X01Game g => g.settings.freeze,
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
      audio.sayLater('Partie gagnée ! Victoire de $team$names !', 900);
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
