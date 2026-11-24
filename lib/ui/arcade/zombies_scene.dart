// Zombies : cimetière la nuit (lune, brume, tombes), 6 couloirs ; les
// zombies avancent en titubant vers la base, leur cible sur une pancarte ;
// abattu = giclée verte, morsure = la base tremble et rougit.

import 'dart:math';

import 'package:flutter/material.dart';

import '../../game/practice.dart';
import '../theme.dart';
import 'common.dart';

class ZombiesScene extends StatefulWidget {
  final PracticeGame game;
  final Color Function(int) colorOf;
  const ZombiesScene({super.key, required this.game, required this.colorOf});
  @override
  State<ZombiesScene> createState() => _ZombiesSceneState();
}

class _ZombiesSceneState extends State<ZombiesScene>
    with TickerProviderStateMixin, ArcadeEvents, AmbientTicker {
  @override
  PracticeGame get game => widget.game;
  final _pops = GlobalKey<PopLayerState>();
  late final AnimationController _kill = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));
  late final AnimationController _bite = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1000));
  Map<int, Zombie> _last = {};
  Offset? _splat;

  @override
  void initState() {
    super.initState();
    _last = {for (final z in zombiesState(game).$1) z.id: z};
    startAmbient();
  }

  Offset _frac(Zombie z) =>
      Offset((z.lane + 0.5) / kZombieLanes, 0.2 + z.y / kZombieReach * 0.6);

  @override
  void onEvent(Map<String, dynamic> e) {
    switch (e['type']) {
      case 'kill':
        final z = _last[e['id']];
        if (z != null) {
          _splat = _frac(z);
          _kill.forward(from: 0);
          final p = e['p'] as int;
          _pops.currentState?.add(Pop(
              'ABATTU !', widget.colorOf(p), _splat! - const Offset(0, 0.05),
              size: 30));
        }
      case 'bite':
        _bite.forward(from: 0);
        _pops.currentState
            ?.add(Pop('MORSURE !', Tv.red, const Offset(0.5, 0.78), size: 40));
    }
  }

  @override
  void dispose() {
    _kill.dispose();
    _bite.dispose();
    stopAmbient();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    checkEvent();
    final g = game;
    final (horde, hp) = zombiesState(g);
    // les zombies vus avant (pour la giclée de celui qui vient de tomber)
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _last = {for (final z in horde) z.id: z});
    final wave = g.round;
    final waves = g.settings.goalOrDefault;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: LayoutBuilder(builder: (context, c) {
        final zw = c.maxWidth / kZombieLanes * 0.8;
        final zh = c.maxHeight * 0.26;
        return AnimatedBuilder(
          animation: _bite,
          builder: (context, child) => Transform.translate(
              offset:
                  _bite.isAnimating ? shake(_bite.value, amp: 7) : Offset.zero,
              child: child),
          child: Stack(children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: Listenable.merge([ambient, _kill, _bite]),
                builder: (context, _) => CustomPaint(
                  painter: _NightPainter(
                    t: ambient.value,
                    hp: hp,
                    bite: _bite.isAnimating ? _bite.value : 0,
                  ),
                ),
              ),
            ),
            for (final z in horde)
              AnimatedPositioned(
                key: ValueKey('z${z.id}'),
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeInOut,
                left: _frac(z).dx * c.maxWidth - zw / 2,
                top: _frac(z).dy * c.maxHeight - zh * 0.55,
                width: zw,
                height: zh,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 700),
                  builder: (context, appear, child) =>
                      Opacity(opacity: appear, child: child),
                  child: _ZombieView(
                      zombie: z,
                      ambient: ambient,
                      danger: z.y >= kZombieReach - 1),
                ),
              ),
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _kill,
                  builder: (context, _) => CustomPaint(
                    painter: _SplatPainter(
                        _splat, _kill.isAnimating ? _kill.value : 0),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 10,
              child: Text('VAGUE ${min(wave, waves)} / $waves',
                  style: Tv.title(18, color: const Color(0xFFB4FF6A))),
            ),
            Positioned(
              top: 8,
              right: 10,
              child: Text(plural(horde.length, 'ZOMBIE', 'ZOMBIES'),
                  style: Tv.title(18, color: Colors.white70)),
            ),
            Positioned.fill(child: PopLayer(key: _pops)),
          ]),
        );
      }),
    );
  }
}

String plural(int n, String one, String many) => '$n ${n > 1 ? many : one}';

class _ZombieView extends StatelessWidget {
  final Zombie zombie;
  final Animation<double> ambient;
  final bool danger;
  const _ZombieView(
      {required this.zombie, required this.ambient, required this.danger});

  @override
  Widget build(BuildContext context) {
    final z = zombie;
    final plate = switch (z.m) {
      3 => const Color(0xFFFF5A4A),
      2 => const Color(0xFFFFB02E),
      _ => const Color(0xFFB4FF6A),
    };
    return AnimatedBuilder(
      animation: ambient,
      builder: (context, _) {
        final ph = ambient.value * 2 * pi * 10 + z.id * 1.7;
        return Transform.translate(
          offset: Offset(sin(ph) * 2.5, (sin(ph * 2)).abs() * -3),
          child: Transform.rotate(
            angle: sin(ph) * 0.06,
            child: Column(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: danger ? Tv.red : plate, width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: plate.withValues(alpha: 0.5), blurRadius: 8)
                  ],
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(z.label, style: Tv.title(18, color: plate)),
                ),
              ),
              Expanded(
                  child: CustomPaint(
                      painter: _ZombiePainter(ph),
                      child: const SizedBox.expand())),
            ]),
          ),
        );
      },
    );
  }
}

class _ZombiePainter extends CustomPainter {
  final double ph;
  _ZombiePainter(this.ph);
  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    const skin = Color(0xFF7FAF5A);
    const dark = Color(0xFF3E5A2A);
    const cloth = Color(0xFF4A3B5C);
    final cx = w / 2;
    // ombre
    c.drawOval(
        Rect.fromCenter(
            center: Offset(cx, h * 0.97), width: w * 0.6, height: h * 0.08),
        Paint()..color = Colors.black.withValues(alpha: 0.45));
    // jambes
    final leg = Paint()
      ..color = const Color(0xFF2E2A3A)
      ..strokeWidth = w * 0.11
      ..strokeCap = StrokeCap.round;
    c.drawLine(Offset(cx - w * 0.08, h * 0.62),
        Offset(cx - w * 0.12 + sin(ph) * 3, h * 0.94), leg);
    c.drawLine(Offset(cx + w * 0.08, h * 0.62),
        Offset(cx + w * 0.1 - sin(ph) * 3, h * 0.94), leg);
    // corps
    final body = RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx, h * 0.5), width: w * 0.4, height: h * 0.32),
        Radius.circular(w * 0.08));
    c.drawRRect(body, Paint()..color = cloth);
    // déchirures
    c.drawPath(
        Path()
          ..moveTo(body.left, body.bottom)
          ..lineTo(body.left + w * 0.07, body.bottom - h * 0.05)
          ..lineTo(body.left + w * 0.13, body.bottom)
          ..lineTo(body.left + w * 0.2, body.bottom - h * 0.06)
          ..lineTo(body.left + w * 0.28, body.bottom),
        Paint()..color = const Color(0xFF241C30));
    // bras tendus
    final arm = Paint()
      ..color = skin
      ..strokeWidth = w * 0.09
      ..strokeCap = StrokeCap.round;
    c.drawLine(Offset(cx - w * 0.18, h * 0.42),
        Offset(cx - w * 0.34, h * 0.6 + sin(ph * 1.3) * 3), arm);
    c.drawLine(Offset(cx + w * 0.18, h * 0.42),
        Offset(cx + w * 0.36, h * 0.58 - sin(ph * 1.3) * 3), arm);
    // tête
    final head = Offset(cx + sin(ph) * 2, h * 0.24);
    c.drawCircle(head, w * 0.17, Paint()..color = skin);
    c.drawCircle(
        head + Offset(w * 0.05, -w * 0.09), w * 0.05, Paint()..color = dark);
    // yeux rouges
    for (final dx in [-0.06, 0.06]) {
      c.drawCircle(
          head + Offset(w * dx, -w * 0.01),
          w * 0.035,
          Paint()
            ..color = const Color(0xFFFF2A2A)
            ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2));
    }
    // bouche
    c.drawLine(
        head + Offset(-w * 0.06, w * 0.08),
        head + Offset(w * 0.06, w * 0.07),
        Paint()
          ..color = Colors.black
          ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(_ZombiePainter o) => o.ph != ph;
}

class _NightPainter extends CustomPainter {
  final double t, bite;
  final int hp;
  _NightPainter({required this.t, required this.hp, required this.bite});

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    c.drawRect(
        Offset.zero & s,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF060B1A), Color(0xFF0E1A12), Color(0xFF1A2414)],
          ).createShader(Offset.zero & s));
    // lune
    final moon = Offset(w * 0.82, h * 0.1);
    c.drawCircle(moon, h * 0.16,
        Paint()..color = const Color(0xFFE8F0C8).withValues(alpha: 0.08));
    c.drawCircle(moon, h * 0.06, Paint()..color = const Color(0xFFE8F0C8));
    c.drawCircle(moon + Offset(h * 0.02, -h * 0.01), h * 0.055,
        Paint()..color = const Color(0xFF0A1020));
    // couloirs
    for (var i = 1; i < kZombieLanes; i++) {
      final x = w * i / kZombieLanes;
      c.drawLine(
          Offset(x, h * 0.08),
          Offset(x, h * 0.84),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.05)
            ..strokeWidth = 1);
    }
    // tombes au loin
    final r = Random(5);
    for (var i = 0; i < 9; i++) {
      final x = r.nextDouble() * w, y = h * (0.1 + r.nextDouble() * 0.12);
      final g = RRect.fromRectAndCorners(
          Rect.fromCenter(center: Offset(x, y), width: 16, height: 22),
          topLeft: const Radius.circular(8),
          topRight: const Radius.circular(8));
      c.drawRRect(g, Paint()..color = const Color(0xFF2A3326));
    }
    // brume qui dérive
    for (var k = 0; k < 4; k++) {
      final x = ((t * (0.3 + k * 0.1) + k * 0.27) % 1.4 - 0.2) * w;
      c.drawOval(
          Rect.fromCenter(
              center: Offset(x, h * (0.35 + k * 0.12)),
              width: w * 0.6,
              height: h * 0.12),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.04)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20));
    }
    // ligne de danger
    c.drawLine(
        Offset(0, h * 0.8),
        Offset(w, h * 0.8),
        Paint()
          ..color = Tv.red.withValues(alpha: 0.35 + 0.2 * sin(t * 2 * pi * 6))
          ..strokeWidth = 2);
    // la base : mur de sacs de sable + barbelés
    final base = Rect.fromLTWH(0, h * 0.86, w, h * 0.14);
    c.drawRect(base, Paint()..color = const Color(0xFF3A3424));
    for (var x = 0.0; x < w; x += 26) {
      for (final row in [0, 1]) {
        c.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(x + (row * 13), base.top + 2 + row * 11, 24, 10),
                const Radius.circular(5)),
            Paint()
              ..color =
                  row == 0 ? const Color(0xFF8A7A50) : const Color(0xFF7A6A44));
      }
    }
    // vies de la base
    for (var i = 0; i < 5; i++) {
      final o = Offset(w / 2 + (i - 2) * 26, base.top + base.height * 0.62);
      _heart(c, o, 9, i < hp ? const Color(0xFFFF3B4A) : Colors.black54);
    }
    if (bite > 0) {
      c.drawRect(
          Offset.zero & s,
          Paint()
            ..shader = RadialGradient(
              colors: [
                Colors.transparent,
                Tv.red.withValues(alpha: 0.55 * (1 - bite))
              ],
              stops: const [0.5, 1],
            ).createShader(Offset.zero & s));
    }
  }

  void _heart(Canvas c, Offset o, double s, Color col) {
    final p = Path()
      ..moveTo(o.dx, o.dy + s * 0.9)
      ..cubicTo(o.dx - s * 1.6, o.dy - s * 0.2, o.dx - s * 0.6, o.dy - s * 1.3,
          o.dx, o.dy - s * 0.4)
      ..cubicTo(o.dx + s * 0.6, o.dy - s * 1.3, o.dx + s * 1.6, o.dy - s * 0.2,
          o.dx, o.dy + s * 0.9);
    c.drawPath(p, Paint()..color = col);
  }

  @override
  bool shouldRepaint(_NightPainter o) => true;
}

class _SplatPainter extends CustomPainter {
  final Offset? at;
  final double t;
  _SplatPainter(this.at, this.t);
  @override
  void paint(Canvas c, Size s) {
    if (at == null || t <= 0) return;
    Burst(at!, const Color(0xFF8BFF3A), count: 26, speed: 0.7, seed: 11)
        .paint(c, s, t);
    final o = Offset(at!.dx * s.width, at!.dy * s.height);
    c.drawCircle(
        o,
        30 * Curves.easeOut.transform(t),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4 * (1 - t)
          ..color = Colors.white.withValues(alpha: 1 - t));
  }

  @override
  bool shouldRepaint(_SplatPainter o) => o.t != t || o.at != at;
}
