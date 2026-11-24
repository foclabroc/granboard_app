// Puissance 4 : grille bleue percée, pions qui tombent derrière la façade
// avec rebond, colonnes et leurs numéros, alignement gagnant qui brille.

import 'dart:math';

import 'package:flutter/material.dart';

import '../../game/practice.dart';
import 'common.dart';

class Connect4Scene extends StatefulWidget {
  final PracticeGame game;
  final Color Function(int) colorOf;
  const Connect4Scene({super.key, required this.game, required this.colorOf});
  @override
  State<Connect4Scene> createState() => _Connect4SceneState();
}

class _Connect4SceneState extends State<Connect4Scene>
    with TickerProviderStateMixin, ArcadeEvents, AmbientTicker {
  @override
  PracticeGame get game => widget.game;
  late final AnimationController _drop = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 750));
  int? _col, _row;

  @override
  void initState() {
    super.initState();
    startAmbient();
  }

  @override
  void onEvent(Map<String, dynamic> e) {
    if (e['type'] != 'drop') return;
    _col = e['col'] as int;
    _row = e['row'] as int;
    _drop.forward(from: 0);
  }

  @override
  void dispose() {
    _drop.dispose();
    stopAmbient();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    checkEvent();
    final g = game;
    final (cells, line) = connect4State(g);
    // colonnes visées par la fléchette en cours
    final hot = <int>{
      for (final d in g.currentTurn.darts)
        if (d.hit != null) connect4Column(d.hit!.isBull ? 25 : d.hit!.number)
    };
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: Listenable.merge([_drop, ambient]),
            builder: (context, _) => CustomPaint(
              painter: _C4Painter(
                cells: cells,
                line: line,
                colors: [
                  widget.colorOf(0),
                  widget.colorOf(min(1, g.players.length - 1))
                ],
                dropCol: _drop.isAnimating ? _col : null,
                dropRow: _row,
                drop: _drop.value,
                hot: hot,
                t: ambient.value,
              ),
            ),
          ),
        ),
        Positioned(
            left: 6,
            right: 6,
            bottom: 6,
            child: ScoreStrip(game: g, colorOf: widget.colorOf)),
      ]),
    );
  }
}

class _C4Painter extends CustomPainter {
  final List<int> cells;
  final List<int>? line;
  final List<Color> colors;
  final int? dropCol, dropRow;
  final double drop, t;
  final Set<int> hot;
  _C4Painter(
      {required this.cells,
      required this.line,
      required this.colors,
      required this.dropCol,
      required this.dropRow,
      required this.drop,
      required this.hot,
      required this.t});

  @override
  void paint(Canvas c, Size s) {
    const cols = 7, rows = 6;
    c.drawRect(
        Offset.zero & s,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(0, -0.6),
            radius: 1.2,
            colors: [Color(0xFF1A2350), Color(0xFF060813)],
          ).createShader(Offset.zero & s));
    const head = 24.0, foot = 44.0;
    final cell =
        min((s.width - 24) / cols, (s.height - head - foot - 10) / rows);
    final bw = cell * cols, bh = cell * rows;
    final ox = (s.width - bw) / 2, oy = head + 6;
    final r = cell * 0.38;
    Offset at(int row, int col) =>
        Offset(ox + col * cell + cell / 2, oy + row * cell + cell / 2);
    // étiquettes des colonnes
    for (var k = 0; k < cols; k++) {
      final nums =
          connect4Numbers(k).map((n) => n == 25 ? 'B' : '$n').join('·');
      final on = hot.contains(k);
      paintText(c, nums, Offset(ox + k * cell + cell / 2, head / 2 + 2),
          min(14, cell * 0.22), on ? const Color(0xFFFFD34F) : Colors.white70,
          weight: on ? FontWeight.w900 : FontWeight.w700);
    }
    // pions posés (derrière la façade)
    for (var i = 0; i < cells.length; i++) {
      final p = cells[i];
      if (p < 0) continue;
      final row = i ~/ cols, col = i % cols;
      if (dropCol == col && dropRow == row) continue;
      paintBall(c, at(row, col), r, colors[p], shadow: false);
      c.drawCircle(
          at(row, col),
          r * 0.62,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.12
            ..color = Colors.black.withValues(alpha: 0.18));
    }
    // pion qui tombe
    if (dropCol != null && dropRow != null) {
      final i = dropRow! * cols + dropCol!;
      final p = cells[i];
      if (p >= 0) {
        final end = at(dropRow!, dropCol!);
        final start = Offset(end.dx, oy - cell * 0.6);
        final y =
            start.dy + (end.dy - start.dy) * Curves.bounceOut.transform(drop);
        paintBall(c, Offset(end.dx, y), r, colors[p], shadow: false);
      }
    }
    // façade percée
    final board = Path()
      ..fillType = PathFillType.evenOdd
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(ox - 8, oy - 6, bw + 16, bh + 12),
          const Radius.circular(14)));
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        board.addOval(Rect.fromCircle(center: at(row, col), radius: r * 1.04));
      }
    }
    c.drawPath(
        board.shift(const Offset(0, 6)),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    c.drawPath(
        board,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3D6BFF), Color(0xFF1E3FD0), Color(0xFF142A96)],
          ).createShader(Rect.fromLTWH(ox, oy, bw, bh)));
    // biseau des trous
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        c.drawCircle(
            at(row, col),
            r * 1.04,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..shader = LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.black.withValues(alpha: 0.45),
                  Colors.white.withValues(alpha: 0.25)
                ],
              ).createShader(Rect.fromCircle(center: at(row, col), radius: r)));
      }
    }
    // colonnes touchées ce tour
    for (final k in hot) {
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(ox + k * cell + 2, oy - 4, cell - 4, bh + 8),
              const Radius.circular(10)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = const Color(0xFFFFD34F).withValues(alpha: 0.85));
    }
    // alignement gagnant
    final l = line;
    if (l != null && l.length == 4) {
      final a = at(l.first ~/ cols, l.first % cols),
          b = at(l.last ~/ cols, l.last % cols);
      final glow = 0.6 + 0.4 * sin(t * 2 * pi * 6);
      c.drawLine(
          a,
          b,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.85 * glow)
            ..strokeWidth = r * 0.5
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 8));
      for (final i in l) {
        c.drawCircle(
            at(i ~/ cols, i % cols),
            r * 1.08,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4
              ..color = Colors.white.withValues(alpha: glow));
      }
    }
  }

  @override
  bool shouldRepaint(_C4Painter o) => true;
}
