import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio.dart';
import '../game/cricket.dart';
import '../players.dart';
import 'game_fx.dart';
import 'game_page.dart' show GamePage;
import 'setup_page.dart' show kTeamColors, kTeamNames;
import 'theme.dart';
import 'widgets.dart';

/// Couleur de chaque joueur dans la partie : sa couleur de compte, sauf
/// invité ou couleur déjà prise (on prend alors une couleur libre), pour que
/// chaque colonne se distingue.
List<Color> _playerColors(CricketGame g) =>
    PlayerStore.instance.distinctColors([for (final p in g.players) p.id]);

Color _playerColor(CricketGame g, int i) => _playerColors(g)[i];

/// Couleur d'un côté : équipe ou joueur.
Color sideColor(CricketGame g, int side) => g.settings.teams
    ? kTeamColors[side % kTeamColors.length]
    : _playerColor(g, side);

String sideName(CricketGame g, int side) => g.settings.teams
    ? kTeamNames[side % kTeamNames.length]
    : g.players[side].name;

/// Partie de Cricket, façon GranBoard : historique du joueur | tableau des
/// marques (numéros au centre, une colonne par joueur / équipe de chaque
/// côté) | MPR + fléchettes de la manche (+ boutons), et la barre des
/// joueurs en bas. Partagé par le téléphone et l'écran TV.
class CricketLayout extends StatefulWidget {
  final CricketGame game;
  final GlobalKey<GameSplashState> splashKey;
  final Widget? actionBar;
  const CricketLayout(
      {super.key, required this.game, required this.splashKey, this.actionBar});

  @override
  State<CricketLayout> createState() => _CricketLayoutState();
}

class _CricketLayoutState extends State<CricketLayout>
    with SingleTickerProviderStateMixin {
  // Grandes marques de la manche, affichées après la 3e fléchette
  late final _anim = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1700));
  List<int> _bigMarks = const [];
  Color _bigColor = Tv.gold;
  int _seen = 0;

  CricketGame get game => widget.game;

  @override
  void initState() {
    super.initState();
    _seen = game.actionLog.length;
  }

  @override
  void didUpdateWidget(CricketLayout old) {
    super.didUpdateWidget(old);
    final n = game.actionLog.length;
    if (n > _seen) {
      final t = game.currentTurn;
      final last = game.actionLog.last;
      if (last != 'n' && t.darts.length == 3) {
        final marks = [for (final d in t.darts) _dartMarks(d)];
        if (marks.any((m) => m > 0)) {
          _bigMarks = marks;
          _bigColor = sideColor(game, game.sideOf(game.current));
          _anim.forward(from: 0);
        }
      }
    }
    _seen = n;
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        LayoutBuilder(builder: (context, c) {
          final barH = (c.maxHeight * 0.2).clamp(52.0, 96.0);
          final sideW = (c.maxWidth * 0.17).clamp(110.0, 220.0);
          return Column(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: sideW, child: _History(game: game)),
                    Expanded(child: _MarksArena(game: game)),
                    SizedBox(
                        width: sideW,
                        child: _RightPanel(
                            game: game, actionBar: widget.actionBar)),
                  ],
                ),
              ),
              SizedBox(height: barH, child: _PlayersBar(game: game)),
            ],
          );
        }),
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _anim,
              builder: (context, _) {
                final v = _anim.value;
                if (v == 0 || v == 1) return const SizedBox.shrink();
                final fade = v < 0.8 ? 1.0 : 1 - (v - 0.8) / 0.2;
                return LayoutBuilder(builder: (context, c) {
                  final size = math.min(c.maxHeight * 0.55, c.maxWidth / 3.6);
                  return Container(
                    color: Colors.black.withValues(alpha: 0.35 * fade),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < _bigMarks.length; i++)
                          Builder(builder: (context) {
                            // Chaque marque arrive à son tour
                            final st = ((v - i * 0.1) / 0.18).clamp(0.0, 1.0);
                            final sc = Curves.easeOutBack.transform(st);
                            return Opacity(
                              opacity: (st * fade).clamp(0.0, 1.0),
                              child: Transform.scale(
                                scale: 0.3 + 0.7 * sc,
                                child: SizedBox.square(
                                  dimension: size,
                                  child: CustomPaint(
                                    painter: MarkPainter(
                                        _bigMarks[i], _bigColor,
                                        weight: 0.13),
                                  ),
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                  );
                });
              },
            ),
          ),
        ),
        Positioned.fill(
            child: IgnorePointer(child: GameSplash(key: widget.splashKey))),
      ],
    );
  }
}

/// Marques « brutes » d'une fléchette pour l'historique (0 = rien d'utile).
int _dartMarks(CricketDart d) => d.marks.clamp(0, 3);

/// Gauche : statut + manches du joueur en cours (R1 / / /, R2 Ⓧ Ⓧ…).
class _History extends StatelessWidget {
  final CricketGame game;
  const _History({required this.game});

  @override
  Widget build(BuildContext context) {
    final g = game;
    final side = g.sideOf(g.current);
    final v = g.variant;
    String status = '';
    Color statusColor = Tv.muted;
    if (g.finished) {
      final names = g.winners.map((i) => g.players[i].name).join(', ');
      status = '🏆 $names ${g.winners.length > 1 ? 'gagnent' : 'gagne'} !';
      statusColor = Tv.goldLight;
    } else if (g.turnOver) {
      status = 'Retire tes fléchettes\npuis « Suivant »';
    } else if (g.isSpoiler(side)) {
      status = 'SPOILER :\nne peut plus gagner';
      statusColor = Tv.red;
    } else if (g.allClosed(side) && v.scoring) {
      status = v.cutThroat
          ? 'Tout fermé : il faut\nle moins de points'
          : 'Tout fermé : marque\npour passer devant';
      statusColor = Tv.goldLight;
    } else if (v.hidden) {
      final left = g.targets.where((x) => !x.revealed).length;
      if (left > 0) {
        status =
            '$left cible${left > 1 ? 's' : ''} cachée${left > 1 ? 's' : ''}';
        statusColor = Tv.ice;
      }
    }
    final turns = [
      for (final t in g.turns)
        if (t.player == g.current) t
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(6, 6, 0, 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (status.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(status,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Tv.title(13, color: statusColor)),
            ),
          const SizedBox(height: 4),
          Expanded(
            child: LayoutBuilder(builder: (context, c) {
              const rowH = 30.0;
              final fit = (c.maxHeight / rowH).floor().clamp(1, 99);
              final shown = turns.length > fit
                  ? turns.sublist(turns.length - fit)
                  : turns;
              return Column(
                children: [
                  for (final t in shown)
                    Container(
                      height: rowH,
                      decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: Tv.line))),
                      child: Row(
                        children: [
                          SizedBox(
                              width: 30,
                              child: Text('R${t.round}',
                                  style: Tv.title(14,
                                      color: identical(t, g.currentTurn)
                                          ? Tv.gold
                                          : Colors.white))),
                          for (final d in t.darts)
                            SizedBox.square(
                              dimension: 22,
                              child: _dartMarks(d) == 0
                                  ? Center(
                                      child: Text('–',
                                          style: Tv.title(14, color: Tv.muted)))
                                  : CustomPaint(
                                      painter: MarkPainter(
                                          _dartMarks(d), Colors.white)),
                            ),
                        ],
                      ),
                    ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// Centre : numéros au milieu, colonnes des joueurs / équipes de chaque côté.
class _MarksArena extends StatelessWidget {
  final CricketGame game;
  const _MarksArena({required this.game});

  @override
  Widget build(BuildContext context) {
    final g = game;
    final sides = g.sides;
    final left = sides.take((sides.length + 1) ~/ 2).toList();
    final right = sides.skip(left.length).toList();
    final cur = g.sideOf(g.current);
    return LayoutBuilder(builder: (context, c) {
      final rows = g.targets.length;
      const pad = 6.0;
      final rowH = (c.maxHeight - pad * 2 - 4) / rows;
      final numW = math.min(64.0, math.max(40.0, rowH * 1.25));
      final perSide = math.max(left.length, right.length);
      final colW = math.min(rowH * (perSide <= 2 ? 1.5 : 1.15),
          (c.maxWidth - numW - 16) / (perSide * 2) - 4);
      final mark = math.min(rowH, colW) * 0.78;

      Widget column(int s) {
        final color = sideColor(g, s);
        final active = s == cur && !g.finished;
        return Container(
          width: colW,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: active
                ? color.withValues(alpha: 0.16)
                : Colors.black.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: color.withValues(alpha: active ? 1 : 0.55),
                width: active ? 2 : 1.2),
          ),
          child: Column(
            children: [
              for (var t = 0; t < rows; t++)
                SizedBox(
                  height: rowH,
                  child: Center(
                    child: SizedBox.square(
                      dimension: mark,
                      child: CustomPaint(
                        painter: MarkPainter(
                            g.marksOf(s, t), g.dead(t) ? Tv.muted : color),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      }

      Widget numbers() => SizedBox(
            width: numW,
            child: Column(
              children: [
                for (var t = 0; t < rows; t++)
                  SizedBox(
                    height: rowH,
                    child: Center(
                      child: Container(
                        width: numW - 6,
                        height: rowH - 6,
                        decoration: BoxDecoration(
                          color: Tv.panel2,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            !g.targets[t].revealed
                                ? '?'
                                : g.variant == CricketVariant.tripleOnly
                                    ? 'T${g.targets[t].number}'
                                    : g.targets[t].number == 25
                                        ? 'B'
                                        : g.targets[t].label,
                            style: Tv.title(rowH * 0.62,
                                color: g.dead(t)
                                    ? Tv.muted
                                    : !g.targets[t].revealed
                                        ? Tv.ice
                                        : Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );

      final rowW = (left.length + right.length) * (colW + 4) + numW;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: pad),
        child: Center(
          child: SizedBox(
            width: rowW,
            child: Stack(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final s in left) column(s),
                    numbers(),
                    for (final s in right) column(s),
                  ],
                ),
                // Numéro fermé par tout le monde : barré d'un trait gris
                for (var t = 0; t < rows; t++)
                  if (g.dead(t))
                    Positioned(
                      left: colW * 0.3,
                      right: colW * 0.3,
                      top: rowH * t + rowH / 2 - 2,
                      height: 4,
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Tv.muted.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

/// Droite : MPR du joueur, fléchettes de la manche, boutons (téléphone).
class _RightPanel extends StatelessWidget {
  final CricketGame game;
  final Widget? actionBar;
  const _RightPanel({required this.game, this.actionBar});

  @override
  Widget build(BuildContext context) {
    final g = game;
    final t = g.currentTurn;
    final mpr = g.statsOf(g.current).mpr;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 6, 6, 6),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('MPR ', style: Tv.title(14, color: Tv.text)),
                  Text(mpr.toStringAsFixed(2), style: Tv.title(28)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Column(
              children: [
                for (var i = 0; i < 3; i++)
                  Expanded(
                    child: _DartBox(
                        dart: i < t.darts.length ? t.darts[i] : null,
                        next: i == t.darts.length && !g.turnOver),
                  ),
              ],
            ),
          ),
          if (actionBar != null) ...[
            const SizedBox(height: 4),
            actionBar!,
          ],
        ],
      ),
    );
  }
}

class _DartBox extends StatelessWidget {
  final CricketDart? dart;
  final bool next;
  const _DartBox({required this.dart, required this.next});

  @override
  Widget build(BuildContext context) {
    final d = dart;
    final h = d?.hit;
    final useful = d != null && d.marks > 0;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: d == null ? Colors.black.withValues(alpha: 0.3) : Tv.panel2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: useful
                ? Tv.green
                : next
                    ? Tv.gold.withValues(alpha: 0.6)
                    : Tv.line,
            width: useful ? 2 : 1),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(2),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: d == null
            ? Icon(Icons.arrow_upward_rounded,
                color: next ? Tv.gold : Tv.muted, size: 26)
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(h == null ? '–' : '${h.score}',
                      style: Tv.title(28,
                          color: useful ? Colors.white : Tv.muted)),
                  Text(
                      h == null
                          ? 'RATÉ'
                          : useful && d.points > 0
                              ? '${h.label} · +${d.points}'
                              : h.label,
                      style: Tv.label(11, color: useful ? Tv.green : Tv.muted)),
                ],
              ),
      ),
    );
  }
}

/// Bas : score et joueurs de chaque côté ; bandeau à la couleur du joueur
/// en cours, avec son nom.
class _PlayersBar extends StatelessWidget {
  final CricketGame game;
  const _PlayersBar({required this.game});

  @override
  Widget build(BuildContext context) {
    final g = game;
    final cur = g.sideOf(g.current);
    final curColor = sideColor(g, cur);
    return LayoutBuilder(builder: (context, c) {
      final h = c.maxHeight;
      final av = (h * 0.34).clamp(18.0, 34.0);
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              curColor.withValues(alpha: 0.35),
              curColor.withValues(alpha: 0.85),
            ],
            stops: const [0, 0.45, 1],
          ),
        ),
        child: Row(
          children: [
            for (final s in g.sides)
              Expanded(
                child: Builder(builder: (context) {
                  final active = s == cur && !g.finished;
                  final won = g.winners.any((i) => g.sideOf(i) == s);
                  final score = g.variant.scoring
                      ? '${g.scoreOf(s)}'
                      : '${g.closedMarks(s)}';
                  return Opacity(
                    opacity: active || g.finished ? 1 : 0.75,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.bottomCenter,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(won ? '🏆 $score' : score,
                              style: Tv.title(h * 0.3,
                                  color: g.isSpoiler(s)
                                      ? Tv.red
                                      : active
                                          ? Colors.white
                                          : Tv.goldLight)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (final i in g.membersOf(s))
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 2),
                                  child: Container(
                                    padding: const EdgeInsets.all(1.5),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: i == g.current && !g.finished
                                          ? Colors.white
                                          : Colors.transparent,
                                    ),
                                    child: PlayerAvatar(
                                        id: g.players[i].id,
                                        name: g.players[i].name,
                                        color: _playerColor(g, i),
                                        size: i == g.current ? av * 1.2 : av),
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(
                            height: h * 0.26,
                            child: active
                                ? FittedBox(
                                    child: Text(g.currentPlayer.name,
                                        style: Tv.title(18)),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
          ],
        ),
      );
    });
  }
}

/// Marques du Cricket : / (1), X (2), X entouré (3, fermé).
class MarkPainter extends CustomPainter {
  final int marks;
  final Color color;

  /// Épaisseur du trait (part de la taille).
  final double weight;
  MarkPainter(this.marks, this.color, {this.weight = 0.12});

  @override
  void paint(Canvas canvas, Size size) {
    if (marks <= 0) return;
    final w = size.width;
    final p = Paint()
      ..color = color
      ..strokeWidth = math.max(2, w * weight)
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
    final medals = {
      1: Tv.gold,
      2: const Color(0xFFC0C4CC),
      3: const Color(0xFFCD7F32)
    };
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
                id: g.players[side].id,
                name: g.players[side].name,
                color: sideColor(g, side),
                size: 34)
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
