// Bot : vise une zone selon le jeu, puis la fléchette part avec une
// dispersion (loi normale autour du point visé). La dispersion est réglée
// pour obtenir la moyenne (PPR) ou le MPR voulus, calqués sur les joueurs
// humains de la partie : leur rang au départ, puis ce qu'ils lancent
// vraiment pendant la partie, avec un léger rattrapage si l'écart au score
// devient trop grand.

import 'dart:math';

import '../granboard.dart';
import '../rank.dart';
import 'cricket.dart';
import 'darts_game.dart';
import 'match.dart';
import 'practice.dart';
import 'x01.dart';

/// Un bot est un invité (pas de stats, pas de compte) au préfixe propre.
bool isBotId(String id) => id.startsWith('guest-bot');

/// Numéros dans l'ordre de la cible, le 20 en haut, sens des aiguilles.
const kBoardOrder = [
  20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5, //
];

/// Note sur 20 (1 à 20) → valeur du tableau des rangs (inverse de
/// [bandRating]).
double bandValue(double rating, List<double> lo) {
  final r = rating.clamp(1.0, 20.0);
  final i = r.floor() - 1;
  if (i >= 19) return lo.last;
  return lo[i] + (r - (i + 1)) * (lo[i + 1] - lo[i]);
}

class Bot {
  Bot._();

  /// Note sur 20 prise pour un joueur inconnu (invité) : environ 40 de
  /// moyenne, 1,4 MPR.
  static const guestRating = 3.0;

  // ─── Lancer ───

  /// Point visé (rayon 0 à 1 = bord du double, angle en radians depuis le
  /// haut, sens des aiguilles) pour une zone.
  static Point<double> aimPoint(DartHit aim) {
    if (aim.isBull) return const Point(0, 0);
    final r = switch (aim.ring) {
      Ring.triple => 0.56,
      Ring.double => 0.93,
      Ring.singleInner => 0.31,
      _ => 0.745,
    };
    final a = kBoardOrder.indexOf(aim.number) * pi / 10;
    return Point(r * sin(a), -r * cos(a));
  }

  /// Zone touchée au point (x, y) ; null = hors cible.
  static DartHit? zoneAt(double x, double y) {
    final r = sqrt(x * x + y * y);
    if (r > 1) return null;
    if (r < 0.055) return const DartHit(25, 2, Ring.innerBull);
    if (r < 0.12) return const DartHit(25, 1, Ring.outerBull);
    var a = atan2(x, -y); // 0 en haut, sens des aiguilles
    if (a < 0) a += 2 * pi;
    final n = kBoardOrder[((a + pi / 20) / (pi / 10)).floor() % 20];
    if (r < 0.49) return DartHit(n, 1, Ring.singleInner);
    if (r < 0.63) return DartHit(n, 3, Ring.triple);
    if (r < 0.86) return DartHit(n, 1, Ring.singleOuter);
    return DartHit(n, 2, Ring.double);
  }

  static double _gauss(Random rnd) {
    final u = 1 - rnd.nextDouble();
    return sqrt(-2 * log(u)) * cos(2 * pi * rnd.nextDouble());
  }

  /// Une fléchette lancée vers [aim] avec la dispersion [sigma].
  static DartHit? throwAt(DartHit aim, double sigma, Random rnd) {
    final p = aimPoint(aim);
    return zoneAt(p.x + _gauss(rnd) * sigma, p.y + _gauss(rnd) * sigma);
  }

  // ─── Étalonnage : dispersion → PPR / MPR en visant le T20 ───

  static const _sigmas = [
    0.005, 0.02, 0.04, 0.06, 0.08, 0.10, 0.12, 0.14, 0.16, 0.19, 0.22, //
    0.26, 0.30, 0.35, 0.40, 0.46, 0.53, 0.62, 0.75, 0.9,
  ];
  static List<double>? _ppr, _mpr;

  static void _calibrate() {
    if (_ppr != null) return;
    final rnd = Random(7);
    const t20 = DartHit(20, 3, Ring.triple);
    const n = 3000;
    final ppr = <double>[], mpr = <double>[];
    for (final s in _sigmas) {
      var pts = 0, marks = 0;
      for (var i = 0; i < n; i++) {
        final h = throwAt(t20, s, rnd);
        if (h == null) continue;
        pts += h.score;
        if (h.number == 20) marks += h.multiplier;
      }
      ppr.add(pts * 3 / n);
      mpr.add(marks * 3 / n);
    }
    _ppr = ppr;
    _mpr = mpr;
  }

  /// Dispersion qui donne en moyenne [value] (PPR, ou MPR si [cricket]).
  static double sigmaFor(double value, {bool cricket = false}) {
    _calibrate();
    final t = cricket ? _mpr! : _ppr!; // décroissant avec la dispersion
    if (value >= t.first) return _sigmas.first;
    if (value <= t.last) return _sigmas.last;
    for (var i = 0; i < t.length - 1; i++) {
      if (value <= t[i] && value >= t[i + 1]) {
        final f = (t[i] - value) / (t[i] - t[i + 1]);
        return _sigmas[i] + f * (_sigmas[i + 1] - _sigmas[i]);
      }
    }
    return _sigmas.last;
  }

  /// PPR et MPR de l'étalonnage pour une dispersion (tests).
  static (double, double) levelOf(double sigma) {
    _calibrate();
    for (var i = 0; i < _sigmas.length - 1; i++) {
      if (sigma <= _sigmas[i + 1]) {
        final f = (sigma - _sigmas[i]) / (_sigmas[i + 1] - _sigmas[i]);
        return (
          _ppr![i] + f * (_ppr![i + 1] - _ppr![i]),
          _mpr![i] + f * (_mpr![i + 1] - _mpr![i]),
        );
      }
    }
    return (_ppr!.last, _mpr!.last);
  }

  // ─── Niveau : calqué sur les humains de la partie ───

  /// Niveau visé pour le bot qui joue : (PPR, MPR).
  /// [ratingOf] donne la note sur 20 d'un joueur (null = inconnu).
  static (double, double) target(
      DartsGame game, double? Function(String id) ratingOf) {
    final g = game is MatchGame ? game.leg : game;
    final humans = [
      for (var i = 0; i < g.players.length; i++)
        if (!isBotId(g.players[i].id)) i
    ];
    if (humans.isEmpty) {
      return (bandValue(8, kPprBounds), bandValue(8, kMprBounds));
    }
    var ppr = 0.0, mpr = 0.0;
    for (final i in humans) {
      final r = ratingOf(g.players[i].id) ?? guestRating;
      var p = bandValue(r, kPprBounds);
      var m = bandValue(r, kMprBounds);
      // Ce qu'il lance dans cette partie compte de plus en plus (à égalité
      // avec le rang après 4 manches)
      switch (g) {
        case X01Game x:
          final s = x.stateOf(i);
          if (s.darts > 0) {
            final w = s.darts / (s.darts + 12);
            p = p * (1 - w) + s.average * w;
            m = m * (1 - w) + s.average / 25 * w;
          }
        case CricketGame c:
          final s = c.statsOf(i);
          if (s.darts > 0) {
            final w = s.darts / (s.darts + 12);
            final live = s.marks * 3 / s.darts;
            m = m * (1 - w) + live * w;
            p = p * (1 - w) + live * 25 * w;
          }
        default:
      }
      ppr += p;
      mpr += m;
    }
    ppr /= humans.length;
    mpr /= humans.length;

    // Rattrapage : un bot trop loin devant lève le pied, trop loin derrière
    // force un peu
    final bot = g.current;
    switch (g) {
      case X01Game x:
        final mine = x.stateOf(bot).remaining;
        final best = humans.map((i) => x.stateOf(i).remaining).reduce(min);
        final gap = best - mine; // > 0 : le bot est devant
        if (gap > 80) ppr *= 0.85;
        if (gap < -80) ppr *= 1.12;
      case CricketGame c:
        final mine = c.scoreOf(c.sideOf(bot));
        final best = humans.map((i) => c.scoreOf(c.sideOf(i))).reduce(max);
        final gap = mine - best;
        final cut = c.settings.variant == CricketVariant.cutThroat ||
            c.settings.variant == CricketVariant.hiddenCutThroat;
        final ahead = cut ? gap < -60 : gap > 60;
        final behind = cut ? gap > 60 : gap < -60;
        if (ahead) mpr *= 0.85;
        if (behind) mpr *= 1.12;
      default:
    }
    return (ppr.clamp(12.0, 150.0), mpr.clamp(0.4, 6.0));
  }

  /// Dispersion à utiliser pour la prochaine fléchette du bot.
  static double sigmaNow(DartsGame game, double? Function(String id) ratingOf) {
    final (ppr, mpr) = target(game, ratingOf);
    final g = game is MatchGame ? game.leg : game;
    return g is CricketGame ? sigmaFor(mpr, cricket: true) : sigmaFor(ppr);
  }

  // ─── Visée selon le jeu ───

  static const _t20 = DartHit(20, 3, Ring.triple);

  /// Zone visée par le bot qui joue.
  static DartHit aim(DartsGame game, Random rnd) {
    final g = game is MatchGame ? game.leg : game;
    switch (g) {
      case X01Game x:
        return _aimX01(x);
      case CricketGame c:
        return _aimCricket(c, rnd);
      case PracticeGame p:
        final zones = p.targetZones;
        if (zones.isEmpty) return _t20;
        // la zone qui rapporte le plus (triple, puis double)
        final best = [...zones]
          ..sort((a, b) => b.multiplier.compareTo(a.multiplier));
        return best.first;
      default:
        return _t20;
    }
  }

  static DartHit _aimX01(X01Game x) {
    final s = x.currentState;
    if (!s.opened) {
      return x.settings.inRule == InRule.open
          ? _t20
          : const DartHit(20, 2, Ring.double);
    }
    final opts = x.checkoutOptions;
    if (opts.isNotEmpty && opts.first.isNotEmpty) {
      return _labelHit(opts.first.first);
    }
    final left = s.remaining;
    if (left > 60) return _t20;
    if (x.settings.outRule == OutRule.open) {
      return left <= 20 ? DartHit(left, 1, Ring.singleOuter) : _t20;
    }
    // pas de fin possible avec les fléchettes qui restent : laisser un double
    for (final keep in const [32, 16, 8, 4, 2]) {
      final want = left - keep;
      if (want >= 1 && want <= 20) return DartHit(want, 1, Ring.singleOuter);
    }
    return const DartHit(20, 1, Ring.singleOuter);
  }

  static DartHit _labelHit(String label) {
    if (label == 'BULL') return const DartHit(25, 2, Ring.innerBull);
    if (label == '25') return const DartHit(25, 1, Ring.outerBull);
    final n = int.tryParse(label.replaceFirst(RegExp('^[DT]'), '')) ?? 20;
    if (label.startsWith('T')) return DartHit(n, 3, Ring.triple);
    if (label.startsWith('D')) return DartHit(n, 2, Ring.double);
    return DartHit(n, 1, Ring.singleOuter);
  }

  static DartHit _aimCricket(CricketGame c, Random rnd) {
    final side = c.sideOf(c.current);
    DartHit hitOf(CricketTarget t) {
      if (!t.revealed) {
        return DartHit(1 + rnd.nextInt(20), 3, Ring.triple);
      }
      return switch (t.number) {
        25 => const DartHit(25, 2, Ring.innerBull),
        kDoublesTarget => const DartHit(20, 2, Ring.double),
        kTriplesTarget => _t20,
        _ => DartHit(t.number, 3, Ring.triple),
      };
    }

    final ts = c.targets;
    // d'abord fermer ses numéros (dans l'ordre), sauf ceux déjà morts
    for (var t = 0; t < ts.length; t++) {
      if (!c.dead(t) && !c.closedBy(side, t)) return hitOf(ts[t]);
    }
    // tout est fermé : marquer des points sur un numéro encore vivant
    for (var t = 0; t < ts.length; t++) {
      if (!c.dead(t)) return hitOf(ts[t]);
    }
    return _t20;
  }
}
