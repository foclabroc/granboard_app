// Tir à la corde : une corde tressée tendue entre deux buts, le nœud
// lumineux glisse vers le camp qui tire ; la corde vibre à chaque coup.

import 'dart:math';

import 'package:flutter/material.dart';

import '../../game/practice.dart';
import '../theme.dart';
import 'common.dart';

class TugScene extends StatefulWidget {
  final PracticeGame game;
  final Color Function(int) colorOf;
  const TugScene({super.key, required this.game, required this.colorOf});
  @override
  State<TugScene> createState() => _TugSceneState();
}

class _TugSceneState extends State<TugScene>
    with TickerProviderStateMixin, ArcadeEvents, AmbientTicker {
  @override
  PracticeGame get game => widget.game;
  final _pops = GlobalKey<PopLayerState>();
  late final AnimationController _jolt = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));
  late final AnimationController _move = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));
  double _from = 0, _to = 0;
  int _side = 0;

  int get _goal => game.settings.goalOrDefault;
  int get _rope => (game.shared['rope'] as int?) ?? 0;

  @override
  void initState() {
    super.initState();
    _from = _to = _rope.toDouble();
    startAmbient();
  }

  @override
  void didUpdateWidget(TugScene old) {
    super.didUpdateWidget(old);
    if (_rope.toDouble() != _to) {
      _from = _pos;
      _to = _rope.toDouble();
      _move.forward(from: 0);
    }
  }

  double get _pos =>
      _from +
      (_to - _from) * Curves.elasticOut.transform(_move.value.clamp(0, 1));

  @override
  void onEvent(Map<String, dynamic> e) {
    if (e['type'] != 'pull') return;
    final p = e['p'] as int;
    _side = p.isEven ? -1 : 1;
    _jolt.forward(from: 0);
    final x = 0.5 + _rope / _goal * 0.38;
    _pops.currentState
        ?.add(Pop('+${e['v']}', widget.colorOf(p), Offset(x, 0.36), size: 40));
  }

  @override
  void dispose() {
    _jolt.dispose();
    _move.dispose();
    stopAmbient();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    checkEvent();
    final g = game;
    final left = widget.colorOf(0);
    final right = widget.colorOf(g.players.length > 1 ? 1 : 0);
    String names(bool even) => [
          for (var i = 0; i < g.players.length; i++)
            if (i.isEven == even) g.players[i].name.toUpperCase()
        ].join(' · ');
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: Listenable.merge([_jolt, _move, ambient]),
            builder: (context, _) => CustomPaint(
              painter: _TugPainter(
                pos: _pos / _goal,
                jolt: _jolt.isAnimating ? _jolt.value : 0,
                side: _side,
                left: left,
                right: right,
                t: ambient.value,
                current: g.finished ? 0 : (g.current.isEven ? -1 : 1),
              ),
            ),
          ),
        ),
        Positioned(
          left: 12,
          top: 10,
          right: 0,
          child: _Team(names(true), left, Alignment.centerLeft),
        ),
        Positioned(
          right: 12,
          top: 10,
          left: 0,
          child: _Team(names(false), right, Alignment.centerRight),
        ),
        Positioned(
          bottom: 10,
          left: 0,
          right: 0,
          child: Center(
            child: Text(
                'ÉCART ${_rope.abs()} / $_goal  ·  ${_rope == 0 ? 'ÉGALITÉ' : _rope < 0 ? 'AVANTAGE GAUCHE' : 'AVANTAGE DROITE'}',
                style: Tv.title(18, color: Colors.white70)),
          ),
        ),
        Positioned.fill(child: PopLayer(key: _pops)),
      ]),
    );
  }
}

class _Team extends StatelessWidget {
  final String names;
  final Color color;
  final Alignment align;
  const _Team(this.names, this.color, this.align);
  @override
  Widget build(BuildContext context) => Align(
        alignment: align,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color, width: 1.5),
          ),
          child: Text(names, style: Tv.title(16, color: color)),
        ),
      );
}

class _TugPainter extends CustomPainter {
  final double pos, jolt, t;
  final int side, current;
  final Color left, right;
  _TugPainter(
      {required this.pos,
      required this.jolt,
      required this.side,
      required this.left,
      required this.right,
      required this.t,
      required this.current});

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height, mid = h * 0.55;
    // fond : arène sombre, halos des camps
    c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF07080D));
    for (final (x, col, me) in [
      (0.0, left, current == -1),
      (w, right, current == 1)
    ]) {
      c.drawRect(
          Offset.zero & s,
          Paint()
            ..shader = RadialGradient(
              center: Alignment(x == 0 ? -1 : 1, 0.1),
              radius: 0.9,
              colors: [
                col.withValues(alpha: me ? 0.45 : 0.25),
                Colors.transparent
              ],
            ).createShader(Offset.zero & s));
    }
    // sol : lignes de perspective
    final floor = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    for (var i = -12; i <= 12; i++) {
      c.drawLine(
          Offset(w / 2 + i * 14, mid + 30), Offset(w / 2 + i * 90, h), floor);
    }
    for (var k = 0; k < 6; k++) {
      final y = mid + 30 + pow(k / 6, 1.6) * (h - mid - 30);
      c.drawLine(Offset(0, y), Offset(w, y), floor);
    }
    final x0 = w * 0.12, x1 = w * 0.88, cx = w / 2;
    // buts
    for (final (x, col) in [(x0, left), (x1, right)]) {
      final r =
          Rect.fromCenter(center: Offset(x, mid), width: 16, height: h * 0.5);
      c.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(8)),
          Paint()
            ..color = col.withValues(alpha: 0.9)
            ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 10));
      paintText(c, 'BUT', Offset(x, mid - h * 0.3), 18, col,
          weight: FontWeight.w900);
    }
    // graduations
    for (var i = -10; i <= 10; i++) {
      final x = cx + (x1 - cx) * i / 10;
      c.drawLine(
          Offset(x, mid + 26),
          Offset(x, mid + (i % 5 == 0 ? 40 : 33)),
          Paint()
            ..color = Colors.white.withValues(alpha: i == 0 ? 0.7 : 0.25)
            ..strokeWidth = i == 0 ? 3 : 1.5);
    }
    // corde tressée qui vibre
    final kx = cx + (x1 - cx) * pos.clamp(-1.0, 1.0);
    final amp = jolt > 0 ? (1 - jolt) * 14 : 0.0;
    final path = Path();
    for (var x = x0; x <= x1; x += 4) {
      final u = (x - x0) / (x1 - x0);
      final wave = sin(u * pi * 6 + jolt * 30) * amp * sin(u * pi) +
          sin(u * pi * 2 + t * 2 * pi * 3) * 1.2;
      final y = mid + wave;
      x == x0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    c.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..color = const Color(0xFFB98A4E)
          ..strokeCap = StrokeCap.round);
    c.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..shader =
              LinearGradient(colors: [left, const Color(0xFFFFE3A0), right])
                  .createShader(Rect.fromLTRB(x0, mid - 10, x1, mid + 10))
          ..blendMode = BlendMode.overlay);
    // torsades
    final tw = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..strokeWidth = 2;
    for (var x = x0 + 6; x < x1; x += 11) {
      final u = (x - x0) / (x1 - x0);
      final y = mid + sin(u * pi * 6 + jolt * 30) * amp * sin(u * pi);
      c.drawLine(Offset(x - 4, y + 6), Offset(x + 4, y - 6), tw);
    }
    // marque du milieu
    c.drawLine(
        Offset(cx, mid - 60),
        Offset(cx, mid - 22),
        Paint()
          ..color = Colors.white54
          ..strokeWidth = 2);
    // nœud lumineux
    final ky = mid + sin(0.5 * pi * 6 + jolt * 30) * amp * 0.2;
    final kc = pos < 0
        ? left
        : pos > 0
            ? right
            : Colors.white;
    c.drawCircle(
        Offset(kx, ky),
        30,
        Paint()
          ..color = kc.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));
    paintBall(c, Offset(kx, ky), 17, Color.lerp(Colors.white, kc, 0.5)!,
        shadow: false);
    // flèche de traction
    if (jolt > 0 && side != 0) {
      final a = (1 - jolt);
      for (var k = 0; k < 3; k++) {
        final x = kx + side * (40 + k * 22 + jolt * 30);
        final p = Path()
          ..moveTo(x, ky - 10)
          ..lineTo(x + side * 12, ky)
          ..lineTo(x, ky + 10);
        c.drawPath(
            p,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4
              ..color = (side < 0 ? left : right)
                  .withValues(alpha: a * (1 - k * 0.25)));
      }
    }
  }

  @override
  bool shouldRepaint(_TugPainter o) => true;
}
