import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio.dart';
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

  void start(X01Game game) => audio.sayLater(
      '${game.settings.name}. ${game.currentPlayer.name}, à toi.', 400);

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
    audio.play(Sfx.next);
    final p = game.currentPlayer;
    final s = game.currentState;
    var text = p.name;
    if (game.isFrozen(game.current)) {
      text += ', ton équipe est gelée';
    } else if (s.opened && s.remaining <= 170) {
      text += ', il te reste ${s.remaining}';
    }
    audio.sayLater(text, 250);
  }

  void win(X01Game game) {
    _haptic(true);
    audio.play(Sfx.win);
    Timer(const Duration(milliseconds: 600), () => audio.play(Sfx.crowd));
    final names = game.winners.map((i) => game.players[i].name).join(' et ');
    final team = game.settings.freeze
        ? '${kTeamNames[game.players[game.winners.first].team]} : '
        : '';
    if (game.endReason == EndReason.checkout) {
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
