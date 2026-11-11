import 'package:flutter/material.dart';

import '../game/x01.dart';
import '../players.dart';
import 'game_page.dart';
import 'setup_page.dart' show kTeamColors, kTeamNames;
import 'widgets.dart';

/// Fin de partie : classement et statistiques.
class ResultsPage extends StatelessWidget {
  final X01Game game;
  const ResultsPage({super.key, required this.game});

  /// Ordre d'affichage : gagnants d'abord, puis par reste croissant.
  List<int> get _ranking {
    final idx = List.generate(game.players.length, (i) => i);
    int key(int i) => game.settings.freeze
        ? game.teamRemaining(game.players[i].team)
        : game.stateOf(i).remaining;
    idx.sort((a, b) {
      final wa = game.winners.contains(a) ? 0 : 1;
      final wb = game.winners.contains(b) ? 0 : 1;
      if (wa != wb) return wa - wb;
      return key(a).compareTo(key(b));
    });
    return idx;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final names = game.winners.map((i) => game.players[i].name).join(', ');
    final freeze = game.settings.freeze;
    final winTeam = freeze && game.winners.isNotEmpty
        ? game.players[game.winners.first].team
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text('Résultats — ${game.settings.name}'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: cs.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 48)),
                  if (winTeam != null)
                    Text(kTeamNames[winTeam],
                        style: TextStyle(
                            color: kTeamColors[winTeam],
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                  Text(names,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 26, fontWeight: FontWeight.bold)),
                  Text(
                    game.endReason == EndReason.checkout
                        ? 'Victoire en ${game.round} manche${game.round > 1 ? 's' : ''}'
                        : 'Limite de ${game.settings.roundLimit} manches atteinte',
                    style: TextStyle(color: cs.onPrimaryContainer),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final (rank, i) in _ranking.indexed)
            _StatCard(game: game, index: i, rank: rank + 1),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56)),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.tune),
                  label: const Text('Réglages'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56)),
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => GamePage(
                            settings: game.settings, players: game.players)),
                  ),
                  icon: const Icon(Icons.replay),
                  label: const Text('Rejouer', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final X01Game game;
  final int index;
  final int rank;
  const _StatCard(
      {required this.game, required this.index, required this.rank});

  @override
  Widget build(BuildContext context) {
    final p = game.players[index];
    final s = game.stateOf(index);
    final color = PlayerStore.instance.byId(p.id)?.color ?? Colors.grey;
    final won = game.winners.contains(index);

    Widget stat(String label, String value) => Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              children: [
                Text(value,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.outline)),
              ],
            ),
          ),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Text('$rank.',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                PlayerAvatar(name: p.name, color: color, size: 30),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${won ? '🏆 ' : ''}${p.name}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                Text('Reste ${s.remaining}'),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                stat('Moyenne', s.average.toStringAsFixed(1)),
                stat('Fléchettes', '${s.darts}'),
                stat('Meilleure', '${s.highestTurn}'),
                stat('100+', '${s.count100}'),
                stat('180', '${s.count180}'),
                stat('Fin', s.checkout == null ? '–' : '${s.checkout}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
