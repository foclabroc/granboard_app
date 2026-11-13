import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio.dart';
import '../game/cricket.dart';
import '../players.dart';
import 'dartboard.dart';
import 'game_fx.dart';
import 'game_page.dart' show GamePage;
import 'setup_page.dart' show kTeamColors, kTeamNames;
import 'theme.dart';
import 'widgets.dart';
import '../format.dart';

/// Mise en page du Cricket : `classic` (numéros au centre, façon GranBoard)
/// ou `columns` (numéros en haut, une ligne par joueur, celle du joueur en
/// cours en surbrillance et plus grande ; jusqu'à 10 joueurs). Choisie sur le
/// téléphone, envoyée à la TV (`cricket` dans l'état).
class CricketStyle {
  static const classic = 'classic';
  static const columns = 'columns';
  static const _pref = 'cricket_layout';
  static final current = ValueNotifier<String>(classic);

  static String fix(Object? v) => v == columns ? columns : classic;

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      current.value = fix(p.getString(_pref));
    } catch (_) {}
  }

  static Future<void> choose(String v) async {
    current.value = fix(v);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_pref, current.value);
    } catch (_) {}
  }

  static Future<void> toggle() =>
      choose(current.value == columns ? classic : columns);
}

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
        ValueListenableBuilder<String>(
          valueListenable: CricketStyle.current,
          builder: (context, style, _) => LayoutBuilder(builder: (context, c) {
            final barH = (c.maxHeight * 0.2).clamp(52.0, 96.0);
            final sideW = (c.maxWidth * 0.17).clamp(110.0, 220.0);
            final phone = widget.actionBar != null;
            if (style == CricketStyle.columns) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _ColumnsArena(game: game, canSwitch: phone)),
                  SizedBox(
                      width: sideW,
                      child: _RightPanel(
                          game: game,
                          actionBar: widget.actionBar,
                          status: true)),
                ],
              );
            }
            return Column(
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                          width: sideW,
                          child: _History(game: game, canSwitch: phone)),
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
        ),
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

/// Message d'état de la partie (fin, spoiler, cibles cachées…) et sa
/// couleur ; texte vide = rien à dire.
(String, Color) _statusOf(CricketGame g) {
  final side = g.sideOf(g.current);
  final v = g.variant;
  if (g.finished) {
    final names = g.winners.map((i) => g.players[i].name).join(', ');
    return (
      '🏆 $names ${g.winners.length > 1 ? 'gagnent' : 'gagne'} !',
      Tv.goldLight
    );
  }
  if (g.turnOver) return ('Retire tes fléchettes\npuis « Suivant »', Tv.muted);
  if (g.isSpoiler(side)) return ('SPOILER :\nne peut plus gagner', Tv.red);
  if (g.allClosed(side) && v.scoring) {
    return (
      v.cutThroat
          ? 'Tout fermé : il faut\nle moins de points'
          : 'Tout fermé : marque\npour passer devant',
      Tv.goldLight
    );
  }
  if (v.hidden) {
    final left = g.targets.where((x) => !x.revealed).length;
    if (left > 0) {
      return (
        '$left cible${left > 1 ? 's' : ''} cachée${left > 1 ? 's' : ''}',
        Tv.ice
      );
    }
  }
  return ('', Tv.muted);
}

/// Texte d'un numéro du tableau.
String _targetLabel(CricketGame g, int t) => !g.targets[t].revealed
    ? '?'
    : g.variant == CricketVariant.tripleOnly
        ? 'T${g.targets[t].number}'
        : g.targets[t].number == 25
            ? 'B'
            : g.targets[t].label;

/// Petit bouton qui change la mise en page (téléphone seulement).
class _StyleButton extends StatelessWidget {
  const _StyleButton();

  @override
  Widget build(BuildContext context) => InkWell(
        key: const ValueKey('cricket-style'),
        borderRadius: BorderRadius.circular(8),
        onTap: CricketStyle.toggle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: Tv.panel2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Tv.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.view_week_rounded, size: 16, color: Tv.gold),
              const SizedBox(width: 4),
              Text('VUE', style: Tv.title(12, color: Tv.gold)),
            ],
          ),
        ),
      );
}

/// Mise en page « lignes » : numéros en haut, puis une ligne par joueur (ou
/// équipe) : avatar + nom + MPR, marques, points. La ligne du joueur en
/// cours est en surbrillance et un peu plus grande que les autres.
class _ColumnsArena extends StatelessWidget {
  final CricketGame game;
  final bool canSwitch;
  const _ColumnsArena({required this.game, required this.canSwitch});

  @override
  Widget build(BuildContext context) {
    final g = game;
    final sides = g.sides;
    final cur = g.sideOf(g.current);
    return LayoutBuilder(builder: (context, c) {
      const pad = 6.0;
      const gap = 4.0;
      const grow = 1.3; // hauteur de la ligne en cours
      const inset = 8.0; // les autres lignes sont un peu moins larges
      final n = sides.length;
      final w = c.maxWidth - pad * 2;
      final h = c.maxHeight - pad * 2;
      final headH = (h * (n > 6 ? 0.09 : 0.13)).clamp(22.0, 46.0);
      final unit = (h - headH - gap * (n + 1) - 1) / (n - 1 + grow);
      // Lignes pas trop hautes à 2 ou 3 joueurs
      final rowH = math.min(unit, h * 0.26);
      final nameW = (w * 0.24).clamp(90.0, 210.0);
      final scoreW = (w * 0.13).clamp(46.0, 110.0);
      final targets = g.targets.length;

      Widget marks(int s, double height, Color color, bool active) => Row(
            children: [
              for (var t = 0; t < targets; t++)
                Expanded(
                  child: Center(
                    child: LayoutBuilder(
                      builder: (context, box) => SizedBox.square(
                        // Petites lignes (beaucoup de joueurs) : marques
                        // presque à pleine hauteur
                        dimension: math.min(box.maxWidth, height) *
                            (height < 30 ? 0.92 : (active ? 0.72 : 0.62)),
                        child: CustomPaint(
                          painter: MarkPainter(
                              g.marksOf(s, t), g.dead(t) ? Tv.muted : color),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );

      Widget row(int s) {
        final color = sideColor(g, s);
        final active = s == cur && !g.finished;
        final won = g.winners.any((i) => g.sideOf(i) == s);
        final rh = active ? rowH * grow : rowH;
        final members = g.membersOf(s);
        final score =
            g.variant.scoring ? '${g.scoreOf(s)}' : '${g.closedMarks(s)}';
        final av = math.min(rh * 0.74, (nameW * 0.45) / members.length);
        final mpr =
            g.settings.teams ? null : g.statsOf(members.first).mpr.fr(1);
        final name = (g.settings.teams && members.contains(g.current)
                ? g.currentPlayer.name
                : sideName(g, s))
            .toUpperCase();
        return Container(
          key: ValueKey('cricket-row-$s'),
          height: rh,
          margin: EdgeInsets.only(
              bottom: gap, left: active ? 0 : inset, right: active ? 0 : inset),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(colors: [
              color.withValues(alpha: active ? 0.38 : 0.1),
              Colors.black.withValues(alpha: 0.4),
            ], stops: const [
              0,
              0.5
            ]),
            border: Border.all(
                color: active ? color : Tv.line, width: active ? 2 : 1),
          ),
          child: Opacity(
            opacity: active || g.finished ? 1 : 0.82,
            child: Row(
              children: [
                SizedBox(
                  width: nameW - (active ? 0 : inset),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Row(
                      children: [
                        for (final i in members)
                          Padding(
                            padding: const EdgeInsets.only(right: 2),
                            child: PlayerAvatar(
                                id: g.players[i].id,
                                name: g.players[i].name,
                                color: _playerColor(g, i),
                                size: av.clamp(12.0, 64.0)),
                          ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(name,
                                    maxLines: 1,
                                    style: Tv.title(active ? 24 : 20,
                                        color:
                                            active ? Colors.white : Tv.text)),
                                if (rh >= 30)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      for (final i in members) ...[
                                        RankChip(g.players[i].id, size: 12),
                                        const SizedBox(width: 4),
                                      ],
                                      if (mpr != null && rh >= 34)
                                        Text('MPR $mpr',
                                            style:
                                                Tv.label(13, color: Tv.muted)),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(child: marks(s, rh, color, active)),
                SizedBox(
                  width: scoreW - (active ? 0 : inset),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(won ? '🏆 $score' : score,
                            style: Tv.title(
                                rh * (rh < 30 ? 0.85 : (active ? 0.62 : 0.56)),
                                color: g.isSpoiler(s)
                                    ? Tv.red
                                    : active
                                        ? Colors.white
                                        : Tv.goldLight)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      Widget header() => SizedBox(
            height: headH,
            child: Row(
              children: [
                SizedBox(
                  width: nameW,
                  child: canSwitch
                      ? const Align(
                          alignment: Alignment.centerLeft,
                          child: FittedBox(
                              fit: BoxFit.scaleDown, child: _StyleButton()))
                      : null,
                ),
                for (var t = 0; t < targets; t++)
                  Expanded(
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Text(
                              _targetLabel(g, t) == 'B'
                                  ? 'BULL'
                                  : _targetLabel(g, t),
                              style: Tv.title(headH * 0.8,
                                      color: g.dead(t)
                                          ? Tv.muted
                                          : !g.targets[t].revealed
                                              ? Tv.ice
                                              : Tv.gold)
                                  .copyWith(
                                      decoration: g.dead(t)
                                          ? TextDecoration.lineThrough
                                          : null,
                                      decorationColor: Tv.muted)),
                        ),
                      ),
                    ),
                  ),
                SizedBox(
                  width: scoreW,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(g.variant.scoring ? 'POINTS' : 'MARQUES',
                          style: Tv.label(13, color: Tv.muted)),
                    ),
                  ),
                ),
              ],
            ),
          );

      return Padding(
        padding: const EdgeInsets.all(pad),
        child: Center(
          child: SizedBox(
            width: w,
            child: Stack(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    header(),
                    const SizedBox(height: gap),
                    for (final s in sides) row(s),
                  ],
                ),
                // Traits fins entre les numéros, du haut jusqu'en bas
                Positioned.fill(
                  bottom: gap,
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _TargetLines(
                          left: nameW, right: scoreW, count: targets),
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

/// Traits verticaux très fins qui séparent les numéros (vue en lignes).
class _TargetLines extends CustomPainter {
  final double left;
  final double right;
  final int count;
  _TargetLines({required this.left, required this.right, required this.count});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..strokeWidth = 1;
    final cell = (size.width - left - right) / count;
    for (var k = 1; k < count; k++) {
      final x = (left + cell * k).roundToDouble() + 0.5;
      canvas.drawLine(Offset(x, 4), Offset(x, size.height - 2), p);
    }
  }

  @override
  bool shouldRepaint(_TargetLines old) =>
      old.left != left || old.right != right || old.count != count;
}

/// Gauche : statut + manches du joueur en cours (R1 / / /, R2 Ⓧ Ⓧ…).
class _History extends StatelessWidget {
  final CricketGame game;
  final bool canSwitch;
  const _History({required this.game, this.canSwitch = false});

  @override
  Widget build(BuildContext context) {
    final g = game;
    final (status, statusColor) = _statusOf(g);
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
                      alignment: Alignment.centerLeft,
                      // Colonne étroite (petit téléphone) : la ligne rétrécit
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
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
                                            style:
                                                Tv.title(14, color: Tv.muted)))
                                    : CustomPaint(
                                        painter: MarkPainter(
                                            _dartMarks(d), Colors.white)),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            }),
          ),
          if (canSwitch) const _StyleButton(),
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
                            _targetLabel(g, t),
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

  /// Affiche aussi le message d'état (vue colonnes : pas d'historique).
  final bool status;
  const _RightPanel({required this.game, this.actionBar, this.status = false});

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
                  Text(mpr.fr(2), style: Tv.title(28)),
                ],
              ),
            ),
          ),
          if (status && _statusOf(g).$1.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text(_statusOf(g).$1,
                  maxLines: 2,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: Tv.title(12, color: _statusOf(g).$2)),
            ),
          const SizedBox(height: 4),
          // Petite cible (numéros fermés allumés, à fermer qui clignotent)
          // puis les 3 fléchettes, qui gardent au moins la moitié de la place
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                final board =
                    math.min(math.min(c.maxWidth, c.maxHeight * 0.5), 160.0);
                return Column(
                  children: [
                    if (board >= 60)
                      _MiniBoard(game: g, size: board.toDouble()),
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
                  ],
                );
              },
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

/// Cible du panneau de droite (Cricket) : fléchettes du tour, numéros
/// fermés par le joueur allumés à sa couleur, numéros à fermer qui
/// clignotent.
class _MiniBoard extends StatelessWidget {
  final CricketGame game;
  final double size;
  const _MiniBoard({required this.game, required this.size});

  @override
  Widget build(BuildContext context) {
    final g = game;
    final side = g.sideOf(g.current);
    final lit = <int>{}, aim = <int>{};
    for (var t = 0; t < g.targets.length; t++) {
      final tg = g.targets[t];
      final n = tg.number;
      if (!tg.revealed || n < 1 || n > 20) continue;
      if (g.closedBy(side, t)) {
        lit.add(n);
      } else if (!g.dead(t)) {
        aim.add(n);
      }
    }
    final color = PlayerStore.instance.colorOf(g.currentPlayer.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: AnimatedDartboard(
        key: const ValueKey('cricket-board'),
        size: size,
        hits: [
          for (final d in g.currentTurn.darts)
            if (d.hit != null) d.hit!
        ],
        litNumbers: lit,
        aimNumbers: aim,
        dartColor: color,
        skin: PlayerBoards.instance.of(g.currentPlayer.id),
        win: g.finished,
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
                            child: FittedBox(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (active) ...[
                                    Text(g.currentPlayer.name,
                                        style: Tv.title(18)),
                                    const SizedBox(width: 6),
                                  ],
                                  RankChip(
                                      active
                                          ? g.currentPlayer.id
                                          : g.players[g.membersOf(s).first].id,
                                      size: 14),
                                ],
                              ),
                            ),
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
            ? 'LIMITE DE ${plural(g.settings.roundLimit!, 'MANCHE')}'
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
                stat('MPR', s.mpr.fr(2)),
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
