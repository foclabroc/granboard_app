import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../board_service.dart';
import '../game/x01.dart';
import '../granboard.dart';
import '../players.dart';
import 'results_page.dart';
import 'setup_page.dart' show kTeamColors, kTeamNames;
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
  bool _recorded = false;

  @override
  void initState() {
    super.initState();
    _sub = BoardService.instance.events.listen(_onEvent);
    WakelockPlus.enable().catchError((_) {});
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
    if (game.currentTurn.isBust || game.finished) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  void _next() {
    if (game.finished) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() => game.next());
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
        title: const Text('Abandonner la partie ?'),
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
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.name),
              Text(s.rulesLabel, style: const TextStyle(fontSize: 12)),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  s.roundLimit == null
                      ? 'Manche ${game.round}'
                      : 'Manche ${game.round}/${s.roundLimit}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
        body: Column(
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
      ),
    );
  }
}

Color _colorOf(X01Player p) =>
    PlayerStore.instance.byId(p.id)?.color ?? Colors.grey;

// ─── Joueur en cours ───

class _CurrentPanel extends StatelessWidget {
  final X01Game game;
  const _CurrentPanel({required this.game});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = game.currentPlayer;
    final st = game.currentState;
    final turn = game.currentTurn;
    final frozen = game.isFrozen(game.current);
    final freeze = game.settings.freeze;

    Color bg = cs.surfaceContainerHigh;
    String status;
    Color statusColor = cs.onSurface;

    if (game.finished) {
      bg = Colors.green.withValues(alpha: 0.30);
      final names = game.winners.map((i) => game.players[i].name).join(', ');
      status = game.endReason == EndReason.checkout
          ? '🏆 $names ${game.winners.length > 1 ? 'gagnent' : 'gagne'} !'
          : '🏁 Limite de manches : $names';
    } else if (turn.isBust) {
      bg = Colors.red.withValues(alpha: 0.30);
      status = 'BUST — ${turn.bust!.label}';
      statusColor = Colors.redAccent;
    } else if (game.turnOver) {
      status = 'Retire tes fléchettes puis « Suivant »';
      statusColor = cs.outline;
    } else if (!st.opened) {
      status = game.settings.inRule == InRule.double
          ? 'Il faut un double pour commencer'
          : 'Il faut un double, un triple ou le bull pour commencer';
      statusColor = Colors.amberAccent;
    } else if (frozen) {
      bg = Colors.lightBlue.withValues(alpha: 0.20);
      status = '❄ Équipe gelée : impossible de finir';
      statusColor = Colors.lightBlueAccent;
    } else {
      final hint = game.checkoutHint;
      status = hint == null ? '' : 'Fin : ${hint.join('  ·  ')}';
      statusColor = Colors.greenAccent;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _colorOf(p), width: 3),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PlayerAvatar(name: p.name, color: _colorOf(p), size: 28),
              const SizedBox(width: 8),
              Flexible(
                child: Text(p.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
              ),
              if (freeze) ...[
                const SizedBox(width: 8),
                Text(kTeamNames[p.team],
                    style: TextStyle(
                        color: kTeamColors[p.team],
                        fontWeight: FontWeight.bold)),
              ],
            ],
          ),
          FittedBox(
            child: Text('${st.remaining}',
                style: const TextStyle(
                    fontSize: 96, fontWeight: FontWeight.w900, height: 1.1)),
          ),
          SizedBox(
            height: 22,
            child: Text(status,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < 3; i++)
                Expanded(
                  child: _DartSlot(
                      dart: i < turn.darts.length ? turn.darts[i] : null,
                      bust: turn.isBust),
                ),
              SizedBox(
                width: 64,
                child: Column(
                  children: [
                    Text('Total',
                        style: TextStyle(color: cs.outline, fontSize: 12)),
                    Text(
                        turn.isBust
                            ? '0'
                            : '${turn.darts.fold<int>(0, (s, d) => s + d.points)}',
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
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
    final cs = Theme.of(context).colorScheme;
    final d = dart;
    final h = d?.hit;
    Color c = cs.surfaceContainerHighest;
    if (h != null) {
      if (h.multiplier == 3) c = Colors.red.shade700;
      if (h.multiplier == 2) c = Colors.green.shade700;
    }
    return Container(
      height: 56,
      padding: const EdgeInsets.all(4),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: d == null ? Colors.transparent : c,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      alignment: Alignment.center,
      child: d == null
          ? Text('–', style: TextStyle(color: cs.outline, fontSize: 22))
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(d.label,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          decoration:
                              bust ? TextDecoration.lineThrough : null)),
                  if (h != null && d.points != h.score)
                    Text('${d.points} pt',
                        style: const TextStyle(fontSize: 11)),
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
        rows.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
          child: Row(
            children: [
              Text(kTeamNames[t],
                  style: TextStyle(
                      color: kTeamColors[t], fontWeight: FontWeight.bold)),
              if (frozen) const Text('  ❄ gelée'),
              const Spacer(),
              Text('${game.teamRemaining(t)}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ));
        for (final i in game.membersOf(t)) {
          rows.add(_PlayerRow(game: game, index: i));
        }
      }
    } else {
      for (var i = 0; i < game.players.length; i++) {
        rows.add(_PlayerRow(game: game, index: i));
      }
    }
    return ListView(padding: const EdgeInsets.only(top: 4), children: rows);
  }
}

class _PlayerRow extends StatelessWidget {
  final X01Game game;
  final int index;
  const _PlayerRow({required this.game, required this.index});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = game.players[index];
    final st = game.stateOf(index);
    final current = index == game.current && !game.finished;
    final winner = game.winners.contains(index);
    final last = game.lastTurnOf(index);

    final lastText = last == null
        ? ''
        : last.isBust
            ? 'Dernière : BUST'
            : 'Dernière : ${last.total}';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: current ? cs.primaryContainer : cs.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        dense: true,
        leading: PlayerAvatar(name: p.name, color: _colorOf(p), size: 32),
        title: Text(
          '${winner ? '🏆 ' : ''}${p.name}',
          style: TextStyle(
              fontWeight: current ? FontWeight.bold : FontWeight.normal,
              fontSize: 16),
        ),
        subtitle: Text('Moy ${st.average.toStringAsFixed(1)}'
            '${lastText.isEmpty ? '' : '  ·  $lastText'}'
            '${st.opened ? '' : '  ·  pas ouvert'}'),
        trailing: Text('${st.remaining}',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
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
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56)),
                onPressed: game.canUndo ? onUndo : null,
                icon: const Icon(Icons.undo),
                label: const Text('Annuler'),
              ),
            ),
            const SizedBox(width: 8),
            if (!game.finished) ...[
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56)),
                  onPressed: game.turnOver ? null : onMiss,
                  icon: const Icon(Icons.block),
                  label: const Text('Raté'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56)),
                  onPressed: onNext,
                  icon: const Icon(Icons.skip_next),
                  label: const Text('Suivant', style: TextStyle(fontSize: 18)),
                ),
              ),
            ] else
              Expanded(
                flex: 3,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56)),
                  onPressed: onResults,
                  icon: const Icon(Icons.emoji_events),
                  label:
                      const Text('Résultats', style: TextStyle(fontSize: 18)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
