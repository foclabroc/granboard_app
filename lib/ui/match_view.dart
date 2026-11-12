import 'package:flutter/material.dart';

import '../audio.dart';
import '../game/cricket.dart';
import '../game/match.dart';
import '../game/x01.dart';
import '../players.dart';
import 'game_page.dart' show GamePage;
import 'theme.dart';
import 'widgets.dart';
import '../format.dart';

/// Résultats d'un match : classement aux legs | détail des legs et stats.
class MatchResultsPage extends StatefulWidget {
  final MatchGame game;
  final Future<bool>? saving;
  final bool tv;
  const MatchResultsPage(
      {super.key, required this.game, this.saving, this.tv = false});

  @override
  State<MatchResultsPage> createState() => _MatchResultsPageState();
}

class _MatchResultsPageState extends State<MatchResultsPage> {
  MatchGame get m => widget.game;

  @override
  void initState() {
    super.initState();
    AudioService.instance.startMusic();
    widget.saving?.then((ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok
              ? 'Match enregistré sur le serveur'
              : 'Hors ligne : le match sera envoyé plus tard')));
    });
  }

  /// Moyenne 01 et MPR Cricket du joueur sur tout le match.
  (double?, double?) _stats(String id) {
    var xd = 0, xp = 0, cd = 0, cm = 0;
    for (final l in m.legs) {
      final i = l.players.indexWhere((p) => p.id == id);
      if (i < 0) continue;
      switch (l) {
        case X01Game g:
          xd += g.stateOf(i).darts;
          xp += g.stateOf(i).points;
        case CricketGame g:
          cd += g.statsOf(i).darts;
          cm += g.statsOf(i).marks;
      }
    }
    return (xd == 0 ? null : xp * 3 / xd, cd == 0 ? null : cm * 3 / cd);
  }

  @override
  Widget build(BuildContext context) {
    final order = List.generate(m.players.length, (i) => i)
      ..sort((a, b) {
        final w =
            (m.winners.contains(a) ? 0 : 1) - (m.winners.contains(b) ? 0 : 1);
        if (w != 0) return w;
        return m.legWinsOf(b).compareTo(m.legWinsOf(a));
      });
    final medals = {
      1: Tv.gold,
      2: const Color(0xFFC0C4CC),
      3: const Color(0xFFCD7F32)
    };
    final legWinners = m.legWinners;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 46,
        automaticallyImplyLeading: false,
        title: Text('RÉSULTATS · MATCH ${m.settings.legs} LEGS'),
      ),
      body: TvBackground(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 300,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(10, 8, 6, 10),
                children: [
                  Center(
                      child: Text(
                          m.finished
                              ? 'MATCH EN ${m.legNumber} LEGS'
                              : 'MATCH ARRÊTÉ',
                          style: Tv.label(13))),
                  const SizedBox(height: 6),
                  for (final (rank, i) in order.indexed)
                    Builder(builder: (context) {
                      final p = m.players[i];
                      final won = m.winners.contains(i);
                      final (avg, mpr) = _stats(p.id);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
                        decoration: BoxDecoration(
                          gradient: Tv.panelGradient,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: won ? Tv.gold : Tv.line,
                              width: won ? 2 : 1),
                        ),
                        child: Row(
                          children: [
                            Text('${rank + 1}',
                                style: Tv.title(30,
                                    color: medals[rank + 1] ?? Tv.muted)),
                            const SizedBox(width: 10),
                            PlayerAvatar(
                                id: p.id,
                                name: p.name,
                                color: PlayerStore.instance.colorOf(p.id),
                                size: 34),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      '${won ? '🏆 ' : ''}${p.name.toUpperCase()}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Tv.title(20)),
                                  Text(
                                      [
                                        if (avg != null) 'MOY ${avg.fr(1)}',
                                        if (mpr != null) 'MPR ${mpr.fr(2)}',
                                      ].join(' · '),
                                      style: Tv.label(11, color: Tv.text)),
                                ],
                              ),
                            ),
                            Text('${m.legWinsOf(i)}',
                                style: Tv.title(30, color: Tv.goldLight)),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(4, 0, 12, 12),
                children: [
                  const TvSection('Legs',
                      padding: EdgeInsets.fromLTRB(4, 8, 4, 6)),
                  for (final (k, l) in m.legs.indexed)
                    if (l.finished)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Tv.panel,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Tv.line),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                                width: 64,
                                child: Text('LEG ${k + 1}',
                                    style: Tv.title(17, color: Tv.gold))),
                            Expanded(
                                child: Text(l.title.toUpperCase(),
                                    style: Tv.title(17))),
                            Icon(Icons.emoji_events, color: Tv.gold, size: 18),
                            const SizedBox(width: 4),
                            Text(
                                legWinners[k]
                                    .map((i) => m.players[i].name)
                                    .join(', '),
                                style: Tv.title(17)),
                            const SizedBox(width: 10),
                            Text('${l.round} M.',
                                style: Tv.label(12, color: Tv.text)),
                          ],
                        ),
                      ),
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
                          onPressed: () =>
                              Navigator.popUntil(context, (r) => r.isFirst),
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
                                builder: (_) => GamePage(game: MatchGame(
                                    m.settings,
                                    // Le joueur suivant commence la revanche
                                    [...m.players.skip(1), m.players.first]))),
                          ),
                          icon: const Icon(Icons.replay),
                          label: Text('REVANCHE',
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
