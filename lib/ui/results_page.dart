import 'package:flutter/material.dart';

import '../audio.dart';
import '../game/x01.dart';
import '../players.dart';
import 'game_page.dart';
import 'setup_page.dart' show kTeamColors, kTeamNames;
import 'theme.dart';
import 'widgets.dart';

/// Fin de partie : podium et statistiques.
class ResultsPage extends StatefulWidget {
  final X01Game game;

  /// Envoi de la partie au serveur (true = enregistrée en ligne).
  final Future<bool>? saving;

  /// Écran TV : pas de boutons (tout se pilote depuis le téléphone).
  final bool tv;
  const ResultsPage(
      {super.key, required this.game, this.saving, this.tv = false});

  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  X01Game get game => widget.game;

  @override
  void initState() {
    super.initState();
    AudioService.instance.startMusic();
    widget.saving?.then((ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok
              ? 'Partie enregistrée sur le serveur'
              : 'Hors ligne : la partie sera envoyée plus tard')));
    });
  }

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
      final k = key(a).compareTo(key(b));
      if (k != 0) return k;
      return game.stateOf(b).average.compareTo(game.stateOf(a).average);
    });
    return idx;
  }

  @override
  Widget build(BuildContext context) {
    final freeze = game.settings.freeze;
    final ranking = _ranking;
    final winTeam = freeze && game.winners.isNotEmpty
        ? game.players[game.winners.first].team
        : null;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 46,
        automaticallyImplyLeading: false,
        title: Text('RÉSULTATS · ${game.settings.name.toUpperCase()}'),
      ),
      body: TvBackground(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Podium
            SizedBox(
              width: 340,
              child: Column(
                children: [
                  const SizedBox(height: 4),
                  if (winTeam != null)
                    Text(kTeamNames[winTeam].toUpperCase(),
                        style: Tv.title(22, color: kTeamColors[winTeam])),
                  Text(
                    game.endReason == EndReason.checkout
                        ? 'VICTOIRE EN ${game.round} MANCHE${game.round > 1 ? 'S' : ''}'
                        : game.endReason == EndReason.roundLimit
                            ? 'LIMITE DE ${game.settings.roundLimit} MANCHES'
                            : 'PARTIE ARRÊTÉE',
                    style: Tv.label(13),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.bottomCenter,
                        child: SizedBox(
                          width: 320,
                          child: _Podium(game: game, ranking: ranking),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Statistiques
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(4, 0, 12, 12),
                children: [
                  const TvSection('Statistiques',
                      padding: EdgeInsets.fromLTRB(4, 8, 4, 6)),
                  for (final (rank, i) in ranking.indexed)
                    _StatCard(game: game, index: i, rank: rank + 1),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: widget.tv
          ? null
          : Container(
              color: Tv.panel,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(46)),
                          onPressed: () => Navigator.popUntil(
                              context, (r) => r.isFirst),
                          icon: const Icon(Icons.home),
                          label: const Text('MENU PRINCIPAL'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(46)),
                          onPressed: () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (_) => GamePage(
                                    settings: game.settings,
                                    players: game.players)),
                          ),
                          icon: const Icon(Icons.replay),
                          label: Text('REJOUER',
                              style: Tv.title(20, color: Colors.black)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _Podium extends StatelessWidget {
  final X01Game game;
  final List<int> ranking;
  const _Podium({required this.game, required this.ranking});

  @override
  Widget build(BuildContext context) {
    // Ordre visuel : 2e, 1er, 3e
    final places = <(int, int)>[
      if (ranking.length > 1) (ranking[1], 2),
      (ranking[0], 1),
      if (ranking.length > 2) (ranking[2], 3),
    ];
    const heights = {1: 110.0, 2: 78.0, 3: 56.0};
    final medals = {
      1: Tv.gold,
      2: const Color(0xFFC0C4CC),
      3: const Color(0xFFCD7F32)
    };

    return SizedBox(
      height: 272,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (i, place) in places)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (place == 1)
                    const Text('🏆', style: TextStyle(fontSize: 34)),
                  PlayerAvatar(
                    id: game.players[i].id,
                    name: game.players[i].name,
                    color: PlayerStore.instance.colorOf(game.players[i].id),
                    size: place == 1 ? 52 : 40,
                  ),
                  const SizedBox(height: 4),
                  Text(game.players[i].name.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Tv.title(place == 1 ? 22 : 17)),
                  Text('MOY ${game.stateOf(i).average.toStringAsFixed(1)}',
                      style: Tv.label(11)),
                  const SizedBox(height: 4),
                  Container(
                    height: heights[place],
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          medals[place]!,
                          medals[place]!.withValues(alpha: 0.35)
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(8)),
                    ),
                    alignment: Alignment.topCenter,
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('$place',
                        style: Tv.title(34, color: Colors.black)),
                  ),
                ],
              ),
            ),
        ],
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
    final color = PlayerStore.instance.colorOf(p.id);
    final won = game.winners.contains(index);

    Widget stat(String label, String value) => Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              children: [
                Text(value, style: Tv.title(22)),
                Text(label.toUpperCase(), style: Tv.label(10)),
              ],
            ),
          ),
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        gradient: Tv.panelGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: won ? Tv.gold : Tv.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: Colors.black38,
            padding: const EdgeInsets.fromLTRB(0, 0, 12, 0),
            child: Row(
              children: [
                Container(width: 6, height: 40, color: color),
                const SizedBox(width: 10),
                Text('$rank', style: Tv.title(22, color: Tv.gold)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('${won ? '🏆 ' : ''}${p.name.toUpperCase()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Tv.title(20)),
                ),
                Text('RESTE ', style: Tv.label(11)),
                Text('${s.remaining}', style: Tv.title(22)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            child: Row(
              children: [
                stat('Moyenne', s.average.toStringAsFixed(1)),
                stat('Fléchettes', '${s.darts}'),
                stat('Meilleure', '${s.highestTurn}'),
                stat('100+', '${s.count100}'),
                stat('180', '${s.count180}'),
                stat('Fin', s.checkout == null ? '–' : '${s.checkout}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
