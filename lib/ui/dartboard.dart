import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../granboard.dart';
import 'theme.dart';

/// Style de la cible dessinée (choisi dans l'accueil, envoyé à la TV).
class BoardSkin {
  final String id;
  final String name;
  final Color background;
  final List<Color>? wood; // anneau des numéros en bois (dégradé)
  final Color rim;
  final Color singleDark;
  final Color singleLight;
  final Color ringA; // doubles / triples des segments pairs
  final Color ringB;
  final Color wire;
  final Color numbers;
  const BoardSkin({
    required this.id,
    required this.name,
    required this.background,
    this.wood,
    required this.rim,
    required this.singleDark,
    required this.singleLight,
    required this.ringA,
    required this.ringB,
    required this.wire,
    required this.numbers,
  });

  static const classic = BoardSkin(
    id: 'classic',
    name: 'Classique',
    background: Color(0xFF0B0B0E),
    rim: Color(0xFFE8B63C),
    singleDark: Color(0xFF121216),
    singleLight: Tv.cream,
    ringA: Tv.red,
    ringB: Tv.green,
    wire: Color(0xFF7D7D86),
    numbers: Tv.text,
  );

  static const pub = BoardSkin(
    id: 'pub',
    name: 'Pub en bois',
    background: Color(0xFF2A1607),
    wood: [Color(0xFF5A3214), Color(0xFF7B4720), Color(0xFF3A1F0B)],
    rim: Color(0xFFC8A75A),
    singleDark: Color(0xFF1D1A17),
    singleLight: Color(0xFFE8D7B3),
    ringA: Color(0xFFA32019),
    ringB: Color(0xFF1D6337),
    wire: Color(0xFFC8A75A),
    numbers: Color(0xFFF3E3B8),
  );

  static const electro = BoardSkin(
    id: 'electro',
    name: 'Électro',
    background: Color(0xFF07080C),
    rim: Color(0xFF3A6BFF),
    singleDark: Color(0xFF101218),
    singleLight: Color(0xFF2B2F3A),
    ringA: Color(0xFFE5202B),
    ringB: Color(0xFF2460F5),
    wire: Color(0xFF6C7386),
    numbers: Color(0xFFF4F4F6),
  );

  static const neon = BoardSkin(
    id: 'neon',
    name: 'Néon',
    background: Color(0xFF05061A),
    rim: Color(0xFF2DE2FF),
    singleDark: Color(0xFF0A0C26),
    singleLight: Color(0xFF1B2060),
    ringA: Color(0xFFFF2BD6),
    ringB: Color(0xFF2DE2FF),
    wire: Color(0xFF6F78D8),
    numbers: Color(0xFFA6F4FF),
  );

  static const blackGold = BoardSkin(
    id: 'blackgold',
    name: 'Or noir',
    background: Color(0xFF060606),
    rim: Color(0xFFE8B63C),
    singleDark: Color(0xFF0E0E10),
    singleLight: Color(0xFF2A2620),
    ringA: Color(0xFFE8B63C),
    ringB: Color(0xFF8C6716),
    wire: Color(0xFFBFA056),
    numbers: Color(0xFFFFD877),
  );

  static const ice = BoardSkin(
    id: 'ice',
    name: 'Glace',
    background: Color(0xFF0B1B2B),
    rim: Color(0xFF9FDCFF),
    singleDark: Color(0xFF14405F),
    singleLight: Color(0xFFEAF6FF),
    ringA: Color(0xFF1E88E5),
    ringB: Color(0xFF7FD3FF),
    wire: Color(0xFFB9D6EA),
    numbers: Color(0xFFEAF6FF),
  );

  static const sakura = BoardSkin(
    id: 'sakura',
    name: 'Sakura',
    background: Color(0xFF190B17),
    rim: Color(0xFFFF7EB6),
    singleDark: Color(0xFF2A1226),
    singleLight: Color(0xFFFFE3F0),
    ringA: Color(0xFFE0457F),
    ringB: Color(0xFF8E5BE8),
    wire: Color(0xFFD9A9C4),
    numbers: Color(0xFFFFC2DD),
  );

  static const ember = BoardSkin(
    id: 'ember',
    name: 'Braise',
    background: Color(0xFF120803),
    rim: Color(0xFFFF8A2B),
    singleDark: Color(0xFF1C0F08),
    singleLight: Color(0xFF4A2A14),
    ringA: Color(0xFFFF3B1F),
    ringB: Color(0xFFFFA63D),
    wire: Color(0xFFB98052),
    numbers: Color(0xFFFFC27A),
  );

  static const all = [
    classic,
    pub,
    electro,
    neon,
    blackGold,
    ice,
    sakura,
    ember
  ];
  static BoardSkin byId(String? id) =>
      all.firstWhere((s) => s.id == id, orElse: () => classic);

  /// Style en cours (toutes les cibles dessinées l'écoutent).
  static final current = ValueNotifier<BoardSkin>(classic);
  static const _pref = 'board_skin';

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      current.value = byId(p.getString(_pref));
    } catch (_) {}
  }

  static Future<void> choose(BoardSkin s) async {
    current.value = s;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_pref, s.id);
    } catch (_) {}
  }
}

/// Ordre des numéros dans le sens des aiguilles, en partant du haut.
const kBoardOrder = [
  20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5 //
];

/// Cible dessinée, avec les zones touchées mises en lumière.
class Dartboard extends StatelessWidget {
  final double size;
  final List<DartHit> highlights;
  final bool showNumbers;
  const Dartboard({
    super.key,
    required this.size,
    this.highlights = const [],
    this.showNumbers = true,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BoardSkin>(
      valueListenable: BoardSkin.current,
      builder: (context, skin, _) => SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _BoardPainter(highlights, showNumbers, skin: skin),
        ),
      ),
    );
  }
}

/// Aperçu d'un style de cible (sans changer le style en cours).
class DartboardPreview extends StatelessWidget {
  final BoardSkin skin;
  final double size;
  const DartboardPreview({super.key, required this.skin, required this.size});

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _BoardPainter(const [], true, skin: skin)),
      );
}

class _BoardPainter extends CustomPainter {
  final List<DartHit> highlights;
  final bool showNumbers;
  final BoardSkin skin;
  _BoardPainter(this.highlights, this.showNumbers,
      {this.skin = BoardSkin.classic});

  // Rayons relatifs (1 = bord extérieur de la zone des doubles). Doubles,
  // triples et bull larges comme sur une cible électronique (pas les
  // anneaux fins d'une cible anglaise).
  static const rDoubleOut = 1.0;
  static const rDoubleIn = 0.86;
  static const rTripleOut = 0.63;
  static const rTripleIn = 0.49;
  static const rBullOut = 0.12;
  static const rBullIn = 0.055;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final outer = size.width / 2;
    final numbersBand = showNumbers ? outer * 0.15 : outer * 0.04;
    final r = outer - numbersBand;

    // Fond (bois verni pour le style pub) + cerclage
    final wood = skin.wood;
    if (wood != null) {
      canvas.drawCircle(
          c,
          outer,
          Paint()
            ..shader = RadialGradient(
              colors: wood,
              stops: [r / outer, (r / outer + 1) / 2, 1],
            ).createShader(Rect.fromCircle(center: c, radius: outer)));
      // Veines du bois
      final grain = Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.6, outer * 0.006);
      for (var k = 0; k < 18; k++) {
        final rr = r + (outer - r) * (k + 0.5) / 18;
        canvas.drawArc(Rect.fromCircle(center: c, radius: rr), k * 0.7,
            1.8 + (k % 3) * 0.6, false, grain);
      }
    } else {
      canvas.drawCircle(c, outer, Paint()..color = skin.background);
    }
    canvas.drawCircle(
        c,
        outer - 1,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(2, outer * 0.025)
          // Cible classique : le cercle prend la couleur du thème
          ..color = skin == BoardSkin.classic ? Tv.gold : skin.rim);

    const seg = 2 * math.pi / 20;
    for (var i = 0; i < 20; i++) {
      final a0 = -math.pi / 2 - seg / 2 + i * seg;
      final even = i % 2 == 0;
      final single = even ? skin.singleDark : skin.singleLight;
      final ring = even ? skin.ringA : skin.ringB;
      _wedge(canvas, c, r * rDoubleIn, r * rTripleOut, a0, seg, single);
      _wedge(canvas, c, r * rTripleIn, r * rBullOut, a0, seg, single);
      _wedge(canvas, c, r * rDoubleOut, r * rDoubleIn, a0, seg, ring);
      _wedge(canvas, c, r * rTripleOut, r * rTripleIn, a0, seg, ring);
    }
    canvas.drawCircle(c, r * rBullOut, Paint()..color = skin.ringB);
    canvas.drawCircle(c, r * rBullIn, Paint()..color = skin.ringA);

    // Fils
    final wirePaint = Paint()
      ..color = skin.wire
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.6, r * 0.006);
    for (final rr in [rDoubleOut, rDoubleIn, rTripleOut, rTripleIn, rBullOut]) {
      canvas.drawCircle(c, r * rr, wirePaint);
    }
    for (var i = 0; i < 20; i++) {
      final a = -math.pi / 2 - seg / 2 + i * seg;
      canvas.drawLine(c + Offset(math.cos(a), math.sin(a)) * r * rBullOut,
          c + Offset(math.cos(a), math.sin(a)) * r, wirePaint);
    }

    // Zones touchées (halo lumineux)
    for (var k = 0; k < highlights.length; k++) {
      _highlight(canvas, c, r, highlights[k], k);
    }

    // Numéros
    if (showNumbers) {
      for (var i = 0; i < 20; i++) {
        final n = kBoardOrder[i];
        final hit = highlights.any((h) => h.number == n);
        final a = -math.pi / 2 + i * seg;
        final pos =
            c + Offset(math.cos(a), math.sin(a)) * (r + numbersBand / 2);
        final tp = TextPainter(
          text: TextSpan(
            text: '$n',
            style: TextStyle(
              fontFamily: Tv.font,
              fontWeight: FontWeight.w800,
              fontSize: numbersBand * 0.78,
              color: hit ? Tv.goldLight : skin.numbers,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
      }
    }
  }

  void _highlight(Canvas canvas, Offset c, double r, DartHit h, int order) {
    final glow = Paint()
      ..color = Tv.goldLight
      ..maskFilter = MaskFilter.blur(BlurStyle.solid, math.max(2, r * 0.03));
    final edge = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.8, r * 0.018);

    if (h.isBull) {
      final rr = h.ring == Ring.innerBull ? rBullIn : rBullOut;
      canvas.drawCircle(c, r * rr, glow);
      canvas.drawCircle(c, r * rr, edge);
      _badge(canvas, c, r, order);
      return;
    }
    final i = kBoardOrder.indexOf(h.number);
    if (i < 0) return;
    const seg = 2 * math.pi / 20;
    final a0 = -math.pi / 2 - seg / 2 + i * seg;
    final (ro, ri) = switch (h.ring) {
      Ring.double => (rDoubleOut, rDoubleIn),
      Ring.triple => (rTripleOut, rTripleIn),
      Ring.singleOuter => (rDoubleIn, rTripleOut),
      _ => (rTripleIn, rBullOut),
    };
    final path = _wedgePath(c, r * ro, r * ri, a0, seg);
    canvas.drawPath(path, glow);
    canvas.drawPath(path, edge);
    final mid = a0 + seg / 2;
    final p = c + Offset(math.cos(mid), math.sin(mid)) * r * (ro + ri) / 2;
    _badge(canvas, p, r, order);
  }

  /// Petit numéro de fléchette (1, 2, 3) posé sur la zone.
  void _badge(Canvas canvas, Offset p, double r, int order) {
    final br = math.max(9.0, r * 0.1);
    canvas.drawCircle(p, br, Paint()..color = Colors.black);
    canvas.drawCircle(
        p,
        br,
        Paint()
          ..color = Tv.gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, br * 0.18));
    final tp = TextPainter(
      text: TextSpan(
          text: '${order + 1}',
          style: TextStyle(
              fontFamily: Tv.font,
              fontWeight: FontWeight.w800,
              fontSize: br * 1.3,
              color: Tv.goldLight)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
  }

  Path _wedgePath(Offset c, double ro, double ri, double a0, double sweep) {
    return Path()
      ..arcTo(Rect.fromCircle(center: c, radius: ro), a0, sweep, true)
      ..arcTo(Rect.fromCircle(center: c, radius: ri), a0 + sweep, -sweep, false)
      ..close();
  }

  void _wedge(Canvas canvas, Offset c, double ro, double ri, double a0,
      double sweep, Color color) {
    canvas.drawPath(_wedgePath(c, ro, ri, a0, sweep), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_BoardPainter old) =>
      old.highlights != highlights ||
      old.showNumbers != showNumbers ||
      old.skin != skin;
}

// ─── Cible animée (écran de partie) ───────────────────────────────────────

/// Point d'impact d'une fléchette (centre de la zone + léger décalage stable).
Offset dartPoint(Offset c, double r, DartHit h, int order) {
  if (h.isBull) {
    final rr = h.ring == Ring.innerBull ? 0.03 : 0.088;
    final a = order * 2.1;
    return c + Offset(math.cos(a), math.sin(a)) * r * rr;
  }
  final i = kBoardOrder.indexOf(h.number);
  const seg = 2 * math.pi / 20;
  final (ro, ri) = switch (h.ring) {
    Ring.double => (_BoardPainter.rDoubleOut, _BoardPainter.rDoubleIn),
    Ring.triple => (_BoardPainter.rTripleOut, _BoardPainter.rTripleIn),
    Ring.singleOuter => (_BoardPainter.rDoubleIn, _BoardPainter.rTripleOut),
    _ => (_BoardPainter.rTripleIn, _BoardPainter.rBullOut),
  };
  // Décalage pour que 3 fléchettes dans la même zone ne se cachent pas
  final jitterA = (order - 1) * seg * 0.22;
  final a = -math.pi / 2 + i * seg + jitterA;
  final rr = (ro + ri) / 2 + (order.isEven ? -1 : 1) * (ro - ri) * 0.12;
  return c + Offset(math.cos(a), math.sin(a)) * r * rr;
}

/// Grande cible de la partie : zones touchées qui pulsent, impact animé
/// (onde + fléchette qui se plante), éclair rouge sur un bust.
class AnimatedDartboard extends StatefulWidget {
  final double size;
  final List<DartHit> hits;
  final bool bust;
  final bool win;
  final Color? dartColor;

  /// Zone à viser pour finir (contour vert qui pulse).
  final List<DartHit> targets;
  const AnimatedDartboard({
    super.key,
    required this.size,
    required this.hits,
    this.targets = const [],
    this.bust = false,
    this.win = false,
    this.dartColor,
  });

  @override
  State<AnimatedDartboard> createState() => _AnimatedDartboardState();
}

class _AnimatedDartboardState extends State<AnimatedDartboard>
    with TickerProviderStateMixin {
  late final _impact = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 650));
  late final _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat(reverse: true);
  late final _flash = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didUpdateWidget(AnimatedDartboard old) {
    super.didUpdateWidget(old);
    if (widget.hits.length > old.hits.length) _impact.forward(from: 0);
    if (widget.bust && !old.bust) _flash.forward(from: 0);
    if (widget.win && !old.win) _flash.forward(from: 0);
  }

  @override
  void dispose() {
    _impact.dispose();
    _pulse.dispose();
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.size,
        child: Stack(
          children: [
            Positioned.fill(
              child: ValueListenableBuilder<BoardSkin>(
                valueListenable: BoardSkin.current,
                builder: (context, skin, _) => CustomPaint(
                  painter: _BoardPainter(const [], true, skin: skin),
                ),
              ),
            ),
            Positioned.fill(
              child: AnimatedBuilder(
                animation: Listenable.merge([_impact, _pulse, _flash]),
                builder: (context, _) => CustomPaint(
                  painter: _HitsPainter(
                    hits: widget.hits,
                    targets: widget.targets,
                    impact: _impact.value,
                    pulse: _pulse.value,
                    flash: _flash.value,
                    flashColor: widget.win ? Tv.gold : Tv.red,
                    dartColor: widget.dartColor ?? Tv.gold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HitsPainter extends CustomPainter {
  final List<DartHit> hits;
  final List<DartHit> targets;
  final double impact; // 0 → 1 pour la dernière fléchette
  final double pulse;
  final double flash;
  final Color flashColor;
  final Color dartColor;
  _HitsPainter({
    required this.hits,
    this.targets = const [],
    required this.impact,
    required this.pulse,
    required this.flash,
    required this.flashColor,
    required this.dartColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final outer = size.width / 2;
    final r = outer - outer * 0.15; // même calcul que _BoardPainter

    // Zone à viser pour finir : contour blanc qui pulse (visible sur le
    // rouge comme sur le vert)
    for (final h in targets) {
      final path = _zonePath(c, r, h);
      canvas.drawPath(path,
          Paint()..color = Colors.white.withValues(alpha: 0.2 + 0.3 * pulse));
      canvas.drawPath(
          path,
          Paint()
            ..color = Tv.goldLight.withValues(alpha: 0.5 + 0.4 * pulse)
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.035
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.02));
      canvas.drawPath(
          path,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.014);
    }

    // Zones touchées : halo qui pulse
    for (var k = 0; k < hits.length; k++) {
      final last = k == hits.length - 1;
      final path = _zonePath(c, r, hits[k]);
      final glow = 0.55 + 0.35 * pulse + (last ? 0.1 * (1 - impact) : 0);
      canvas.drawPath(
          path,
          Paint()
            ..color = Tv.goldLight.withValues(alpha: glow.clamp(0, 1))
            ..maskFilter = MaskFilter.blur(BlurStyle.solid, r * 0.03));
      canvas.drawPath(
          path,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.02);
    }

    // Onde de choc de la dernière fléchette
    if (hits.isNotEmpty && impact < 1) {
      final p = dartPoint(c, r, hits.last, hits.length);
      final t = Curves.easeOut.transform(impact);
      canvas.drawCircle(
          p,
          r * (0.05 + 0.4 * t),
          Paint()
            ..color = Tv.goldLight.withValues(alpha: (1 - t) * 0.9)
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.025 * (1 - t) + 1);
    }

    // Fléchettes plantées (vues de face : empennage en croix)
    for (var k = 0; k < hits.length; k++) {
      final last = k == hits.length - 1;
      final p = dartPoint(c, r, hits[k], k + 1);
      // La dernière arrive de loin : plus grosse puis se plante
      final t = last ? Curves.easeIn.transform(impact.clamp(0, 1)) : 1.0;
      final scale = 1 + (1 - t) * 1.6;
      final s = r * 0.085 * scale;
      final shadowOff = const Offset(1, 1) * r * 0.03 * scale;
      canvas.drawCircle(p + shadowOff, s * 0.9,
          Paint()..color = Colors.black.withValues(alpha: 0.45));
      final flight = Paint()..color = dartColor;
      for (var q = 0; q < 4; q++) {
        final a = math.pi / 4 + q * math.pi / 2;
        final dir = Offset(math.cos(a), math.sin(a));
        final side = Offset(-dir.dy, dir.dx);
        canvas.drawPath(
            Path()
              ..moveTo(p.dx, p.dy)
              ..lineTo((p + dir * s + side * s * 0.35).dx,
                  (p + dir * s + side * s * 0.35).dy)
              ..lineTo((p + dir * s - side * s * 0.35).dx,
                  (p + dir * s - side * s * 0.35).dy)
              ..close(),
            flight);
      }
      canvas.drawCircle(p, s * 0.28, Paint()..color = Colors.black);
      canvas.drawCircle(
          p,
          s * 0.28,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1, s * 0.08));
    }

    // Éclair plein écran (bust en rouge, victoire en or)
    if (flash > 0 && flash < 1) {
      final a = math.sin(flash * math.pi) * 0.45;
      canvas.drawCircle(
          c, outer, Paint()..color = flashColor.withValues(alpha: a));
    }
  }

  Path _zonePath(Offset c, double r, DartHit h) {
    if (h.isBull) {
      final rr = h.ring == Ring.innerBull
          ? _BoardPainter.rBullIn
          : _BoardPainter.rBullOut;
      return Path()..addOval(Rect.fromCircle(center: c, radius: r * rr));
    }
    final i = kBoardOrder.indexOf(h.number);
    const seg = 2 * math.pi / 20;
    final a0 = -math.pi / 2 - seg / 2 + i * seg;
    final (ro, ri) = switch (h.ring) {
      Ring.double => (_BoardPainter.rDoubleOut, _BoardPainter.rDoubleIn),
      Ring.triple => (_BoardPainter.rTripleOut, _BoardPainter.rTripleIn),
      Ring.singleOuter => (_BoardPainter.rDoubleIn, _BoardPainter.rTripleOut),
      _ => (_BoardPainter.rTripleIn, _BoardPainter.rBullOut),
    };
    return Path()
      ..arcTo(Rect.fromCircle(center: c, radius: r * ro), a0, seg, true)
      ..arcTo(Rect.fromCircle(center: c, radius: r * ri), a0 + seg, -seg, false)
      ..close();
  }

  @override
  bool shouldRepaint(_HitsPainter old) => true;
}
