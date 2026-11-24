// Serpents et échelles : plateau 10 × 10, échelles en bois, serpents
// tachetés ; les pions sautent case par case puis montent ou glissent.

import 'dart:math';

import 'package:flutter/material.dart';

import '../../game/practice.dart';
import '../theme.dart';
import '../widgets.dart';
import 'common.dart';

class SnakesScene extends StatefulWidget {
  final PracticeGame game;
  final Color Function(int) colorOf;
  const SnakesScene({super.key, required this.game, required this.colorOf});
  @override
  State<SnakesScene> createState() => _SnakesSceneState();
}

class _SnakesSceneState extends State<SnakesScene>
    with TickerProviderStateMixin, ArcadeEvents, AmbientTicker {
  @override
  PracticeGame get game => widget.game;
  final _pops = GlobalKey<PopLayerState>();
  late final AnimationController _move = AnimationController(vsync: this);
  int? _who;
  int _from = 0, _land = 0, _to = 0, _m = 0;

  @override
  void initState() {
    super.initState();
    startAmbient();
  }

  @override
  void onEvent(Map<String, dynamic> e) {
    if (e['type'] != 'move') return;
    _who = e['p'] as int;
    _from = e['from'] as int;
    _land = e['land'] as int;
    _to = e['to'] as int;
    _m = e['m'] as int? ?? (_land - _from).abs();
    final hops = _m;
    _move.duration = Duration(
        milliseconds: 170 * max(1, hops).toInt() + (_to != _land ? 900 : 0));
    _move.forward(from: 0);
    if (e['via'] == 'ladder') {
      Future.delayed(Duration(milliseconds: 170 * hops), () {
        if (mounted) {
          _pops.currentState?.add(Pop(
              'ÉCHELLE !', const Color(0xFFFFD34F), const Offset(0.36, 0.4)));
        }
      });
    } else if (e['via'] == 'snake') {
      Future.delayed(Duration(milliseconds: 170 * hops), () {
        if (mounted) {
          _pops.currentState?.add(Pop(
              'SERPENT !', const Color(0xFFFF5A4A), const Offset(0.36, 0.4)));
        }
      });
    }
  }

  @override
  void dispose() {
    _move.dispose();
    stopAmbient();
    super.dispose();
  }

  /// Case affichée du pion animé (fraction possible : glissade).
  (double, bool) _shown(int p) {
    final real = game.stateOf(p).score.toDouble();
    if (p != _who || !_move.isAnimating) return (real, false);
    final hops = _m;
    final total = _move.duration!.inMilliseconds.toDouble();
    final hopMs = 170.0 * max(1, hops);
    final ms = _move.value * total;
    if (ms < hopMs) {
      final k = ms / hopMs * hops;
      // rebond au-delà de 100
      var target = _from + k;
      if (target > 100) target = 200 - target;
      return (target, true);
    }
    final u = ((ms - hopMs) / max(1, total - hopMs)).clamp(0.0, 1.0);
    return (_land + (_to - _land) * Curves.easeInOut.transform(u), false);
  }

  @override
  Widget build(BuildContext context) {
    checkEvent();
    final g = game;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(children: [
        Positioned.fill(
          child: Container(color: const Color(0xFF0B1A10)),
        ),
        Row(children: [
          AspectRatio(
            aspectRatio: 1,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: AnimatedBuilder(
                animation: Listenable.merge([_move, ambient]),
                builder: (context, _) => CustomPaint(
                  painter: _BoardPainter(
                    pawns: [
                      for (var i = 0; i < g.players.length; i++)
                        (
                          _shown(i).$1,
                          _shown(i).$2,
                          widget.colorOf(i),
                          i == g.current && !g.finished
                        )
                    ],
                    t: ambient.value,
                    hop: _move.isAnimating ? _move.value : 0,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(2, 8, 8, 8),
              child: Column(
                children: [
                  for (var i = 0; i < g.players.length; i++)
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            widget
                                .colorOf(i)
                                .withValues(alpha: i == g.current ? 0.6 : 0.25),
                            Colors.black45
                          ]),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: i == g.current && !g.finished
                                  ? Colors.white
                                  : Colors.transparent),
                        ),
                        child: Row(children: [
                          PlayerAvatar(
                              id: g.players[i].id,
                              name: g.players[i].name,
                              color: widget.colorOf(i),
                              size: 24),
                          const SizedBox(width: 6),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(g.players[i].name.toUpperCase(),
                                  style: Tv.title(16, color: Colors.white)),
                            ),
                          ),
                          Text('${g.stateOf(i).score}',
                              style: Tv.title(24, color: Colors.white)),
                        ]),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text('BULL 6 · 25 5 · S.EXT 4 · T 3 · S.INT 2 · D 1',
                      textAlign: TextAlign.center,
                      style: Tv.label(10, color: Colors.white60)),
                ],
              ),
            ),
          ),
        ]),
        Positioned.fill(child: PopLayer(key: _pops)),
      ]),
    );
  }
}

class _BoardPainter extends CustomPainter {
  final List<(double, bool, Color, bool)> pawns;
  final double t, hop;
  _BoardPainter({required this.pawns, required this.t, required this.hop});

  static Offset cellCenter(double sq, double n) {
    // case 1 en bas à gauche, en serpentin
    final i = (n.clamp(1, 100) - 1);
    final row = (i ~/ 10);
    final inRow = i - row * 10;
    final col = row.isEven ? inRow : 9 - inRow;
    return Offset((col + 0.5) * sq, (9 - row + 0.5) * sq);
  }

  Offset _pos(double sq, double n) {
    if (n <= 0) return Offset(-sq * 0.3, 9.5 * sq);
    final lo = n.floor().clamp(1, 100), hi = n.ceil().clamp(1, 100);
    final f = n - n.floor();
    return Offset.lerp(
        cellCenter(sq, lo.toDouble()), cellCenter(sq, hi.toDouble()), f)!;
  }

  @override
  void paint(Canvas c, Size s) {
    final sq = s.width / 10;
    // cases
    for (var n = 1; n <= 100; n++) {
      final o = cellCenter(sq, n.toDouble());
      final r = Rect.fromCenter(center: o, width: sq, height: sq);
      final row = (n - 1) ~/ 10, col = (n - 1) % 10;
      final even = (row + col).isEven;
      c.drawRect(
          r,
          Paint()
            ..color = even ? const Color(0xFF2E7D4A) : const Color(0xFF256A3E));
      if (n == 100) {
        c.drawRect(
            r, Paint()..color = const Color(0xFFFFD34F).withValues(alpha: 0.6));
      }
      paintText(c, '$n', r.topLeft + Offset(sq * 0.2, sq * 0.18), sq * 0.2,
          Colors.white.withValues(alpha: 0.6));
    }
    c.drawRect(
        Offset.zero & s,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0xFF0E2A18));
    // échelles
    kSnakesLadders.forEach((a, b) {
      final p = cellCenter(sq, a.toDouble()), q = cellCenter(sq, b.toDouble());
      final d = q - p;
      final nrm = Offset(-d.dy, d.dx) / d.distance * sq * 0.16;
      final rail = Paint()
        ..color = const Color(0xFFC8913E)
        ..strokeWidth = sq * 0.08
        ..strokeCap = StrokeCap.round;
      final shadow = Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..strokeWidth = sq * 0.1
        ..strokeCap = StrokeCap.round;
      for (final k in [nrm, -nrm]) {
        c.drawLine(
            p + k + const Offset(2, 3), q + k + const Offset(2, 3), shadow);
      }
      final rungs = (d.distance / (sq * 0.35)).floor();
      for (var i = 1; i < rungs; i++) {
        final m = p + d * (i / rungs);
        c.drawLine(
            m + nrm,
            m - nrm,
            Paint()
              ..color = const Color(0xFFE0B068)
              ..strokeWidth = sq * 0.06);
      }
      for (final k in [nrm, -nrm]) {
        c.drawLine(p + k, q + k, rail);
      }
    });
    // serpents
    var k = 0;
    kSnakesSnakes.forEach((head, tail) {
      final p = cellCenter(sq, head.toDouble()),
          q = cellCenter(sq, tail.toDouble());
      final d = q - p;
      final nrm = Offset(-d.dy, d.dx) / d.distance;
      final wig = sq * 0.9 * (k.isEven ? 1 : -1);
      final path = Path()
        ..moveTo(p.dx, p.dy)
        ..cubicTo(
            p.dx + d.dx * 0.3 + nrm.dx * wig,
            p.dy + d.dy * 0.3 + nrm.dy * wig,
            p.dx + d.dx * 0.7 - nrm.dx * wig,
            p.dy + d.dy * 0.7 - nrm.dy * wig,
            q.dx,
            q.dy);
      final hue = [
        const Color(0xFFE53935),
        const Color(0xFF8E24AA),
        const Color(0xFFFF8F00),
        const Color(0xFF00897B)
      ][k % 4];
      // corps qui s'affine vers la queue
      final metric = path.computeMetrics().first;
      const steps = 40;
      for (var i = steps; i >= 0; i--) {
        final f = i / steps;
        final tan = metric.getTangentForOffset(metric.length * f)!;
        final w = sq * (0.24 - 0.17 * f);
        c.drawCircle(tan.position + const Offset(2, 3), w,
            Paint()..color = Colors.black.withValues(alpha: 0.12));
        c.drawCircle(
            tan.position,
            w,
            Paint()
              ..color = Color.lerp(hue, Colors.black, i.isEven ? 0 : 0.25)!);
        if (i % 4 == 0) {
          c.drawCircle(tan.position, w * 0.45,
              Paint()..color = const Color(0xFFFFE082).withValues(alpha: 0.7));
        }
      }
      // tête
      final h0 = metric.getTangentForOffset(0)!;
      final dir = -h0.vector;
      c.drawOval(Rect.fromCenter(center: p, width: sq * 0.6, height: sq * 0.48),
          Paint()..color = hue);
      final eyeN = Offset(-dir.dy, dir.dx) * sq * 0.12;
      for (final e in [eyeN, -eyeN]) {
        c.drawCircle(
            p + e + dir * sq * 0.08, sq * 0.07, Paint()..color = Colors.white);
        c.drawCircle(
            p + e + dir * sq * 0.1, sq * 0.035, Paint()..color = Colors.black);
      }
      // langue qui sort
      final flick = (sin(t * 2 * pi * 8 + k) > 0.6) ? 1.0 : 0.0;
      if (flick > 0) {
        final tip = p + dir * sq * 0.45;
        c.drawLine(
            p + dir * sq * 0.25,
            tip,
            Paint()
              ..color = const Color(0xFFFF1744)
              ..strokeWidth = 2);
      }
      k++;
    });
    // pions
    final placed = <String, int>{};
    for (var i = 0; i < pawns.length; i++) {
      final (n, hopping, color, current) = pawns[i];
      var o = _pos(sq, n);
      final key = '${n.round()}';
      final dup = placed[key] ?? 0;
      placed[key] = dup + 1;
      o += Offset(
          (dup % 2) * sq * 0.22 - sq * 0.11, (dup ~/ 2) * sq * 0.2 - sq * 0.08);
      if (hopping) o -= Offset(0, sin((n - n.floor()) * pi) * sq * 0.45);
      if (current) {
        c.drawCircle(
            o,
            sq * 0.36,
            Paint()
              ..color = Colors.white
                  .withValues(alpha: 0.4 + 0.3 * sin(t * 2 * pi * 4))
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      }
      paintBall(c, o, sq * 0.24, color, label: '${i + 1}');
    }
  }

  @override
  bool shouldRepaint(_BoardPainter o) => true;
}
