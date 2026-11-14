import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../granboard.dart';
import '../media.dart';
import '../players.dart';
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

  /// Cible électronique réaliste : plastique troué, relief, anneau de LED
  /// animé et fléchettes en 3D.
  final bool realistic;
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
    this.realistic = true,
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

  static const real = BoardSkin(
    id: 'real',
    name: 'Réaliste',
    background: Color(0xFF0C0D10),
    rim: Color(0xFF2E7BFF),
    singleDark: Color(0xFF17181C),
    singleLight: Color(0xFFE6E2D6),
    ringA: Color(0xFFD7262C),
    ringB: Color(0xFF1F5FD6),
    wire: Color(0xFF050506),
    numbers: Color(0xFFF2F2F2),
    realistic: true,
  );

  static const all = [
    real,
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

/// Cible choisie par chaque joueur (fiche du joueur) : elle remplace le
/// style général pendant son tour, et celle du profil principal s'affiche
/// sur l'écran TV en attente. Gardée sur le serveur avec sa photo et son
/// son (`gb_set_board`, `MediaStore`) : elle le suit sur tous les
/// téléphones, la TV et en ligne.
class PlayerBoards extends ChangeNotifier {
  static final instance = PlayerBoards._();
  PlayerBoards._() {
    MediaStore.instance.addListener(notifyListeners);
  }

  /// Reçues du téléphone (écran TV).
  final Map<String, String> _remote = {};
  String? _idle;

  /// Cibles connues sur ce téléphone (envoyées à la TV).
  Map<String, String> get all => MediaStore.instance.boards;

  /// Cible du joueur, null = style général.
  BoardSkin? of(String? id) {
    if (id == null) return null;
    final s = _remote[id] ?? MediaStore.instance.boardOf(id);
    if (s.isEmpty || !BoardSkin.all.any((b) => b.id == s)) return null;
    return BoardSkin.byId(s);
  }

  /// Cible de l'écran TV en attente (null = style général).
  BoardSkin? get idle => _idle == null ? null : BoardSkin.byId(_idle);

  /// Change la cible du compte (null = style par défaut). Lève ApiError.
  Future<void> set(PlayerProfile p, BoardSkin? skin) =>
      MediaStore.instance.setBoard(p, skin?.id ?? '');

  /// Écran TV : cibles envoyées par le téléphone.
  void applyRemote(Map boards, String? idle) {
    final m = {for (final e in boards.entries) '${e.key}': '${e.value}'};
    if (_idle == idle &&
        m.length == _remote.length &&
        m.entries.every((e) => _remote[e.key] == e.value)) {
      return;
    }
    _remote
      ..clear()
      ..addAll(m);
    _idle = idle;
    notifyListeners();
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

  /// Style imposé (sinon le style général).
  final BoardSkin? skin;
  const Dartboard({
    super.key,
    required this.size,
    this.highlights = const [],
    this.showNumbers = true,
    this.skin,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BoardSkin>(
      valueListenable: BoardSkin.current,
      builder: (context, cur, _) => SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _BoardPainter(highlights, showNumbers, skin: skin ?? cur),
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
    if (skin.realistic) {
      _paintReal(canvas, c, outer, r, numbersBand);
      for (var k = 0; k < highlights.length; k++) {
        _highlight(canvas, c, r, highlights[k], k);
      }
      return;
    }

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

  /// Cible électronique : contour en plastique noir, segments en relief
  /// percés de petits trous, séparateurs, chiffres en relief, reflet.
  void _paintReal(
      Canvas canvas, Offset c, double outer, double r, double band) {
    final full = Rect.fromCircle(center: c, radius: outer);
    final wood = skin.wood;
    if (wood != null) {
      // Contour en bois verni avec ses veines
      canvas.drawCircle(
          c,
          outer,
          Paint()
            ..shader = RadialGradient(
              colors: wood,
              stops: [r / outer, (r / outer + 1) / 2, 1],
            ).createShader(full));
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
      // Contour (catch ring) en plastique mat avec relief, teinté au style
      final b = skin.background;
      canvas.drawCircle(
          c,
          outer,
          Paint()
            ..shader = RadialGradient(
              colors: [
                Color.lerp(b, Colors.white, 0.14)!,
                Color.lerp(b, Colors.white, 0.05)!,
                Color.lerp(b, Colors.black, 0.4)!,
                Color.lerp(b, Colors.white, 0.1)!,
              ],
              stops: [r / outer * 0.98, r / outer + 0.02, 0.96, 1],
            ).createShader(full));
    }
    // Liseré extérieur à la couleur du style (classique : couleur du thème)
    canvas.drawCircle(
        c,
        outer - outer * 0.006,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, outer * 0.012)
          ..color = (skin == BoardSkin.classic ? Tv.gold : skin.rim)
              .withValues(alpha: 0.85));
    // Ombre portée de la zone de jeu sur le contour
    canvas.drawCircle(
        c,
        r * 1.012,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.7)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.02));

    const seg = 2 * math.pi / 20;
    for (var i = 0; i < 20; i++) {
      final a0 = -math.pi / 2 - seg / 2 + i * seg;
      final even = i % 2 == 0;
      final single = even ? skin.singleDark : skin.singleLight;
      final ring = even ? skin.ringA : skin.ringB;
      for (final (ro, ri, col) in [
        (rDoubleIn, rTripleOut, single),
        (rTripleIn, rBullOut, single),
        (rDoubleOut, rDoubleIn, ring),
        (rTripleOut, rTripleIn, ring),
      ]) {
        final path = _wedgePath(c, r * ro, r * ri, a0, seg);
        // Relief : plus clair au centre du segment, plus sombre aux bords
        canvas.drawPath(
            path,
            Paint()
              ..shader = RadialGradient(
                colors: [
                  Color.lerp(col, Colors.white, 0.10)!,
                  col,
                  Color.lerp(col, Colors.black, 0.35)!,
                ],
                stops: [ri / ro, (ri / ro + 1) / 2, 1],
              ).createShader(Rect.fromCircle(center: c, radius: r * ro)));
        _holes(canvas, c, r, ro, ri, a0, seg, col);
      }
    }
    // Bull : 2 cercles en relief percés
    for (final (rr, col) in [(rBullOut, skin.ringB), (rBullIn, skin.ringA)]) {
      canvas.drawCircle(
          c,
          r * rr,
          Paint()
            ..shader = RadialGradient(colors: [
              Color.lerp(col, Colors.white, 0.18)!,
              col,
              Color.lerp(col, Colors.black, 0.4)!,
            ]).createShader(Rect.fromCircle(center: c, radius: r * rr)));
    }
    _holes(canvas, c, r, rBullOut, rBullIn, 0, 2 * math.pi, skin.ringB);
    _holes(canvas, c, r, rBullIn, 0.012, 0, 2 * math.pi, skin.ringA);

    // Séparateurs en plastique (rainures sombres + liseré clair)
    final gap = Paint()
      ..color = Color.lerp(skin.wire, Colors.black, 0.8)!
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, r * 0.013);
    final lip = Paint()
      ..color =
          Color.lerp(skin.wire, Colors.white, 0.3)!.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.5, r * 0.004);
    for (final rr in [rDoubleOut, rDoubleIn, rTripleOut, rTripleIn, rBullOut]) {
      canvas.drawCircle(c, r * rr, gap);
      canvas.drawCircle(c, r * rr - r * 0.007, lip);
    }
    canvas.drawCircle(c, r * rBullIn, gap);
    for (var i = 0; i < 20; i++) {
      final a = -math.pi / 2 - seg / 2 + i * seg;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + d * r * rBullOut, c + d * r, gap);
    }

    // Chiffres en relief
    if (showNumbers) {
      for (var i = 0; i < 20; i++) {
        final n = kBoardOrder[i];
        final a = -math.pi / 2 + i * seg;
        final pos = c + Offset(math.cos(a), math.sin(a)) * (r + band / 2);
        for (final (off, color) in [
          (Offset(r * 0.006, r * 0.008), Colors.black),
          (Offset.zero, skin.numbers),
        ]) {
          final tp = TextPainter(
            text: TextSpan(
              text: '$n',
              style: TextStyle(
                fontFamily: Tv.font,
                fontWeight: FontWeight.w800,
                fontSize: band * 0.74,
                color: color,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, pos + off - Offset(tp.width / 2, tp.height / 2));
        }
      }
    }

    // Reflet de la lumière (haut gauche) sur le plastique
    canvas.drawCircle(
        c,
        outer,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.45, -0.55),
            radius: 0.9,
            colors: [
              Colors.white.withValues(alpha: 0.13),
              Colors.white.withValues(alpha: 0.03),
              Colors.transparent,
            ],
            stops: const [0, 0.45, 1],
          ).createShader(full));
  }

  /// Petits trous de la cible électronique, en rangées régulières.
  void _holes(Canvas canvas, Offset c, double r, double ro, double ri,
      double a0, double sweep, Color base) {
    final pitch = r * 0.034; // écart entre trous
    final dot = Paint()
      ..color = Color.lerp(base, Colors.black, 0.62)!
      ..strokeWidth = pitch * 0.42
      ..strokeCap = StrokeCap.round;
    final shine = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..strokeWidth = pitch * 0.16
      ..strokeCap = StrokeCap.round;
    final pts = <Offset>[];
    final hi = <Offset>[];
    for (var rad = r * ri + pitch * 0.6;
        rad < r * ro - pitch * 0.4;
        rad += pitch) {
      final n = (rad * sweep / pitch).floor();
      if (n < 1) continue;
      final step = sweep / n;
      for (var k = 0; k < n; k++) {
        final a = a0 + step * (k + 0.5);
        final p = c + Offset(math.cos(a), math.sin(a)) * rad;
        pts.add(p);
        hi.add(p + Offset(pitch * 0.07, pitch * 0.08));
      }
    }
    canvas.drawPoints(PointMode.points, pts, dot);
    canvas.drawPoints(PointMode.points, hi, shine);
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

  /// Numéros allumés en continu (Cricket : fermés par le joueur) et
  /// numéros qui clignotent (Cricket : encore à fermer), sur l'anneau.
  final Set<int> litNumbers;
  final Set<int> aimNumbers;

  /// Style imposé (cible du joueur en cours), sinon le style général.
  final BoardSkin? skin;

  /// Zones peintes (Paint) : (zone, couleur, protégée).
  final List<(DartHit, Color, bool)> painted;
  const AnimatedDartboard({
    super.key,
    required this.size,
    required this.hits,
    this.targets = const [],
    this.litNumbers = const {},
    this.aimNumbers = const {},
    this.painted = const [],
    this.bust = false,
    this.win = false,
    this.dartColor,
    this.skin,
  });

  @override
  State<AnimatedDartboard> createState() => _AnimatedDartboardState();
}

class _AnimatedDartboardState extends State<AnimatedDartboard>
    with TickerProviderStateMixin {
  // Démarre « fini » : les fléchettes déjà là sont plantées
  late final _impact = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 650), value: 1);
  late final _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat(reverse: true);
  late final _flash = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));
  // Anneau de LED et reflet qui tournent (cible réaliste)
  late final _spin =
      AnimationController(vsync: this, duration: const Duration(seconds: 6))
        ..repeat();

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
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.size,
        child: Stack(
          children: [
            // La cible fixe dans sa propre couche : pas redessinée à chaque
            // image de l'animation
            Positioned.fill(
              child: RepaintBoundary(
                child: ValueListenableBuilder<BoardSkin>(
                  valueListenable: BoardSkin.current,
                  builder: (context, cur, _) => CustomPaint(
                    isComplex: true,
                    painter:
                        _BoardPainter(const [], true, skin: widget.skin ?? cur),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: ValueListenableBuilder<BoardSkin>(
                valueListenable: BoardSkin.current,
                builder: (context, cur, _) {
                  final skin = widget.skin ?? cur;
                  return AnimatedBuilder(
                    animation: Listenable.merge(
                        [_impact, _pulse, _flash, if (skin.realistic) _spin]),
                    builder: (context, _) => CustomPaint(
                      painter: _HitsPainter(
                        hits: widget.hits,
                        targets: widget.targets,
                        litNumbers: widget.litNumbers,
                        aimNumbers: widget.aimNumbers,
                        painted: widget.painted,
                        impact: _impact.value,
                        pulse: _pulse.value,
                        flash: _flash.value,
                        flashColor: widget.win ? Tv.gold : Tv.red,
                        dartColor: widget.dartColor ?? Tv.gold,
                        realistic: skin.realistic,
                        spin: _spin.value,
                        bust: widget.bust,
                        win: widget.win,
                      ),
                    ),
                  );
                },
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
  final bool realistic;
  final double spin; // 0 → 1 en boucle
  final bool bust;
  final bool win;
  final Set<int> litNumbers;
  final Set<int> aimNumbers;
  final List<(DartHit, Color, bool)> painted;
  _HitsPainter({
    required this.hits,
    this.painted = const [],
    this.targets = const [],
    this.litNumbers = const {},
    this.aimNumbers = const {},
    required this.impact,
    required this.pulse,
    required this.flash,
    required this.flashColor,
    required this.dartColor,
    this.realistic = false,
    this.spin = 0,
    this.bust = false,
    this.win = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final outer = size.width / 2;
    final r = outer - outer * 0.15; // même calcul que _BoardPainter
    if (painted.isNotEmpty) _paintZones(canvas, c, r);
    if (realistic) {
      _leds(canvas, c, outer, r);
      _numberLights(canvas, c, outer, r);
    }

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
      // Cible réaliste : le segment s'allume à la couleur du joueur, comme
      // sur une cible électronique
      final lit = realistic ? dartColor : Tv.goldLight;
      canvas.drawPath(
          path,
          Paint()
            ..color = lit.withValues(
                alpha: (realistic ? glow * 0.7 : glow).clamp(0, 1))
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

    // Fléchettes plantées, vues de face (ailettes fines numérotées) : les
    // plus anciennes d'abord, la dernière par-dessus
    for (var k = 0; k < hits.length; k++) {
      final last = k == hits.length - 1;
      _dartFace(canvas, dartPoint(c, r, hits[k], k + 1), r, k,
          last ? impact.clamp(0.0, 1.0) : 1.0);
    }

    // Éclair plein écran (bust en rouge, victoire en or)
    if (flash > 0 && flash < 1) {
      final a = math.sin(flash * math.pi) * 0.45;
      canvas.drawCircle(
          c, outer, Paint()..color = flashColor.withValues(alpha: a));
    }
  }

  /// Anneau de LED autour de la cible (comme la 3s) : une lumière qui
  /// tourne à la couleur du joueur, rouge sur un bust, arc-en-ciel à la
  /// victoire ; reflet de lumière qui glisse lentement.
  void _leds(Canvas canvas, Offset c, double outer, double r) {
    const n = 60;
    final ringR = outer * 0.972;
    final ledR = math.max(1.2, outer * 0.012);
    final phase = spin * 2 * math.pi;
    for (var i = 0; i < n; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / n;
      final p = c + Offset(math.cos(a), math.sin(a)) * ringR;
      Color col;
      double on;
      if (win) {
        col = HSVColor.fromAHSV(1, (i * 6 + spin * 360 * 2) % 360, 0.85, 1)
            .toColor();
        on = 0.85;
      } else if (bust) {
        col = Tv.red;
        on = 0.35 + 0.65 * pulse;
      } else {
        col = dartColor;
        // 2 « comètes » qui tournent
        final d = math.cos(a - phase);
        final d2 = math.cos(a - phase - math.pi);
        on = 0.18 + 0.82 * math.pow(math.max(0, math.max(d, d2)), 8).toDouble();
      }
      canvas.drawCircle(
          p,
          ledR * 2.6,
          Paint()
            ..color = col.withValues(alpha: 0.35 * on)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, ledR * 2));
      canvas.drawCircle(
          p,
          ledR,
          Paint()
            ..color = Color.lerp(const Color(0xFF202226), col, on)!
                .withValues(alpha: 1));
    }
    // Reflet qui glisse sur le plastique
    final la = phase / 3;
    final lc = Alignment(-0.5 + 0.25 * math.cos(la), -0.5 + 0.2 * math.sin(la));
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            center: lc,
            radius: 0.55,
            colors: [
              Colors.white.withValues(alpha: 0.07),
              Colors.transparent,
            ],
          ).createShader(Rect.fromCircle(center: c, radius: r)));
  }

  /// Jeux de lumière sur l'anneau des numéros : le numéro d'une zone
  /// touchée s'allume à la couleur du joueur et reste allumé pendant le
  /// tour (flash à l'impact), les numéros à viser clignotent en blanc, une
  /// petite lumière fait le tour quand rien n'est touché, tout passe au rouge
  /// sur un bust et en arc-en-ciel qui tourne à la victoire.
  void _numberLights(Canvas canvas, Offset c, double outer, double r) {
    const seg = 2 * math.pi / 20;
    final ri = r * 1.01, ro = outer * 0.95;
    final band = outer - r;
    final lit = <int, double>{}; // numéro → intensité
    for (var k = 0; k < hits.length; k++) {
      final h = hits[k];
      if (h.isBull) continue;
      final last = k == hits.length - 1;
      final boost = last && impact < 1 ? (1 - impact) * 0.6 : 0.0;
      lit[h.number] = math.max(lit[h.number] ?? 0, 0.75 + 0.15 * pulse + boost);
    }
    for (final n in litNumbers) {
      lit[n] = math.max(lit[n] ?? 0, 0.9);
    }
    final aim = {
      for (final t in targets)
        if (!t.isBull) t.number,
      ...aimNumbers,
    }..removeAll(lit.keys);
    final anyBull = hits.any((h) => h.isBull);
    final phase = spin * 20; // position de la lumière qui tourne
    for (var i = 0; i < 20; i++) {
      final n = kBoardOrder[i];
      final a0 = -math.pi / 2 - seg / 2 + i * seg;
      Color? col;
      var on = 0.0;
      if (win) {
        col = HSVColor.fromAHSV(1, (i * 18 + spin * 720) % 360, 0.85, 1)
            .toColor();
        on = 0.75;
      } else if (bust) {
        col = Tv.red;
        on = 0.25 + 0.55 * pulse;
      } else if (lit.containsKey(n)) {
        col = dartColor;
        on = lit[n]!.clamp(0.0, 1.0);
      } else if (anyBull) {
        // un bull fait briller tout l'anneau un instant
        col = dartColor;
        on = impact < 1 ? 0.45 * (1 - impact) : 0;
      } else if (hits.isEmpty && litNumbers.isEmpty && aimNumbers.isEmpty) {
        // attente : une lumière douce fait le tour
        final d = ((i - phase) % 20 + 20) % 20;
        on = d < 1 ? 0.35 * (1 - d) : (d > 19 ? 0.35 * (d - 19) : 0);
        col = dartColor;
      }
      final path = Path()
        ..arcTo(
            Rect.fromCircle(center: c, radius: ro), a0 + 0.02, seg - 0.04, true)
        ..arcTo(Rect.fromCircle(center: c, radius: ri), a0 + seg - 0.02,
            -(seg - 0.04), false)
        ..close();
      if (col != null && on > 0.01) {
        canvas.drawPath(
            path,
            Paint()
              ..color = col.withValues(alpha: 0.75 * on)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, band * 0.12));
        canvas.drawPath(
            path,
            Paint()
              ..color = col.withValues(alpha: 0.9 * on)
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(1, band * 0.05));
      }
      if (aim.contains(n) && !win && !bust) {
        canvas.drawPath(
            path,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.35 + 0.55 * pulse)
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(1, band * 0.06));
      }
      // Numéro redessiné par-dessus, lumineux quand sa zone est allumée
      if (on > 0.3 || aim.contains(n)) {
        final mid = a0 + seg / 2;
        final pos = c + Offset(math.cos(mid), math.sin(mid)) * (r + band / 2);
        final tp = TextPainter(
          text: TextSpan(
            text: '$n',
            style: TextStyle(
              fontFamily: Tv.font,
              fontWeight: FontWeight.w800,
              fontSize: band * 0.74,
              color: Colors.white,
              shadows: [
                Shadow(
                    color: (col ?? Colors.white).withValues(alpha: 0.9),
                    blurRadius: band * 0.25),
              ],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
      }
    }
  }

  /// Fléchette vue de face : 4 ailettes fines à la couleur du joueur
  /// (contour sombre), numéro de la fléchette au centre, ombre portée.
  /// [t] = arrivée (0 → 1) : elle arrive en grand puis se plante en
  /// tremblant.
  void _dartFace(Canvas canvas, Offset p, double r, int k, double t) {
    final arrive = Curves.easeIn.transform(t);
    // taille mini pour les petites cibles (Cricket)
    final s = math.max(r * 0.16, 14.0) * (1 + (1 - arrive) * 1.4);
    final wob = t < 1 ? 0.25 * math.sin(t * 22) * (1 - t) : 0.0;
    // Ombre (lumière en haut à gauche)
    canvas.drawCircle(
        p + Offset(s * 0.35, s * 0.35),
        s * 0.85,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.45 * arrive)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.3));
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(math.pi / 4 + k * 0.35 + wob);
    final wing = Path()
      ..moveTo(s * 0.1, 0)
      ..lineTo(s * 0.5, s * 0.125)
      ..lineTo(s, s * 0.1)
      ..lineTo(s, -s * 0.1)
      ..lineTo(s * 0.5, -s * 0.125)
      ..close();
    final fill = Paint()
      ..shader = LinearGradient(colors: [
        Color.lerp(dartColor, Colors.black, 0.4)!,
        dartColor,
        Color.lerp(dartColor, Colors.white, 0.3)!,
      ]).createShader(Rect.fromLTRB(0, 0, s, 1));
    final edge = Paint()
      ..color = Colors.black.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, s * 0.06)
      ..strokeJoin = StrokeJoin.round;
    for (var q = 0; q < 4; q++) {
      canvas.drawPath(wing, fill);
      canvas.drawPath(wing, edge);
      canvas.rotate(math.pi / 2);
    }
    canvas.restore();
    // Centre : pastille numérotée
    canvas.drawCircle(p, s * 0.3, Paint()..color = Colors.white);
    canvas.drawCircle(
        p, s * 0.25, Paint()..color = Color.lerp(dartColor, Colors.black, 0.3)!);
    final tp = TextPainter(
      text: TextSpan(
        text: '${k + 1}',
        style: TextStyle(
            fontFamily: Tv.font,
            fontWeight: FontWeight.w800,
            fontSize: s * 0.38,
            color: Colors.white,
            height: 1),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
  }

  /// Paint : zones à la couleur de leur joueur, bord blanc si protégées.
  void _paintZones(Canvas canvas, Offset c, double r) {
    for (final (h, color, locked) in painted) {
      final path = _zonePath(c, r, h);
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.82));
      canvas.drawPath(
          path,
          Paint()
            ..color = locked ? Colors.white : Colors.black54
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1, r * (locked ? 0.016 : 0.006)));
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
