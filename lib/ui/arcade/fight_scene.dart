// Fight Club : un ring sous les projecteurs, une carte par combattant
// (photo, barre de vie avec traînée rouge, numéros) ; coups (secousse,
// éclair), soins (halo vert), onde de choc du bull, tampon K.O.

import 'dart:math';

import 'package:flutter/material.dart';

import '../../game/practice.dart';
import '../theme.dart';
import '../widgets.dart';
import 'common.dart';

class FightScene extends StatefulWidget {
  final PracticeGame game;
  final Color Function(int) colorOf;
  const FightScene({super.key, required this.game, required this.colorOf});
  @override
  State<FightScene> createState() => _FightSceneState();
}

class _FightSceneState extends State<FightScene>
    with TickerProviderStateMixin, ArcadeEvents, AmbientTicker {
  @override
  PracticeGame get game => widget.game;
  final _pops = GlobalKey<PopLayerState>();
  late final AnimationController _hit = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700));
  late final AnimationController _blast = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));
  int? _victim;
  int? _healed;

  @override
  void initState() {
    super.initState();
    startAmbient();
  }

  Offset _cardCenter(int i) {
    final n = game.players.length;
    if (n == 2) return Offset(i == 0 ? 0.25 : 0.75, 0.52);
    return Offset(i.isEven ? 0.27 : 0.73, i < 2 ? 0.3 : 0.74);
  }

  @override
  void onEvent(Map<String, dynamic> e) {
    switch (e['type']) {
      case 'hit':
        _victim = e['o'] as int;
        _healed = null;
        _hit.forward(from: 0);
        _pops.currentState?.add(Pop(
            e['m'] == 3 ? 'UPPERCUT ! -${e['dmg']}' : '-${e['dmg']}',
            const Color(0xFFFF5A4A),
            _cardCenter(_victim!) - const Offset(0, 0.12),
            size: e['m'] == 3 ? 40 : 34));
      case 'heal':
        _healed = e['p'] as int;
        _victim = null;
        _hit.forward(from: 0);
        _pops.currentState?.add(Pop('+${e['v']} PV', const Color(0xFF6BFF8A),
            _cardCenter(_healed!) - const Offset(0, 0.12)));
      case 'blast':
        _blast.forward(from: 0);
        _pops.currentState?.add(Pop('ONDE DE CHOC -${e['dmg']}',
            const Color(0xFFFFD34F), const Offset(0.5, 0.5),
            size: 38));
    }
  }

  @override
  void dispose() {
    _hit.dispose();
    _blast.dispose();
    stopAmbient();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    checkEvent();
    final g = game;
    final nums = fightNumbers(g);
    final maxHp = g.settings.goalOrDefault;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: LayoutBuilder(builder: (context, c) {
        final n = g.players.length;
        final cw = n == 2 ? c.maxWidth * 0.4 : c.maxWidth * 0.44;
        final ch = n == 2 ? c.maxHeight * 0.62 : c.maxHeight * 0.42;
        return Stack(children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: Listenable.merge([ambient, _blast]),
              builder: (context, _) => CustomPaint(
                  painter: _RingPainter(
                      ambient.value, _blast.isAnimating ? _blast.value : 0)),
            ),
          ),
          if (n == 2)
            Positioned.fill(
              child: Center(
                child: Text('VS',
                    style: Tv.title(64, color: const Color(0xFFE53935))
                        .copyWith(fontStyle: FontStyle.italic, shadows: const [
                      Shadow(blurRadius: 16, color: Colors.black)
                    ])),
              ),
            ),
          for (var i = 0; i < n; i++)
            Positioned(
              left: _cardCenter(i).dx * c.maxWidth - cw / 2,
              top: _cardCenter(i).dy * c.maxHeight - ch / 2,
              width: cw,
              height: ch,
              child: AnimatedBuilder(
                animation: _hit,
                builder: (context, child) {
                  final t = _hit.isAnimating ? _hit.value : 0.0;
                  final off = _victim == i ? shake(t, amp: 10) : Offset.zero;
                  return Transform.translate(offset: off, child: child);
                },
                child: _FighterCard(
                  key: ValueKey('fight-$i'),
                  id: g.players[i].id,
                  name: g.players[i].name,
                  color: widget.colorOf(i),
                  hp: g.stateOf(i).score,
                  maxHp: maxHp,
                  numbers: nums.isEmpty ? const [] : nums[i],
                  current: i == g.current && !g.finished,
                  out: g.stateOf(i).out,
                  flash: _hit,
                  flashColor: _victim == i
                      ? const Color(0xFFFF3B30)
                      : _healed == i
                          ? const Color(0xFF4CFF80)
                          : null,
                ),
              ),
            ),
          Positioned.fill(child: PopLayer(key: _pops)),
        ]);
      }),
    );
  }
}

class _FighterCard extends StatelessWidget {
  final String id, name;
  final Color color;
  final int hp, maxHp;
  final List<int> numbers;
  final bool current, out;
  final Animation<double> flash;
  final Color? flashColor;
  const _FighterCard(
      {super.key,
      required this.id,
      required this.name,
      required this.color,
      required this.hp,
      required this.maxHp,
      required this.numbers,
      required this.current,
      required this.out,
      required this.flash,
      required this.flashColor});

  @override
  Widget build(BuildContext context) {
    final frac = (hp / maxHp).clamp(0.0, 1.0);
    final barColor = frac > 0.5
        ? const Color(0xFF4CD964)
        : frac > 0.25
            ? const Color(0xFFFFB02E)
            : const Color(0xFFFF3B30);
    return LayoutBuilder(builder: (context, c) {
      final av = min(c.maxHeight * 0.42, c.maxWidth * 0.36);
      return Stack(clipBehavior: Clip.none, children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withValues(alpha: out ? 0.15 : 0.55),
                Colors.black.withValues(alpha: 0.8)
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: current ? Colors.white : color.withValues(alpha: 0.7),
                width: current ? 2.5 : 1.5),
            boxShadow: [
              if (current)
                BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 22),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Opacity(
            opacity: out ? 0.45 : 1,
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: color, width: 3),
                          boxShadow: [
                            BoxShadow(
                                color: color.withValues(alpha: 0.5),
                                blurRadius: 12)
                          ],
                        ),
                        child: PlayerAvatar(
                            id: id, name: name, color: color, size: av),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(name.toUpperCase(),
                                  maxLines: 1,
                                  style: Tv.title(22, color: Colors.white)),
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text('$hp PV',
                                  style: Tv.title(30, color: barColor)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                _HpBar(frac: frac, color: barColor),
                const SizedBox(height: 6),
                Row(
                  children: [
                    for (final n in numbers)
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: color),
                          ),
                          alignment: Alignment.center,
                          child: Text('$n',
                              style: Tv.title(20, color: Colors.white)),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // éclair du coup / halo du soin
        if (flashColor != null)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: flash,
                builder: (context, _) {
                  final t = flash.value;
                  final a = t <= 0 || t >= 1 ? 0.0 : (1 - t) * 0.6;
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: flashColor!.withValues(alpha: a),
                    ),
                  );
                },
              ),
            ),
          ),
        if (out)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 2.4, end: 1),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutBack,
                  builder: (context, s, child) =>
                      Transform.scale(scale: s, child: child),
                  child: Transform.rotate(
                    angle: -0.25,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 2),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: const Color(0xFFFF3B30), width: 4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('K.O.',
                          style: Tv.title(46, color: const Color(0xFFFF3B30))),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ]);
    });
  }
}

/// Barre de vie : la partie perdue reste rouge un instant puis se vide.
class _HpBar extends StatelessWidget {
  final double frac;
  final Color color;
  const _HpBar({required this.frac, required this.color});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 14,
      child: LayoutBuilder(builder: (context, c) {
        return Stack(children: [
          Container(
            decoration: BoxDecoration(
                color: Colors.black, borderRadius: BorderRadius.circular(7)),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(end: frac),
            duration: const Duration(milliseconds: 1100),
            curve: const Interval(0.45, 1, curve: Curves.easeOut),
            builder: (context, v, _) => Container(
              width: c.maxWidth * v,
              decoration: BoxDecoration(
                  color: const Color(0xFFB71C1C),
                  borderRadius: BorderRadius.circular(7)),
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(end: frac),
            duration: const Duration(milliseconds: 280),
            builder: (context, v, _) => Container(
              width: c.maxWidth * v,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [Color.lerp(color, Colors.white, 0.3)!, color]),
                borderRadius: BorderRadius.circular(7),
              ),
            ),
          ),
        ]);
      }),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double t, blast;
  _RingPainter(this.t, this.blast);
  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF0A0505));
    // tapis du ring en perspective
    final mat = Path()
      ..moveTo(w * 0.08, h * 0.98)
      ..lineTo(w * 0.92, h * 0.98)
      ..lineTo(w * 0.78, h * 0.12)
      ..lineTo(w * 0.22, h * 0.12)
      ..close();
    c.drawPath(
        mat,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF3A1414), Color(0xFF5A1C1C)],
          ).createShader(Offset.zero & s));
    // cordes
    for (var k = 0; k < 3; k++) {
      final y0 = h * (0.12 - k * 0.035), y1 = h * (0.98 - k * 0.05);
      final rope = Paint()
        ..color = [
          const Color(0xFFE53935),
          Colors.white,
          const Color(0xFF1E5AE5)
        ][k]
            .withValues(alpha: 0.75)
        ..strokeWidth = 3;
      c.drawLine(Offset(w * 0.22, y0), Offset(w * 0.08, y1), rope);
      c.drawLine(Offset(w * 0.78, y0), Offset(w * 0.92, y1), rope);
      c.drawLine(Offset(w * 0.22, y0), Offset(w * 0.78, y0), rope);
    }
    // projecteurs qui balaient
    for (final (x, ph) in [(0.25, 0.0), (0.75, 1.7)]) {
      final a = sin(t * 2 * pi * 2 + ph) * 0.25;
      final o = Offset(w * x, -10);
      final e = Offset(w * x + sin(a) * h, h);
      c.drawPath(
          Path()
            ..moveTo(o.dx - 4, o.dy)
            ..lineTo(o.dx + 4, o.dy)
            ..lineTo(e.dx + 110, e.dy)
            ..lineTo(e.dx - 110, e.dy)
            ..close(),
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.16),
                Colors.white.withValues(alpha: 0)
              ],
            ).createShader(Offset.zero & s));
    }
    // onde de choc
    if (blast > 0) {
      final r = blast * max(w, h) * 0.8;
      c.drawCircle(
          Offset(w / 2, h / 2),
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 18 * (1 - blast)
            ..color = const Color(0xFFFFD34F).withValues(alpha: 1 - blast));
      c.drawRect(
          Offset.zero & s,
          Paint()
            ..color = Colors.white
                .withValues(alpha: 0.25 * (1 - blast) * (blast < 0.2 ? 1 : 0)));
    }
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.t != t || o.blast != blast;
}
