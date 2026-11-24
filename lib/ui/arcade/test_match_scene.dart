// Test Match : terrain de cricket vu de dessus (pelouse tondue, pitch,
// guichets) et tableau d'affichage à l'ancienne ; frappe (balle qui part
// vers la limite), guichet (piquets qui volent), jauge de la visite (40).

import 'dart:math';

import 'package:flutter/material.dart';

import '../../game/practice.dart';
import '../theme.dart';
import 'common.dart';

class TestMatchScene extends StatefulWidget {
  final PracticeGame game;
  final Color Function(int) colorOf;
  const TestMatchScene({super.key, required this.game, required this.colorOf});
  @override
  State<TestMatchScene> createState() => _TestMatchSceneState();
}

class _TestMatchSceneState extends State<TestMatchScene>
    with TickerProviderStateMixin, ArcadeEvents, AmbientTicker {
  @override
  PracticeGame get game => widget.game;
  final _pops = GlobalKey<PopLayerState>();
  late final AnimationController _shot = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100));
  late final AnimationController _wicket = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1300));
  double _dir = 0, _power = 0.5;

  static const _cream = Color(0xFFF3E9C6);
  static const _board = Color(0xFF123824);

  @override
  void initState() {
    super.initState();
    startAmbient();
  }

  @override
  void onEvent(Map<String, dynamic> e) {
    switch (e['type']) {
      case 'bat':
        final v = e['v'] as int;
        if (v <= 0) return;
        _dir = Random().nextDouble() * 2 * pi;
        _power = (v / 60).clamp(0.25, 1.0);
        _shot.forward(from: 0);
      case 'wicket':
        _wicket.forward(from: 0);
        _pops.currentState?.add(Pop(e['w'] == 2 ? 'DOUBLE GUICHET !' : 'OUT !',
            const Color(0xFFFF5A4A), const Offset(0.3, 0.3),
            size: 44));
      case 'runs':
        final r = e['runs'] as int;
        _pops.currentState?.add(Pop(
            r > 0 ? '+$r COURSES' : 'PAS DE COURSE',
            r > 0 ? const Color(0xFF7CFF8A) : Colors.white70,
            const Offset(0.3, 0.3),
            size: 36));
      case 'innings':
        _pops.currentState?.add(Pop(
            'CIBLE : ${e['target']}', _cream, const Offset(0.3, 0.45),
            size: 40));
    }
  }

  @override
  void dispose() {
    _shot.dispose();
    _wicket.dispose();
    stopAmbient();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    checkEvent();
    final g = game;
    final (inn, bat, w, vis) = testMatchState(g);
    final wickets = g.settings.goalOrDefault;
    final visit = g.current == bat && !g.finished ? g.currentTurn.points : 0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(children: [
        Row(children: [
          Expanded(
            flex: 11,
            child: AnimatedBuilder(
              animation: Listenable.merge([_shot, _wicket, ambient]),
              builder: (context, _) => CustomPaint(
                painter: _GroundPainter(
                  shot: _shot.isAnimating ? _shot.value : 0,
                  dir: _dir,
                  power: _power,
                  wicket: _wicket.isAnimating ? _wicket.value : 0,
                  batColor: widget.colorOf(bat),
                  bowlColor: widget.colorOf(1 - bat),
                  t: ambient.value,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          Expanded(
            flex: 8,
            child: Container(
              margin: const EdgeInsets.all(6),
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: BoxDecoration(
                color: _board,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF6B5A2E), width: 4),
                boxShadow: const [
                  BoxShadow(color: Colors.black54, blurRadius: 10)
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('MANCHE $inn / 2',
                      textAlign: TextAlign.center,
                      style: Tv.title(16, color: _cream)),
                  const Divider(color: Color(0x66F3E9C6), height: 8),
                  for (var i = 0; i < 2; i++)
                    Expanded(
                      flex: 3,
                      child: Row(children: [
                        Container(width: 6, color: widget.colorOf(i)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(g.players[i].name.toUpperCase(),
                                    style: Tv.title(16, color: _cream)),
                              ),
                              Text(i == bat ? 'AU BÂTON' : 'AU LANCER',
                                  style: Tv.label(10,
                                      color: i == bat
                                          ? const Color(0xFFFFD34F)
                                          : Colors.white60)),
                            ],
                          ),
                        ),
                        Text('${g.stateOf(i).score}',
                            style: Tv.title(34, color: _cream).copyWith(
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ])),
                      ]),
                    ),
                  const Divider(color: Color(0x66F3E9C6), height: 8),
                  Expanded(
                    flex: 2,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _Stat('GUICHETS', '$w/$wickets'),
                        _Stat('VISITES', '$vis/8'),
                      ],
                    ),
                  ),
                  Text('VISITE : $visit', style: Tv.title(14, color: _cream)),
                  const SizedBox(height: 4),
                  _VisitMeter(value: visit),
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

class _Stat extends StatelessWidget {
  final String label, value;
  const _Stat(this.label, this.value);
  @override
  Widget build(BuildContext context) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: Tv.label(10, color: Colors.white60)),
          Text(value, style: Tv.title(22, color: const Color(0xFFF3E9C6))),
        ],
      );
}

/// Jauge de la visite : seuls les points au-delà de 40 sont des courses.
class _VisitMeter extends StatelessWidget {
  final int value;
  const _VisitMeter({required this.value});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 18,
      child: LayoutBuilder(builder: (context, c) {
        const max = 120.0;
        final x40 = c.maxWidth * 40 / max;
        return Stack(children: [
          Container(
              decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(9))),
          TweenAnimationBuilder<double>(
            tween: Tween(end: (value / max).clamp(0, 1)),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Container(
              width: c.maxWidth * v,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  const Color(0xFFB7A36A),
                  value > 40
                      ? const Color(0xFF7CFF8A)
                      : const Color(0xFFE0CF8A),
                ]),
                borderRadius: BorderRadius.circular(9),
              ),
            ),
          ),
          Positioned(
              left: x40 - 1,
              top: 0,
              bottom: 0,
              child: Container(width: 3, color: Colors.white)),
          Positioned(
              left: x40 + 4,
              top: 0,
              bottom: 0,
              child: Center(
                  child: Text('40', style: Tv.label(10, color: Colors.white)))),
        ]);
      }),
    );
  }
}

class _GroundPainter extends CustomPainter {
  final double shot, dir, power, wicket, t;
  final Color batColor, bowlColor;
  _GroundPainter(
      {required this.shot,
      required this.dir,
      required this.power,
      required this.wicket,
      required this.batColor,
      required this.bowlColor,
      required this.t});

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF1B3D1A));
    final o = Offset(w / 2, h / 2);
    final field = Rect.fromCenter(center: o, width: w * 0.94, height: h * 0.92);
    // pelouse tondue en bandes
    c.save();
    c.clipPath(Path()..addOval(field));
    for (var i = 0; i < 14; i++) {
      c.drawRect(
          Rect.fromLTWH(field.left + i * field.width / 14, field.top,
              field.width / 14 + 1, field.height),
          Paint()
            ..color =
                i.isEven ? const Color(0xFF4C9A3F) : const Color(0xFF44903A));
    }
    c.restore();
    // corde de la limite
    c.drawOval(
        field.deflate(4),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Colors.white70);
    // cercle des 30 yards
    c.drawOval(
        Rect.fromCenter(
            center: o, width: field.width * 0.55, height: field.height * 0.55),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Colors.white30);
    // pitch
    final pitch = Rect.fromCenter(center: o, width: w * 0.08, height: h * 0.5);
    c.drawRect(pitch, Paint()..color = const Color(0xFFCDB57E));
    for (final y in [
      pitch.top + pitch.height * 0.12,
      pitch.bottom - pitch.height * 0.12
    ]) {
      c.drawLine(
          Offset(pitch.left - 6, y),
          Offset(pitch.right + 6, y),
          Paint()
            ..color = Colors.white
            ..strokeWidth = 2);
    }
    // guichets (piquets) : celui du batteur en bas
    void stumps(double y, bool hit) {
      for (var k = -1; k <= 1; k++) {
        var p = Offset(o.dx + k * 5, y);
        if (hit && wicket > 0) {
          final f = Curves.easeOut.transform(wicket);
          p += Offset(k * 40 * f, -60 * f + 80 * f * f);
          c.save();
          c.translate(p.dx, p.dy);
          c.rotate(k * 3 * f + 0.5 * f);
          c.drawRect(const Rect.fromLTWH(-2, -8, 4, 16),
              Paint()..color = const Color(0xFFF2E6C8));
          c.restore();
        } else {
          c.drawCircle(p, 3, Paint()..color = const Color(0xFFF2E6C8));
        }
      }
    }

    stumps(pitch.top + pitch.height * 0.08, false);
    stumps(pitch.bottom - pitch.height * 0.08, true);
    // joueurs : batteur en bas, lanceur en haut
    final batter = Offset(o.dx + 14, pitch.bottom - pitch.height * 0.16);
    final bowler = Offset(
        o.dx - 12, pitch.top + pitch.height * 0.02 + sin(t * 2 * pi * 4) * 2);
    for (final (p, col) in [(batter, batColor), (bowler, bowlColor)]) {
      c.drawCircle(p + const Offset(2, 3), 9, Paint()..color = Colors.black38);
      c.drawCircle(p, 9, Paint()..color = col);
      c.drawCircle(p, 4, Paint()..color = const Color(0xFFF2D3B0));
    }
    // batte
    c.drawLine(
        batter + const Offset(-6, -2),
        batter + const Offset(-20, -14),
        Paint()
          ..color = const Color(0xFFE6C98F)
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round);
    // balle frappée vers la limite
    if (shot > 0) {
      final f = Curves.easeOutCubic.transform(shot);
      final reach = Offset(
              cos(dir) * field.width * 0.45, sin(dir) * field.height * 0.45) *
          power;
      final p = batter + reach * f;
      final lift = sin(f * pi) * 26 * power;
      for (var k = 1; k <= 5; k++) {
        final ff = max(0.0, f - k * 0.03);
        c.drawCircle(
            batter + reach * ff - Offset(0, sin(ff * pi) * 26 * power),
            3.5 - k * 0.5,
            Paint()..color = Colors.white.withValues(alpha: 0.4 - k * 0.07));
      }
      c.drawCircle(p + const Offset(3, 4), 4, Paint()..color = Colors.black26);
      c.drawCircle(
          p - Offset(0, lift), 5, Paint()..color = const Color(0xFFC62828));
    }
  }

  @override
  bool shouldRepaint(_GroundPainter o) => true;
}
