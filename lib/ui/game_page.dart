import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../audio.dart';
import '../board_service.dart';
import '../game/x01.dart';
import '../granboard.dart';
import '../players.dart';
import 'dartboard.dart';
import 'results_page.dart';
import 'setup_page.dart' show kTeamColors, kTeamNames;
import 'sound_settings.dart';
import 'theme.dart';
import 'widgets.dart';

/// Partie X01 / Freeze en cours.
class GamePage extends StatefulWidget {
  final X01Settings settings;
  final List<X01Player> players;
  const GamePage({super.key, required this.settings, required this.players});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late final X01Game game = X01Game(widget.settings, widget.players);
  late final StreamSubscription<BoardEvent> _sub;
  final _splash = GlobalKey<_SplashState>();
  final audio = AudioService.instance;
  bool _recorded = false;

  @override
  void initState() {
    super.initState();
    _sub = BoardService.instance.events.listen(_onEvent);
    WakelockPlus.enable().catchError((_) {});
    audio.stopMusic();
    audio.sayLater(
        '${widget.settings.name}. ${game.currentPlayer.name}, à toi.', 400);
  }

  @override
  void dispose() {
    _sub.cancel();
    WakelockPlus.disable().catchError((_) {});
    super.dispose();
  }

  void _onEvent(BoardEvent e) {
    switch (e) {
      case HitEvent(:final hit):
        _dart(hit);
      case ButtonEvent():
        _next();
      case UnknownEvent():
        break;
    }
  }

  void _dart(DartHit? hit) {
    if (game.finished) return;
    if (game.turnOver) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            duration: Duration(seconds: 2),
            content: Text('Manche terminée : retire tes fléchettes '
                'puis « Suivant »')));
      return;
    }
    setState(() => game.throwDart(hit));
    final turn = game.currentTurn;

    if (game.finished) {
      _onWin();
      return;
    }
    if (turn.isBust) {
      HapticFeedback.heavyImpact();
      audio.play(Sfx.bust);
      audio.sayLater(
          turn.bust == BustReason.frozen ? 'Bust ! Équipe gelée.' : 'Bust !',
          250);
      _splash.currentState?.show('BUST', Tv.red);
      return;
    }

    HapticFeedback.lightImpact();
    if (hit != null) {
      audio.play(hit.isBull
          ? Sfx.bull
          : hit.multiplier == 3
              ? Sfx.triple
              : hit.multiplier == 2
                  ? Sfx.double
                  : Sfx.hit);
    }

    if (turn.darts.length == 3) {
      final total = turn.total;
      if (total == 180) {
        audio.play(Sfx.crowd);
        audio.sayLater('Cent quatre-vingts !', 500);
        _splash.currentState?.show('180', Tv.gold, big: true);
      } else if (total >= 100) {
        audio.play(Sfx.ton);
        audio.sayLater('$total !', 400);
        _splash.currentState?.show('$total', Tv.gold);
      } else {
        audio.sayLater(total == 0 ? 'Aucun point' : '$total', 400);
      }
    }
  }

  void _onWin() {
    HapticFeedback.heavyImpact();
    audio.play(Sfx.win);
    Timer(const Duration(milliseconds: 600), () => audio.play(Sfx.crowd));
    final names = game.winners.map((i) => game.players[i].name).join(' et ');
    final team = game.settings.freeze
        ? '${kTeamNames[game.players[game.winners.first].team]} : '
        : '';
    if (game.endReason == EndReason.checkout) {
      audio.sayLater('Partie gagnée ! Victoire de $team$names !', 900);
      _splash.currentState?.show('VICTOIRE', Tv.gold, big: true);
    } else {
      audio.sayLater('Fin de la partie. Victoire de $team$names.', 700);
      _splash.currentState?.show('FIN', Tv.gold, big: true);
    }
  }

  void _next() {
    if (game.finished) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() => game.next());
    if (game.finished) {
      _onWin();
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

  void _undo() => setState(() => game.undo());

  Future<void> _results() async {
    if (!_recorded) {
      _recorded = true;
      await PlayerStore.instance.recordX01(game);
    }
    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => ResultsPage(game: game)));
  }

  Future<bool> _confirmQuit() async {
    if (game.finished) return true;
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Abandonner la partie ?', style: Tv.title(22)),
        content: const Text('Les statistiques ne seront pas enregistrées.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Continuer')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Abandonner')),
        ],
      ),
    );
    return r ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmQuit() && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.name.toUpperCase(), style: Tv.title(24, color: Tv.gold)),
              Text(s.rulesLabel.toUpperCase(), style: Tv.label(11)),
            ],
          ),
          actions: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Tv.panel2,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Tv.line),
              ),
              child: Column(
                children: [
                  Text('MANCHE', style: Tv.label(9)),
                  Text(
                    s.roundLimit == null
                        ? '${game.round}'
                        : '${game.round}/${s.roundLimit}',
                    style: Tv.title(18),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Sons',
              icon: const Icon(Icons.volume_up),
              onPressed: () => showSoundSettings(context),
            ),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                const BoardBanner(),
                _CurrentPanel(game: game),
                Expanded(child: _Scoreboard(game: game)),
                _ActionBar(
                  game: game,
                  onUndo: _undo,
                  onMiss: () => _dart(null),
                  onNext: _next,
                  onResults: _results,
                ),
              ],
            ),
            Positioned.fill(child: IgnorePointer(child: _Splash(key: _splash))),
          ],
        ),
      ),
    );
  }
}

Color _colorOf(X01Player p) =>
    PlayerStore.instance.byId(p.id)?.color ?? Colors.grey;

// ─── Annonce animée (180, BUST, VICTOIRE) ───

class _Splash extends StatefulWidget {
  const _Splash({super.key});
  @override
  State<_Splash> createState() => _SplashState();
}

class _SplashState extends State<_Splash> with SingleTickerProviderStateMixin {
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

// ─── Joueur en cours (bandeau TV) ───

class _CurrentPanel extends StatelessWidget {
  final X01Game game;
  const _CurrentPanel({required this.game});

  @override
  Widget build(BuildContext context) {
    final p = game.currentPlayer;
    final st = game.currentState;
    final turn = game.currentTurn;
    final frozen = game.isFrozen(game.current);
    final freeze = game.settings.freeze;
    final color = _colorOf(p);

    String status;
    Color statusColor = Tv.text;
    Color accent = Tv.gold;

    if (game.finished) {
      final names = game.winners.map((i) => game.players[i].name).join(', ');
      status = game.endReason == EndReason.checkout
          ? '🏆 $names ${game.winners.length > 1 ? 'gagnent' : 'gagne'} !'
          : '🏁 Limite atteinte : $names';
      statusColor = Tv.goldLight;
    } else if (turn.isBust) {
      status = 'BUST — ${turn.bust!.label}';
      statusColor = Tv.red;
      accent = Tv.red;
    } else if (game.turnOver) {
      status = 'Retire tes fléchettes · « Suivant »';
      statusColor = Tv.muted;
    } else if (!st.opened) {
      status = game.settings.inRule == InRule.double
          ? 'Un double pour commencer'
          : 'Double, triple ou bull pour commencer';
      statusColor = Tv.goldLight;
    } else if (frozen) {
      status = '❄ Équipe gelée : pas de fin';
      statusColor = Tv.ice;
      accent = Tv.ice;
    } else {
      final hint = game.checkoutHint;
      status = hint == null ? '' : hint.join('  ·  ');
      statusColor = Tv.green;
    }

    final hits = [
      for (final d in turn.darts)
        if (d.hit != null) d.hit!
    ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.fromLTRB(10, 6, 10, 4),
      decoration: BoxDecoration(
        gradient: Tv.panelGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border(top: BorderSide(color: accent, width: 4)),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: 0.15), blurRadius: 20),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
      child: Column(
        children: [
          Row(
            children: [
              Dartboard(size: 128, highlights: hits, showNumbers: false),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(width: 5, height: 20, color: color),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(p.name.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Tv.title(24)),
                        ),
                        if (freeze) ...[
                          const SizedBox(width: 6),
                          Text(kTeamNames[p.team].split(' ').last,
                              style: Tv.title(18, color: kTeamColors[p.team])),
                        ],
                      ],
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text('${st.remaining}',
                          style: Tv.title(88, color: Colors.white)),
                    ),
                    Text(status,
                        maxLines: 2, style: Tv.title(17, color: statusColor)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < 3; i++)
                Expanded(
                  child: _DartSlot(
                      dart: i < turn.darts.length ? turn.darts[i] : null,
                      bust: turn.isBust),
                ),
              Container(
                width: 70,
                height: 52,
                margin: const EdgeInsets.only(left: 4),
                decoration: BoxDecoration(
                  gradient: Tv.goldGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('TOTAL', style: Tv.label(10, color: Colors.black87)),
                    Text(
                        turn.isBust
                            ? '0'
                            : '${turn.darts.fold<int>(0, (s, d) => s + d.points)}',
                        style: Tv.title(24, color: Colors.black)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DartSlot extends StatelessWidget {
  final ThrownDart? dart;
  final bool bust;
  const _DartSlot({required this.dart, required this.bust});

  @override
  Widget build(BuildContext context) {
    final d = dart;
    final h = d?.hit;
    Color c = Tv.panel2;
    if (h != null) {
      if (h.multiplier == 3) c = Tv.red;
      if (h.multiplier == 2) c = Tv.green;
      if (h.isBull) c = h.ring == Ring.innerBull ? Tv.red : Tv.green;
    }
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: d == null ? Colors.black26 : c,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: d == null ? Tv.line : Colors.white24),
      ),
      alignment: Alignment.center,
      child: d == null
          ? Text('—', style: Tv.title(20, color: Tv.line))
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(d.label.toUpperCase(),
                      style: Tv.title(24).copyWith(
                          decoration:
                              bust ? TextDecoration.lineThrough : null)),
                  if (h != null && d.points != h.score)
                    Text('${d.points} PT', style: Tv.label(10, color: Tv.text)),
                ],
              ),
            ),
    );
  }
}

// ─── Tableau des scores ───

class _Scoreboard extends StatelessWidget {
  final X01Game game;
  const _Scoreboard({required this.game});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    if (game.settings.freeze) {
      for (final t in game.teams) {
        final frozen = game.membersOf(t).any(game.isFrozen);
        rows.add(Container(
          margin: const EdgeInsets.fromLTRB(10, 8, 10, 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: kTeamColors[t].withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Text(kTeamNames[t].toUpperCase(),
                  style: Tv.title(16, color: kTeamColors[t])),
              if (frozen) Text('  ❄ GELÉE', style: Tv.title(14, color: Tv.ice)),
              const Spacer(),
              Text('${game.teamRemaining(t)}', style: Tv.title(20)),
            ],
          ),
        ));
        for (final i in game.membersOf(t)) {
          rows.add(_PlayerBar(game: game, index: i));
        }
      }
    } else {
      for (var i = 0; i < game.players.length; i++) {
        rows.add(_PlayerBar(game: game, index: i));
      }
    }
    return ListView(padding: const EdgeInsets.only(top: 4), children: rows);
  }
}

class _PlayerBar extends StatelessWidget {
  final X01Game game;
  final int index;
  const _PlayerBar({required this.game, required this.index});

  @override
  Widget build(BuildContext context) {
    final p = game.players[index];
    final st = game.stateOf(index);
    final current = index == game.current && !game.finished;
    final winner = game.winners.contains(index);
    final last = game.lastTurnOf(index);

    final info = [
      'MOY ${st.average.toStringAsFixed(1)}',
      if (last != null) last.isBust ? 'BUST' : 'DERN. ${last.total}',
      if (!st.opened) 'PAS OUVERT',
    ].join('  ·  ');

    return Container(
      height: 52,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: current ? const Color(0xFF2A2210) : Tv.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: current ? Tv.gold : Tv.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Container(width: 6, color: _colorOf(p)),
          SizedBox(
            width: 22,
            child: current
                ? const Icon(Icons.play_arrow, color: Tv.gold, size: 20)
                : null,
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${winner ? '🏆 ' : ''}${p.name.toUpperCase()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        Tv.title(19, color: current ? Tv.goldLight : Tv.text)),
                Text(info, maxLines: 1, style: Tv.label(11)),
              ],
            ),
          ),
          Container(
            width: 78,
            color: current ? Tv.gold : Colors.black,
            alignment: Alignment.center,
            child: Text('${st.remaining}',
                style: Tv.title(28, color: current ? Colors.black : Tv.text)),
          ),
        ],
      ),
    );
  }
}

// ─── Boutons ───

class _ActionBar extends StatelessWidget {
  final X01Game game;
  final VoidCallback onUndo;
  final VoidCallback onMiss;
  final VoidCallback onNext;
  final VoidCallback onResults;
  const _ActionBar(
      {required this.game,
      required this.onUndo,
      required this.onMiss,
      required this.onNext,
      required this.onResults});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Tv.panel,
        border: Border(top: BorderSide(color: Tv.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Row(
            children: [
              Expanded(
                child: _BarButton(
                    icon: Icons.undo,
                    label: 'ANNULER',
                    onTap: game.canUndo ? onUndo : null),
              ),
              const SizedBox(width: 8),
              if (!game.finished) ...[
                Expanded(
                  child: _BarButton(
                      icon: Icons.block,
                      label: 'RATÉ',
                      onTap: game.turnOver ? null : onMiss),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: _BarButton(
                      icon: Icons.skip_next,
                      label: 'SUIVANT',
                      primary: true,
                      onTap: onNext),
                ),
              ] else
                Expanded(
                  flex: 3,
                  child: _BarButton(
                      icon: Icons.emoji_events,
                      label: 'RÉSULTATS',
                      primary: true,
                      onTap: onResults),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bouton du bas : icône au-dessus du texte (ne se coupe jamais).
class _BarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  const _BarButton(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.primary = false});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final fg = primary
        ? Colors.black
        : enabled
            ? Tv.text
            : Tv.line;
    return Material(
      color: Colors.transparent,
      child: Ink(
        height: 60,
        decoration: BoxDecoration(
          gradient: primary && enabled ? Tv.goldGradient : null,
          color: primary && !enabled ? Tv.goldDark : null,
          borderRadius: BorderRadius.circular(12),
          border: primary ? null : Border.all(color: Tv.line, width: 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: fg, size: primary ? 26 : 22),
              FittedBox(
                fit: BoxFit.scaleDown,
                child:
                    Text(label, style: Tv.title(primary ? 20 : 15, color: fg)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
