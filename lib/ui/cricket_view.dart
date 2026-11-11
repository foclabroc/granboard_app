import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio.dart';
import '../game/cricket.dart';
import '../players.dart';
import 'dartboard.dart';
import 'game_fx.dart';
import 'game_page.dart' show GamePage;
import 'setup_page.dart' show kTeamColors, kTeamNames;
import 'theme.dart';
import 'widgets.dart';

Color _playerColor(CricketGame g, int i) =>
    PlayerStore.instance.colorOf(g.players[i].id);

/// Couleur d'un côté : équipe ou joueur.
Color sideColor(CricketGame g, int side) => g.settings.teams
    ? kTeamColors[side % kTeamColors.length]
    : _playerColor(g, side);

String sideName(CricketGame g, int side) => g.settings.teams
    ? kTeamNames[side % kTeamNames.length]
    : g.players[side].name;

/// Partie de Cricket : cible animée | joueur en cours (+ boutons) | tableau
/// des marques. Partagé par le téléphone et l'écran TV.
class CricketLayout extends StatelessWidget {
  final CricketGame game;
  final GlobalKey<GameSplashState> splashKey;
  final Widget? actionBar;
  const CricketLayout(
      {super.key, required this.game, required this.splashKey, this.actionBar});

  @override
  Widget build(BuildContext context) {
    final t = game.currentTurn;
    return Stack(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, c) => Padding(
                padding: const EdgeInsets.all(6),
                child: AnimatedDartboard(
                  size: c.maxHeight - 12,
                  hits: [
                    for (final d in t.darts)
                      if (d.hit != null) d.hit!
                  ],
                  win: game.finished,
                  dartColor: _playerColor(game, game.current),
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Column(
                children: [
                  Expanded(child: _CurrentPanel(game: game)),
                  if (actionBar != null) actionBar!,
                ],
              ),
            ),
            Expanded(flex: 5, child: CricketBoard(game: game)),
          ],
        ),
        Positioned.fill(
            child: IgnorePointer(child: GameSplash(key: splashKey))),
      ],
    );
  }
}

class _CurrentPanel extends StatelessWidget {
  final CricketGame game;
  const _CurrentPanel({required this.game});

  @override
  Widget build(BuildContext context) {
    final g = game;
    final p = g.currentPlayer;
    final side = g.sideOf(g.current);
    final color = _playerColor(g, g.current);
    final t = g.currentTurn;
    final v = g.variant;

    String status = '';
    Color statusColor = Tv.muted;
    if (g.finished) {
      final names = g.winners.map((i) => g.players[i].name).join(', ');
      status = '🏆 $names ${g.winners.length > 1 ? 'gagnent' : 'gagne'} !';
      statusColor = Tv.goldLight;
    } else if (g.turnOver) {
      status = 'Retire tes fléchettes · « Suivant »';
    } else if (g.isSpoiler(side)) {
      status = 'SPOILER : tu ne peux plus gagner';
      statusColor = Tv.red;
    } else if (g.allClosed(side) && v.scoring) {
      status = v.cutThroat
          ? 'Tout fermé : attends d\'avoir le moins de points'
          : 'Tout fermé : marque des points pour passer devant';
      statusColor = Tv.goldLight;
    } else if (v.hidden) {
      final left = g.targets.where((x) => !x.revealed).length;
      status = left == 0
          ? ''
          : '$left cible${left > 1 ? 's' : ''} cachée${left > 1 ? 's' : ''}';
    }

    final scoreText = v.scoring
        ? '${g.scoreOf(side)}'
        : '${g.closedMarks(side)}/${g.targets.length * 3}';

    return Container(
      margin: const EdgeInsets.fromLTRB(4, 6, 4, 4),
      decoration: BoxDecoration(
        gradient: Tv.panelGradient,
        borderRadius: BorderRadius.circular(16),
        border: const Border(top: BorderSide(color: Tv.gold, width: 4)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
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
              if (g.settings.teams) ...[
                const SizedBox(width: 6),
                Text(kTeamNames[p.team].split(' ').last,
                    style: Tv.title(18, color: kTeamColors[p.team])),
              ],
            ],
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    alignment: Alignment.centerLeft,
                    child: Text(scoreText,
                        style: Tv.title(96, color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  flex: 0,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                        v.scoring
                            ? (v.cutThroat ? 'PTS\n(− = MIEUX)' : 'PTS')
                            : 'MARQUES',
                        style: Tv.label(11)),
                  ),
                ),
              ],
            ),
          ),
          Text(status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Tv.title(16, color: statusColor)),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < 3; i++)
                Expanded(
                    child: _DartSlot(
                        dart: i < t.darts.length ? t.darts[i] : null)),
              Container(
                width: 64,
                height: 48,
                margin: const EdgeInsets.only(left: 4),
                decoration: BoxDecoration(
                  gradient: Tv.goldGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('MARQUES',
                          style: Tv.label(10, color: Colors.black87)),
                      Text('${t.marks}',
                          style: Tv.title(22, color: Colors.black)),
                    ],
                  ),
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
  final CricketDart? dart;
  const _DartSlot({required this.dart});

  @override
  Widget build(BuildContext context) {
    final d = dart;
    final h = d?.hit;
    final useful = d != null && d.marks > 0;
    Color c = Colors.black26;
    if (d != null) c = useful ? Tv.green : Tv.panel2;
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: c,
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
                  Text(h == null ? 'RATÉ' : h.label,
                      style: Tv.title(22,
                          color: useful ? Colors.white : Tv.muted)),
                  if (useful)
                    Text(
                        d.points > 0
                            ? '+${d.marks} · ${d.points} PT'
                            : '+${d.marks}',
                        style: Tv.label(10, color: Colors.white)),
                ],
              ),
            ),
    );
  }
}

/// Tableau des marques : une ligne par cible, une colonne par joueur / équipe.
class CricketBoard extends StatelessWidget {
  final CricketGame game;
  const CricketBoard({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final g = game;
    final sides = g.sides;
    final cur = g.sideOf(g.current);
    return Container(
      margin: const EdgeInsets.fromLTRB(4, 6, 8, 6),
      decoration: BoxDecoration(
        gradient: Tv.panelGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Tv.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(builder: (context, c) {
        final rows = g.targets.length + 1;
        final rowH = c.maxHeight / rows;
        final labelW = math.min(56.0, c.maxWidth * 0.2);
        final colW = (c.maxWidth - labelW) / sides.length;
        // Colonnes étroites (beaucoup de joueurs) : nom abrégé, lisible
        final maxChars = math.max(3, (colW / 9).floor());
        String shortName(String n) =>
            n.length <= maxChars ? n : n.substring(0, maxChars);
        Widget cell(int side, Widget child, {bool header = false}) => Container(
              width: colW,
              height: rowH,
              decoration: BoxDecoration(
                color: side == cur && !g.finished
                    ? Tv.gold.withValues(alpha: header ? 0.22 : 0.08)
                    : null,
                border: const Border(left: BorderSide(color: Tv.line)),
              ),
              alignment: Alignment.center,
              child: child,
            );
        return Column(
          children: [
            // En-tête : nom + score
            SizedBox(
              height: rowH,
              child: Row(
                children: [
                  SizedBox(
                    width: labelW,
                    child:
                        Center(child: Text('R${g.round}', style: Tv.label(11))),
                  ),
                  for (final s in sides)
                    cell(
                        s,
                        header: true,
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                        width: 4,
                                        height: 12,
                                        color: sideColor(g, s)),
                                    const SizedBox(width: 3),
                                    Text(
                                        shortName(sideName(g, s)).toUpperCase(),
                                        style: Tv.title(13)),
                                  ],
                                ),
                                Text(
                                    g.variant.scoring
                                        ? '${g.scoreOf(s)}'
                                        : '${g.closedMarks(s)}',
                                    style: Tv.title(20,
                                        color: g.isSpoiler(s)
                                            ? Tv.red
                                            : Tv.goldLight)),
                              ],
                            ),
                          ),
                        )),
                ],
              ),
            ),
            for (var t = 0; t < g.targets.length; t++)
              Container(
                height: rowH,
                decoration: BoxDecoration(
                  color: g.dead(t) ? Colors.black45 : null,
                  border: const Border(top: BorderSide(color: Tv.line)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: labelW,
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            !g.targets[t].revealed
                                ? '?'
                                : g.variant == CricketVariant.tripleOnly
                                    ? 'T${g.targets[t].label}'
                                    : g.targets[t].label,
                            style: Tv.title(rowH * 0.55,
                                color: g.dead(t)
                                    ? Tv.muted
                                    : !g.targets[t].revealed
                                        ? Tv.ice
                                        : Tv.gold),
                          ),
                        ),
                      ),
                    ),
                    for (final s in sides)
                      cell(
                        s,
                        SizedBox.square(
                          dimension: math.min(rowH, colW) * 0.72,
                          child: CustomPaint(
                            painter: MarkPainter(
                              g.marksOf(s, t),
                              g.dead(t) ? Tv.muted : sideColor(g, s),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
      }),
    );
  }
}

/// Marques du Cricket : / (1), X (2), X entouré (3, fermé).
class MarkPainter extends CustomPainter {
  final int marks;
  final Color color;
  MarkPainter(this.marks, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (marks <= 0) return;
    final w = size.width;
    final p = Paint()
      ..color = color
      ..strokeWidth = math.max(2, w * 0.12)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final a = w * 0.22, b = w * 0.78;
    canvas.drawLine(Offset(b, a), Offset(a, b), p);
    if (marks >= 2) canvas.drawLine(Offset(a, a), Offset(b, b), p);
    if (marks >= 3) {
      canvas.drawCircle(Offset(w / 2, w / 2), w * 0.45, p);
    }
  }

  @override
  bool shouldRepaint(MarkPainter old) =>
      old.marks != marks || old.color != color;
}

// ─── Résultats ───

class CricketResultsPage extends StatefulWidget {
  final CricketGame game;
  final Future<bool>? saving;
  final bool tv;
  const CricketResultsPage(
      {super.key, required this.game, this.saving, this.tv = false});

  @override
  State<CricketResultsPage> createState() => _CricketResultsPageState();
}

class _CricketResultsPageState extends State<CricketResultsPage> {
  CricketGame get g => widget.game;

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

  @override
  Widget build(BuildContext context) {
    final ranking = g.sideRanking;
    final reason = g.endReason == CricketEnd.closed
        ? 'VICTOIRE EN ${g.round} MANCHE${g.round > 1 ? 'S' : ''}'
        : g.endReason == CricketEnd.roundLimit
            ? 'LIMITE DE ${g.settings.roundLimit} MANCHES'
            : 'PARTIE ARRÊTÉE';
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 46,
        automaticallyImplyLeading: false,
        title: Text('RÉSULTATS · ${g.title.toUpperCase()}'),
      ),
      body: TvBackground(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 300,
              child: Column(
                children: [
                  const SizedBox(height: 6),
                  Text(reason, style: Tv.label(13)),
                  const SizedBox(height: 6),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(10, 0, 6, 10),
                      children: [
                        for (final (rank, s) in ranking.indexed)
                          _SideRow(game: g, side: s, rank: rank + 1),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(4, 0, 12, 12),
                children: [
                  const TvSection('Statistiques',
                      padding: EdgeInsets.fromLTRB(4, 8, 4, 6)),
                  for (final s in ranking)
                    for (final i in g.membersOf(s))
                      _PlayerStats(game: g, index: i),
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
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.tune),
                          label: const Text('RÉGLAGES'),
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
                                    game: CricketGame(
                                        g.settings.withSeed(DateTime.now()
                                            .microsecondsSinceEpoch),
                                        g.players))),
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

class _SideRow extends StatelessWidget {
  final CricketGame game;
  final int side;
  final int rank;
  const _SideRow({required this.game, required this.side, required this.rank});

  @override
  Widget build(BuildContext context) {
    final g = game;
    final won = g.winners.any((i) => g.sideOf(i) == side);
    const medals = {1: Tv.gold, 2: Color(0xFFC0C4CC), 3: Color(0xFFCD7F32)};
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
      decoration: BoxDecoration(
        gradient: Tv.panelGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: won ? Tv.gold : Tv.line, width: won ? 2 : 1),
      ),
      child: Row(
        children: [
          Text('$rank', style: Tv.title(30, color: medals[rank] ?? Tv.muted)),
          const SizedBox(width: 10),
          if (!g.settings.teams)
            PlayerAvatar(
                name: g.players[side].name, color: sideColor(g, side), size: 34)
          else
            Container(width: 6, height: 34, color: sideColor(g, side)),
          const SizedBox(width: 10),
          Expanded(
            child: Text('${won ? '🏆 ' : ''}${sideName(g, side).toUpperCase()}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Tv.title(20)),
          ),
          Text(
              g.variant.scoring
                  ? '${g.scoreOf(side)}'
                  : '${g.closedMarks(side)}',
              style: Tv.title(24, color: Tv.goldLight)),
        ],
      ),
    );
  }
}

class _PlayerStats extends StatelessWidget {
  final CricketGame game;
  final int index;
  const _PlayerStats({required this.game, required this.index});

  @override
  Widget build(BuildContext context) {
    final p = game.players[index];
    final s = game.statsOf(index);
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
            child: Row(
              children: [
                Container(
                    width: 6, height: 34, color: _playerColor(game, index)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('${won ? '🏆 ' : ''}${p.name.toUpperCase()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Tv.title(19)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            child: Row(
              children: [
                stat('MPR', s.mpr.toStringAsFixed(2)),
                stat('Marques', '${s.marks}'),
                stat('Fléchettes', '${s.darts}'),
                stat('Meilleure', '${s.bestTurn}'),
                stat('5+ marques', '${s.turns5}'),
                if (game.variant.scoring)
                  stat(game.variant.cutThroat ? 'Donnés' : 'Points',
                      '${s.points}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
