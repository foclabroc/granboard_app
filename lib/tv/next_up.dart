// Écran TV : « Ensuite » = le joueur qui lancera après celui en cours, avec
// ce qu'il lui reste (01) ou son score.

import 'package:flutter/material.dart';

import '../game/cricket.dart';
import '../game/darts_game.dart';
import '../game/match.dart';
import '../game/practice.dart';
import '../game/x01.dart';
import '../players.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// Joueur suivant et sa situation, ou null (fin, seul, entre 2 legs).
(X01Player, String)? nextUp(DartsGame game) {
  if (game.finished || game.players.length < 2) return null;
  if (game is MatchGame && game.betweenLegs) return null;
  DartsGame copy;
  try {
    copy = gameFromJson(game.toJson());
    copy.next();
  } catch (_) {
    return null;
  }
  if (copy.finished) return null;
  final g = copy is MatchGame ? copy.leg : copy;
  if (g.finished) return null;
  final p = g.currentPlayer;
  if (p.id == (game is MatchGame ? game.leg : game).currentPlayer.id) {
    return null;
  }
  final info = switch (g) {
    X01Game x => 'IL LUI RESTE ${x.currentState.remaining}',
    CricketGame c => '${c.scoreOf(c.sideOf(c.current))} PTS',
    PracticeGame pg => 'SCORE ${pg.stateOf(pg.current).score}',
    _ => '',
  };
  return (p, info);
}

/// Pastille « ENSUITE » de l'écran TV (recalculée seulement quand la
/// partie avance).
class NextUpChip extends StatefulWidget {
  final DartsGame game;
  final double scale;

  /// Largeur maximale (sinon 280 × [scale]).
  final double? maxWidth;
  const NextUpChip(
      {super.key, required this.game, this.scale = 1, this.maxWidth});

  @override
  State<NextUpChip> createState() => _NextUpChipState();
}

class _NextUpChipState extends State<NextUpChip> {
  int _len = -1;
  DartsGame? _of;
  (X01Player, String)? _next;

  @override
  Widget build(BuildContext context) {
    final g = widget.game;
    if (!identical(g, _of) || g.actionLog.length != _len) {
      _of = g;
      _len = g.actionLog.length;
      _next = nextUp(g);
    }
    final n = _next;
    if (n == null) return const SizedBox.shrink();
    final (p, info) = n;
    final s = widget.scale;
    final color = PlayerStore.instance.colorOf(p.id);
    // Nom en entier sur sa propre ligne (rétréci s'il est long, jamais
    // coupé) ; « ENSUITE » et ce qu'il lui reste au-dessus
    return Container(
      key: const ValueKey('next-up'),
      constraints: BoxConstraints(maxWidth: widget.maxWidth ?? 280 * s),
      padding: EdgeInsets.fromLTRB(4 * s, 3 * s, 12 * s, 3 * s),
      decoration: BoxDecoration(
        color: Tv.panel2,
        borderRadius: BorderRadius.circular(22 * s),
        border: Border.all(color: color.withValues(alpha: 0.8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PlayerAvatar(name: p.name, color: color, size: 30 * s, id: p.id),
          SizedBox(width: 6 * s),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: 'ENSUITE',
                        style: Tv.label(9 * s, color: Tv.gold)),
                    if (info.isNotEmpty)
                      TextSpan(
                          text: '  ·  $info',
                          style: Tv.label(9 * s, color: Tv.goldLight)),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                FittedBox(
                  key: const ValueKey('next-up-name'),
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(p.name.toUpperCase(),
                      maxLines: 1, style: Tv.title(15 * s)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
