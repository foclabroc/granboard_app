// Jeux Party « arcade » (v0.6.27, d'après Arcade Darts) : Tir à la corde,
// Coffre-fort, Fight Club, Puissance 4, Serpents et échelles, Boules,
// Conquérant, Test Match, Snooker, 8 Ball Pool, Zombies.
//
// Même moteur que les autres jeux (PracticeGame) : l'état commun est dans
// `g.shared`, recalculé en rejouant le journal. Chaque jeu pose son dernier
// évènement (`shared['ev']` = {type, …, n}) pour que l'écran l'anime une
// seule fois (`n` = longueur du journal à ce moment).

part of 'practice.dart';

/// Ordre des numéros sur la cible (en partant du 20, sens horaire).
const kArcadeBoardOrder = [
  20,
  1,
  18,
  4,
  13,
  6,
  10,
  15,
  2,
  17,
  3,
  19,
  7,
  16,
  8,
  11,
  14,
  9,
  12,
  5,
];

void _event(PracticeGame g, String type, [Map<String, dynamic>? data]) {
  g.shared['ev'] = {'type': type, ...?data, 'n': g.actionLog.length};
}

int _num(DartHit h) => h.isBull ? 25 : h.number;

String _upper(PracticeGame g, int p) => g.players[p].name.toUpperCase();

const _t20 = DartHit(20, 3, Ring.triple);
const _bulls = [DartHit(25, 2, Ring.innerBull), DartHit(25, 1, Ring.outerBull)];

// ─── Tir à la corde ───

/// Joueurs pairs à gauche, impairs à droite. Les points du tour tirent la
/// corde vers son camp ; le premier camp qui l'amène à son but gagne.
class _Tug extends PracticeRules {
  _Tug(super.s);

  int get goal => s.goalOrDefault;
  static int rope(PracticeGame g) => (g.shared['rope'] as int?) ?? 0;

  /// Avance du camp du joueur (négatif = la corde part chez l'adversaire).
  int advance(PracticeGame g, int p) => p.isEven ? -rope(g) : rope(g);

  @override
  bool get goalEndsGame => true;
  @override
  int? roundLimit(PracticeGame g) => 30;
  @override
  String rulesLabel(PracticeGame g) => 'But à $goal points';
  @override
  String target(PracticeGame g, int p) =>
      p.isEven ? 'TIRE À GAUCHE' : 'TIRE À DROITE';
  @override
  List<DartHit> zones(PracticeGame g, int p) => const [_t20];
  @override
  String info(PracticeGame g, int p) =>
      'ÉCART ${advance(g, p)} / $goal · TOTAL ${g.stateOf(p).score}';
  @override
  String scoreText(PracticeGame g, int p) {
    final a = advance(g, p);
    return a > 0 ? '+$a' : '$a';
  }

  @override
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d) {
    final v = _value(d.hit, s.bull);
    if (v == 0) return;
    d.points = v;
    d.ok = true;
    final st = g.stateOf(p);
    st.score += v;
    final r = (rope(g) + (p.isEven ? -v : v)).clamp(-goal, goal);
    g.shared['rope'] = r;
    _event(g, 'pull', {'p': p, 'v': v});
    if (r.abs() >= goal) {
      for (var i = 0; i < g.players.length; i++) {
        if (i.isEven == p.isEven) g.stateOf(i).done = true;
      }
      t.note = p.isEven ? 'LA GAUCHE GAGNE !' : 'LA DROITE GAGNE !';
      if (g.players.length == 2) t.note = '${_upper(g, p)} GAGNE !';
      t.maxDarts = t.darts.length;
    }
  }

  @override
  int compare(PracticeGame g, int a, int b) =>
      advance(g, b).compareTo(advance(g, a));
}

// ─── Coffre-fort ───

/// Chaque manche, un code (10 à 50, le même pour tous) à faire descendre
/// à 0 pile en 3 fléchettes : le coffre rapporte le code. En dessous de 0,
/// ou pas à 0 : alarme, rien.
class _Vault extends PracticeRules {
  _Vault(super.s);

  int code(int round) => 10 + Random(s.seed * 31 + round * 7).nextInt(41);
  static int left(PracticeGame g, int p) => g.stateOf(p).v['left'] ?? 0;

  @override
  int? roundLimit(PracticeGame g) => s.roundsOrDefault;
  @override
  void onTurnStart(PracticeGame g, int p) {
    g.stateOf(p).v['left'] = code(g.round);
    g.stateOf(p).v['code'] = code(g.round);
  }

  @override
  String target(PracticeGame g, int p) {
    final l = left(g, p);
    return l > 0
        ? 'CODE $l'
        : l == 0
            ? 'OUVERT'
            : 'ALARME';
  }

  @override
  List<DartHit> zones(PracticeGame g, int p) {
    final l = left(g, p);
    if (l <= 0) return const [];
    final exact = <DartHit>[
      if (l <= 20) DartHit(l, 1, Ring.singleOuter),
      if (l.isEven && l <= 40) DartHit(l ~/ 2, 2, Ring.double),
      if (l % 3 == 0 && l <= 60) DartHit(l ~/ 3, 3, Ring.triple),
      if (l == 25) const DartHit(25, 1, Ring.outerBull),
      if (l == 50) const DartHit(25, 2, Ring.innerBull),
    ];
    if (exact.isNotEmpty) return exact;
    // pas de fin en 1 fléchette : descendre en laissant au moins 2
    final n = min(20, max(1, (l - 2) ~/ 3));
    return [DartHit(n, 3, Ring.triple)];
  }

  @override
  String info(PracticeGame g, int p) =>
      plural(g.stateOf(p).hits, 'coffre ouvert', 'coffres ouverts');
  @override
  String scoreText(PracticeGame g, int p) => '\$${g.stateOf(p).score}';

  @override
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d) {
    final st = g.stateOf(p);
    final l = left(g, p);
    if (l <= 0) return;
    final v = _value(d.hit, s.bull);
    if (v == 0) return;
    final rest = l - v;
    final code = st.v['code'] ?? 0;
    if (rest == 0) {
      st.v['left'] = 0;
      st.score += code;
      st.hits++;
      d.ok = true;
      d.points = code;
      t.note = 'COFFRE PILLÉ ! +\$$code';
      t.maxDarts = t.darts.length;
      _event(g, 'open', {'p': p, 'code': code});
    } else if (rest < 0) {
      st.v['left'] = -1;
      t.note = 'ALARME !';
      t.maxDarts = t.darts.length;
      _event(g, 'alarm', {'p': p});
    } else {
      st.v['left'] = rest;
      d.ok = true;
      _event(g, 'turn', {'p': p, 'left': rest});
    }
  }

  @override
  void onTurnEnd(PracticeGame g, int p, PracticeTurn t) {
    if (left(g, p) > 0) {
      t.note ??= 'ALARME : LE COFFRE RÉSISTE';
      _event(g, 'alarm', {'p': p});
    }
  }
}

// ─── Fight Club ───

/// 3 numéros par joueur : toucher ceux d'un adversaire le frappe
/// (10 × multiplicateur), les siens soignent (5 ×). Bull : coup sur tous les
/// adversaires (5 ou 10). Dernier debout gagne.
class _Fight extends PracticeRules {
  _Fight(super.s);

  int get maxHp => s.goalOrDefault;
  List<int> numbersOf(int p) =>
      _shuffled(s.seed * 13 + 7).sublist(p * 3, p * 3 + 3);
  int? ownerOf(PracticeGame g, int n) {
    for (var i = 0; i < g.players.length; i++) {
      if (numbersOf(i).contains(n)) return i;
    }
    return null;
  }

  @override
  void init(PracticeGame g, int p, PracticePlayer st) => st.score = maxHp;
  @override
  int? roundLimit(PracticeGame g) => 30;
  @override
  String rulesLabel(PracticeGame g) => '$maxHp PV';
  @override
  bool over(PracticeGame g) =>
      [for (var i = 0; i < g.players.length; i++) i]
          .where((i) => !g.stateOf(i).out)
          .length <=
      1;
  @override
  String target(PracticeGame g, int p) => 'TES N° ${numbersOf(p).join(' · ')}';

  @override
  List<DartHit> zones(PracticeGame g, int p) {
    // l'adversaire le plus faible
    int? weak;
    for (var i = 0; i < g.players.length; i++) {
      if (i == p || g.stateOf(i).out) continue;
      if (weak == null || g.stateOf(i).score < g.stateOf(weak).score) weak = i;
    }
    if (weak == null) return const [];
    return [for (final n in numbersOf(weak)) DartHit(n, 3, Ring.triple)];
  }

  @override
  String info(PracticeGame g, int p) => 'N° ${numbersOf(p).join(' · ')}';
  @override
  String scoreText(PracticeGame g, int p) => '${g.stateOf(p).score} PV';

  void _hurt(PracticeGame g, int p, int o, int dmg, PracticeTurn t) {
    final q = g.stateOf(o);
    q.score = max(0, q.score - dmg);
    g.stateOf(p).hits += dmg;
    if (q.score == 0) {
      q.out = true;
      t.note = 'K.O. ! ${_upper(g, o)} EST AU TAPIS';
    }
  }

  @override
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d) {
    final h = d.hit;
    if (h == null) return;
    final st = g.stateOf(p);
    final n = _num(h);
    if (n == 25) {
      final dmg = h.ring == Ring.innerBull ? 10 : 5;
      final hit = <int>[];
      for (var o = 0; o < g.players.length; o++) {
        if (o == p || g.stateOf(o).out) continue;
        _hurt(g, p, o, dmg, t);
        hit.add(o);
      }
      d.ok = true;
      d.points = dmg;
      t.note ??= 'ONDE DE CHOC : -$dmg POUR TOUS';
      _event(g, 'blast', {'p': p, 'dmg': dmg, 'to': hit});
      return;
    }
    final o = ownerOf(g, n);
    if (o == null) return;
    if (o == p) {
      final heal = min(5 * h.multiplier, maxHp - st.score);
      if (heal <= 0) return;
      st.score += heal;
      d.ok = true;
      d.points = heal;
      t.note = 'SOIN +$heal';
      _event(g, 'heal', {'p': p, 'v': heal});
      return;
    }
    if (g.stateOf(o).out) return;
    final dmg = 10 * h.multiplier;
    d.ok = true;
    d.points = dmg;
    t.note = h.multiplier == 3
        ? 'UPPERCUT SUR ${_upper(g, o)} ! -$dmg'
        : '-$dmg POUR ${_upper(g, o)}';
    _hurt(g, p, o, dmg, t);
    _event(g, 'hit', {'p': p, 'o': o, 'dmg': dmg, 'm': h.multiplier});
  }

  @override
  int compare(PracticeGame g, int a, int b) {
    final o = (g.stateOf(a).out ? 1 : 0) - (g.stateOf(b).out ? 1 : 0);
    if (o != 0) return o;
    return g.stateOf(b).score.compareTo(g.stateOf(a).score);
  }
}

/// Numéros de chaque joueur (Fight Club).
List<List<int>> fightNumbers(PracticeGame g) {
  final r = g.rules;
  if (r is! _Fight) return const [];
  return [for (var i = 0; i < g.players.length; i++) r.numbersOf(i)];
}

// ─── Puissance 4 ───

/// Le numéro touché choisit la colonne : (n - 1) % 7, bull = 7e colonne.
class _Connect4 extends PracticeRules {
  _Connect4(super.s);

  static const cols = 7, rows = 6;
  static int columnOf(int n) => n == 25 ? 6 : (n - 1) % 7;
  static List<int> numbersOfColumn(int c) =>
      c == 6 ? const [7, 14, 25] : [for (var n = c + 1; n <= 20; n += 7) n];

  static List<int> cells(PracticeGame g) =>
      (g.shared['c4'] as List<int>?) ?? List.filled(cols * rows, -1);

  @override
  void init(PracticeGame g, int p, PracticePlayer st) {
    if (p == 0) g.shared['c4'] = List.filled(cols * rows, -1);
  }

  @override
  bool get goalEndsGame => true;
  @override
  int? roundLimit(PracticeGame g) => 30;
  @override
  String rulesLabel(PracticeGame g) => 'Grille 7 × 6';
  @override
  bool over(PracticeGame g) => !cells(g).contains(-1);
  @override
  String target(PracticeGame g, int p) => 'ALIGNE 4 PIONS';
  @override
  String info(PracticeGame g, int p) =>
      plural(cells(g).where((c) => c == p).length, 'pion');
  @override
  String scoreText(PracticeGame g, int p) =>
      g.stateOf(p).done ? '4 !' : '${cells(g).where((c) => c == p).length}';

  static int? _drop(List<int> c, int col) {
    for (var r = rows - 1; r >= 0; r--) {
      if (c[r * cols + col] == -1) return r;
    }
    return null;
  }

  static List<int>? line(List<int> c, int p) {
    const dirs = [(0, 1), (1, 0), (1, 1), (1, -1)];
    for (var r = 0; r < rows; r++) {
      for (var k = 0; k < cols; k++) {
        for (final (dr, dk) in dirs) {
          final cellsOf = <int>[];
          for (var i = 0; i < 4; i++) {
            final rr = r + dr * i, kk = k + dk * i;
            if (rr < 0 || rr >= rows || kk < 0 || kk >= cols) break;
            if (c[rr * cols + kk] != p) break;
            cellsOf.add(rr * cols + kk);
          }
          if (cellsOf.length == 4) return cellsOf;
        }
      }
    }
    return null;
  }

  @override
  List<DartHit> zones(PracticeGame g, int p) {
    final c = cells(g);
    int? pick;
    // gagner, sinon bloquer, sinon le centre
    for (final who in [p, 1 - p]) {
      for (var k = 0; k < cols && pick == null; k++) {
        final r = _drop(c, k);
        if (r == null) continue;
        final copy = [...c]..[r * cols + k] = who;
        if (line(copy, who) != null) pick = k;
      }
      if (pick != null) break;
    }
    for (final k in [3, 2, 4, 1, 5, 0, 6]) {
      if (pick != null) break;
      if (_drop(c, k) != null) pick = k;
    }
    if (pick == null) return const [];
    return [
      for (final n in numbersOfColumn(pick))
        n == 25
            ? const DartHit(25, 1, Ring.outerBull)
            : DartHit(n, 3, Ring.triple)
    ];
  }

  @override
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d) {
    final h = d.hit;
    if (h == null) return;
    final c = [...cells(g)];
    final col = columnOf(_num(h));
    final r = _drop(c, col);
    if (r == null) {
      t.note = 'COLONNE ${col + 1} PLEINE';
      return;
    }
    c[r * cols + col] = p;
    g.shared['c4'] = c;
    d.ok = true;
    d.points = 1;
    g.stateOf(p).score = c.where((x) => x == p).length;
    _event(g, 'drop', {'p': p, 'col': col, 'row': r});
    final l = line(c, p);
    if (l != null) {
      g.shared['c4w'] = l;
      g.stateOf(p).done = true;
      t.note = 'PUISSANCE 4 !';
      t.maxDarts = t.darts.length;
    }
  }

  @override
  int compare(PracticeGame g, int a, int b) =>
      (g.stateOf(a).done ? 0 : 1) - (g.stateOf(b).done ? 0 : 1);
}

/// Grille du Puissance 4 (-1 = vide) et alignement gagnant.
(List<int>, List<int>?) connect4State(PracticeGame g) => (
      _Connect4.cells(g),
      (g.shared['c4w'] as List<int>?),
    );
int connect4Column(int n) => _Connect4.columnOf(n);
List<int> connect4Numbers(int col) => _Connect4.numbersOfColumn(col);

// ─── Serpents et échelles ───

/// L'anneau touché fait avancer (bull 6, 25 5, simple extérieur 4, triple 3,
/// simple intérieur 2, double 1). Case 100 pile pour gagner.
class _Snakes extends PracticeRules {
  _Snakes(super.s);

  static const ladders = {
    4: 25,
    13: 46,
    33: 49,
    42: 63,
    50: 69,
    62: 81,
    74: 92
  };
  static const snakes = {
    27: 5,
    40: 3,
    43: 18,
    54: 31,
    66: 45,
    76: 58,
    89: 53,
    99: 41
  };

  static int moves(DartHit? h) => switch (h?.ring) {
        null => 0,
        Ring.innerBull => 6,
        Ring.outerBull => 5,
        Ring.singleOuter => 4,
        Ring.triple => 3,
        Ring.singleInner => 2,
        Ring.double => 1,
      };

  @override
  bool get goalEndsGame => true;
  @override
  int? roundLimit(PracticeGame g) => 60;
  @override
  String rulesLabel(PracticeGame g) => 'Case 100 pile';
  @override
  String target(PracticeGame g, int p) => 'CASE ${g.stateOf(p).score}';
  @override
  String info(PracticeGame g, int p) => 'CASE ${g.stateOf(p).score}/100';
  @override
  String scoreText(PracticeGame g, int p) => '${g.stateOf(p).score}';

  @override
  List<DartHit> zones(PracticeGame g, int p) {
    final r = 100 - g.stateOf(p).score;
    return switch (r) {
      1 => const [DartHit(20, 2, Ring.double)],
      2 => const [DartHit(20, 1, Ring.singleInner)],
      3 => const [_t20],
      4 => const [DartHit(20, 1, Ring.singleOuter)],
      5 => const [DartHit(25, 1, Ring.outerBull)],
      _ => const [DartHit(20, 1, Ring.singleOuter)],
    };
  }

  @override
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d) {
    final st = g.stateOf(p);
    final m = moves(d.hit);
    if (m == 0 || st.done) return;
    final from = st.score;
    var land = from + m;
    if (land > 100) land = 200 - land;
    var end = land;
    String? via;
    if (ladders[land] case final int up) {
      end = up;
      via = 'ladder';
      t.note = 'ÉCHELLE ! $land → $up';
    } else if (snakes[land] case final int down) {
      end = down;
      via = 'snake';
      t.note = 'SERPENT ! $land → $down';
    }
    st.score = end;
    d.ok = true;
    d.points = m;
    _event(g, 'move', {
      'p': p,
      'm': m,
      'from': from,
      'land': land,
      'to': end,
      if (via != null) 'via': via,
    });
    if (end == 100) {
      st.done = true;
      t.note = 'CASE 100 !';
      t.maxDarts = t.darts.length;
    }
  }

  @override
  int compare(PracticeGame g, int a, int b) {
    final d = g.stateOf(b).score.compareTo(g.stateOf(a).score);
    if (d != 0) return d;
    final ra = g.stateOf(a).doneRound ?? 1 << 20,
        rb = g.stateOf(b).doneRound ?? 1 << 20;
    return ra.compareTo(rb);
  }
}

const kSnakesLadders = _Snakes.ladders;
const kSnakesSnakes = _Snakes.snakes;
int snakesMoves(DartHit? h) => _Snakes.moves(h);

// ─── Boules ───

/// Chacun son tour 1 fléchette, 3 par joueur et par mène. La plus près du
/// centre gagne la mène : 1 point par boule plus près que la meilleure
/// adverse. Distance = anneau (bull, 25, simple intérieur, triple, simple
/// extérieur, double, raté).
class _Bowls extends PracticeRules {
  _Bowls(super.s);

  int get ends => s.goalOrDefault;
  static int dist(DartHit? h) => switch (h?.ring) {
        null => 6,
        Ring.innerBull => 0,
        Ring.outerBull => 1,
        Ring.singleInner => 2,
        Ring.triple => 3,
        Ring.singleOuter => 4,
        Ring.double => 5,
      };

  /// Mène en cours (1…) et boule du joueur (0-2).
  static int endOf(int round) => (round - 1) ~/ 3 + 1;
  static int ballOf(int round) => (round - 1) % 3;

  @override
  int? roundLimit(PracticeGame g) => ends * 3;
  @override
  String rulesLabel(PracticeGame g) => plural(ends, 'mène');
  @override
  String target(PracticeGame g, int p) =>
      'MÈNE ${endOf(g.round)} · BOULE ${ballOf(g.round) + 1}/3';
  @override
  List<DartHit> zones(PracticeGame g, int p) => [_bulls[0]];
  @override
  String info(PracticeGame g, int p) => plural(g.stateOf(p).score, 'point');

  @override
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d) {
    t.maxDarts = 1;
    final st = g.stateOf(p);
    final k = ballOf(g.round);
    final ds = dist(d.hit);
    st.v['b$k'] = ds;
    st.v['n$k'] = d.hit == null ? 0 : _num(d.hit!);
    st.v['e$k'] = endOf(g.round);
    d.ok = ds < 6;
    _event(g, 'ball', {'p': p, 'k': k, 'd': ds});
  }

  /// Distance de la boule k dans la mène [end] (6 = pas jouée).
  static int ballDist(PracticePlayer st, int k, int end) =>
      st.v['e$k'] == end ? (st.v['b$k'] ?? 6) : 6;

  static int best(PracticePlayer st, int end) {
    var b = 6;
    for (var k = 0; k < 3; k++) {
      b = min(b, ballDist(st, k, end));
    }
    return b;
  }

  @override
  void onTurnEnd(PracticeGame g, int p, PracticeTurn t) {
    if (ballOf(g.round) != 2 || p != g.players.length - 1) return;
    final e = endOf(g.round);
    final bests = [
      for (var i = 0; i < g.players.length; i++) best(g.stateOf(i), e)
    ];
    final top = bests.reduce(min);
    final who = [
      for (var i = 0; i < bests.length; i++)
        if (bests[i] == top) i
    ];
    final ends = [...(g.shared['ends'] as List? ?? const [])];
    if (who.length != 1 || top >= 6) {
      t.note = 'MÈNE NULLE';
      ends.add([-1, 0]);
      _event(g, 'end', {'w': -1, 'shots': 0, 'e': e});
    } else {
      final w = who.single;
      final second = [
        for (var i = 0; i < bests.length; i++)
          if (i != w) bests[i]
      ].reduce(min);
      final st = g.stateOf(w);
      var shots = 0;
      for (var k = 0; k < 3; k++) {
        if (ballDist(st, k, e) < second) shots++;
      }
      st.score += shots;
      st.hits++;
      t.note = 'MÈNE POUR ${_upper(g, w)} : +$shots';
      ends.add([w, shots]);
      _event(g, 'end', {'w': w, 'shots': shots, 'e': e});
    }
    g.shared['ends'] = ends;
  }
}

/// Boules posées dans la mène [end] (en cours par défaut) : (joueur,
/// n° de boule, distance 0-6, numéro touché).
List<(int, int, int, int)> bowlsBalls(PracticeGame g, {int? end}) {
  final e = end ?? _Bowls.endOf(g.round);
  return [
    for (var i = 0; i < g.players.length; i++)
      for (var k = 0; k < 3; k++)
        if (g.stateOf(i).v['e$k'] == e)
          (i, k, g.stateOf(i).v['b$k'] ?? 6, g.stateOf(i).v['n$k'] ?? 0)
  ];
}

// ─── Conquérant ───

/// Chacun part de sa base ; on ne prend ou n'attaque que les numéros
/// voisins (sur la cible) de ses régions. Région grise : prise. Région
/// adverse : un bouclier cassé, à 0 elle est volée. Sa région : +1
/// bouclier (3 max). Le bull (hub) se prend comme une région et, tenu,
/// permet d'attaquer partout. Multiplicateur = nombre de coups.
class _Conqueror extends PracticeRules {
  _Conqueror(super.s);

  static Map<int, int> owners(PracticeGame g) =>
      (g.shared['own'] as Map<int, int>?) ?? const {};
  static Map<int, int> shields(PracticeGame g) =>
      (g.shared['sh'] as Map<int, int>?) ?? const {};

  @override
  void init(PracticeGame g, int p, PracticePlayer st) {
    if (p == 0) {
      g.shared['own'] = <int, int>{};
      g.shared['sh'] = <int, int>{};
    }
    final off = Random(s.seed * 23 + 1).nextInt(20);
    final base = kArcadeBoardOrder[(off + p * 20 ~/ g.players.length) % 20];
    (g.shared['own'] as Map<int, int>)[base] = p;
    (g.shared['sh'] as Map<int, int>)[base] = 1;
    st.v['base'] = base;
    _rescore(g);
  }

  static bool canReach(PracticeGame g, int p, int n) {
    final own = owners(g);
    if (n == 25 || own[n] == p || own[25] == p) return true;
    final i = kArcadeBoardOrder.indexOf(n);
    if (i < 0) return false;
    return own[kArcadeBoardOrder[(i + 1) % 20]] == p ||
        own[kArcadeBoardOrder[(i + 19) % 20]] == p;
  }

  static List<int> reachable(PracticeGame g, int p) => [
        for (final n in [...kArcadeBoardOrder, 25])
          if (owners(g)[n] != p && canReach(g, p, n)) n
      ];

  void _rescore(PracticeGame g) {
    final own = owners(g), sh = shields(g);
    for (var i = 0; i < g.players.length; i++) {
      final mine = own.entries.where((e) => e.value == i).map((e) => e.key);
      final st = g.stateOf(i);
      st.hits = mine.length;
      st.v['shields'] = mine.fold(0, (s, n) => s + (sh[n] ?? 0));
      st.score = st.hits * 10 + st.v['shields']!;
    }
  }

  @override
  int? roundLimit(PracticeGame g) => s.roundsOrDefault;
  @override
  String target(PracticeGame g, int p) {
    final r = reachable(g, p);
    return r.isEmpty
        ? 'RENFORCE'
        : 'PORTÉE : ${r.take(5).map(_numLabel).join(' · ')}';
  }

  @override
  List<DartHit> zones(PracticeGame g, int p) {
    final own = owners(g), sh = shields(g);
    final r = reachable(g, p);
    final neutral = r.where((n) => own[n] == null).toList();
    final pick = neutral.isNotEmpty
        ? neutral
        : (r..sort((a, b) => (sh[a] ?? 0).compareTo(sh[b] ?? 0)));
    if (pick.isEmpty) return [_bulls[1]];
    return [
      for (final n in pick.take(3))
        n == 25
            ? const DartHit(25, 2, Ring.innerBull)
            : DartHit(n, 3, Ring.triple)
    ];
  }

  @override
  String info(PracticeGame g, int p) {
    final st = g.stateOf(p);
    return '${plural(st.hits, 'région')} · ${plural(st.v['shields'] ?? 0, 'bouclier')}';
  }

  @override
  String scoreText(PracticeGame g, int p) => '${g.stateOf(p).hits}';

  @override
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d) {
    final h = d.hit;
    if (h == null) return;
    final n = _num(h);
    if (!canReach(g, p, n)) {
      t.note = 'LE ${_numLabel(n)} EST HORS DE PORTÉE';
      return;
    }
    final own = Map<int, int>.from(owners(g));
    final sh = Map<int, int>.from(shields(g));
    final k = n == 25 ? (h.ring == Ring.innerBull ? 2 : 1) : h.multiplier;
    var kind = '';
    for (var i = 0; i < k; i++) {
      final o = own[n];
      if (o == p) {
        if ((sh[n] ?? 0) < 3) {
          sh[n] = (sh[n] ?? 0) + 1;
          kind = kind.isEmpty ? 'shield' : kind;
        }
      } else if (o == null) {
        own[n] = p;
        sh[n] = 0;
        kind = 'claim';
      } else if ((sh[n] ?? 0) > 0) {
        sh[n] = sh[n]! - 1;
        kind = 'break';
      } else {
        own[n] = p;
        sh[n] = 0;
        kind = 'steal';
        t.note = '${_upper(g, p)} VOLE LE ${_numLabel(n)} !';
      }
    }
    g.shared['own'] = own;
    g.shared['sh'] = sh;
    _rescore(g);
    if (kind.isEmpty) return;
    d.ok = true;
    d.points = k;
    if (kind == 'claim') {
      t.note = n == 25
          ? 'LE HUB EST À ${_upper(g, p)} !'
          : '${_upper(g, p)} PREND LE $n';
    }
    _event(g, kind, {'p': p, 'num': n});
  }
}

/// Propriétaire et boucliers de chaque région (Conquérant), et numéros
/// attaquables par le joueur en cours.
(Map<int, int>, Map<int, int>, List<int>) conquerorState(PracticeGame g) => (
      _Conqueror.owners(g),
      _Conqueror.shields(g),
      g.finished ? const [] : _Conqueror.reachable(g, g.current),
    );

// ─── Test Match (cricket, le sport) ───

/// 2 joueurs, 2 manches. Au bâton : seuls les points au-dessus de 40 par
/// visite deviennent des courses. Au lancer : 25 = 1 guichet, bull = 2.
/// Une manche s'arrête au nombre de guichets choisi ou après 8 visites.
class _TestCricket extends PracticeRules {
  _TestCricket(super.s);

  static const visits = 8;
  int get wickets => s.goalOrDefault;
  static int innings(PracticeGame g) => (g.shared['inn'] as int?) ?? 1;
  static int batter(PracticeGame g) => innings(g) == 1 ? 0 : 1;
  static int fallen(PracticeGame g) => (g.shared['w'] as int?) ?? 0;
  static int visitsDone(PracticeGame g) => (g.shared['vis'] as int?) ?? 0;

  @override
  int? roundLimit(PracticeGame g) => 2 * visits + 2;
  @override
  String rulesLabel(PracticeGame g) => '$wickets guichets · $visits visites';
  @override
  bool over(PracticeGame g) => g.shared['over'] == true;

  @override
  String target(PracticeGame g, int p) =>
      p == batter(g) ? 'AU BÂTON : AU-DESSUS DE 40' : 'AU LANCER : 25 / BULL';
  @override
  List<DartHit> zones(PracticeGame g, int p) =>
      p == batter(g) ? const [_t20] : _bulls;
  @override
  String info(PracticeGame g, int p) => p == batter(g)
      ? 'AU BÂTON · ${fallen(g)}/$wickets GUICHETS · VISITE ${visitsDone(g) + 1}/$visits'
      : 'AU LANCER · ${fallen(g)}/$wickets GUICHETS';
  @override
  String scoreText(PracticeGame g, int p) => '${g.stateOf(p).score}';

  @override
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d) {
    final h = d.hit;
    if (p == batter(g)) {
      final v = _value(h, s.bull);
      d.points = v;
      d.ok = v > 0;
      final total = t.points;
      _event(g, 'bat', {'p': p, 'v': v, 'total': total});
      return;
    }
    if (h == null || !h.isBull) return;
    final w = h.ring == Ring.innerBull ? 2 : 1;
    g.shared['w'] = fallen(g) + w;
    d.ok = true;
    d.points = w;
    t.note = w == 2 ? 'DOUBLE GUICHET !' : 'GUICHET !';
    _event(g, 'wicket', {'p': p, 'w': w});
  }

  void _close(PracticeGame g, PracticeTurn t) {
    if (innings(g) == 1) {
      g.shared['inn'] = 2;
      g.shared['w'] = 0;
      g.shared['vis'] = 0;
      final target = g.stateOf(0).score + 1;
      t.note = 'FIN DE LA 1RE MANCHE · ${_upper(g, 1)} DOIT FAIRE $target';
      _event(g, 'innings', {'target': target});
    } else {
      g.shared['over'] = true;
    }
  }

  @override
  void onTurnEnd(PracticeGame g, int p, PracticeTurn t) {
    final inn = innings(g);
    if (p == batter(g)) {
      final runs = max(0, t.points - 40);
      final st = g.stateOf(p);
      st.score += runs;
      st.hits++;
      g.shared['vis'] = visitsDone(g) + 1;
      t.note ??= runs > 0 ? '+$runs COURSES' : 'PAS DE COURSE (${t.points})';
      _event(g, 'runs', {'p': p, 'runs': runs});
      if (inn == 2 &&
          (st.score > g.stateOf(0).score || visitsDone(g) >= visits)) {
        g.shared['over'] = true;
      }
    } else if (fallen(g) >= wickets || (inn == 1 && visitsDone(g) >= visits)) {
      _close(g, t);
    }
  }
}

/// Manche (1 ou 2), batteur, guichets tombés, visites (Test Match).
(int, int, int, int) testMatchState(PracticeGame g) => (
      _TestCricket.innings(g),
      _TestCricket.batter(g),
      _TestCricket.fallen(g),
      _TestCricket.visitsDone(g),
    );

// ─── Snooker ───

/// Phase 1 : une rouge (1-15), puis une couleur (16 jaune … bull noir),
/// les couleurs reviennent. Phase 2 : les couleurs dans l'ordre. Faute
/// (raté, mauvais numéro) : 4 points ou plus pour l'adversaire, tour fini.
class _Snooker extends PracticeRules {
  _Snooker(super.s);

  static const colors = [16, 17, 18, 19, 20, 25];
  static int valueOf(int n) => n <= 15 ? 1 : colors.indexOf(n) + 2;

  static List<int> reds(PracticeGame g) =>
      (g.shared['reds'] as List<int>?) ?? [for (var i = 1; i <= 15; i++) i];
  static String want(PracticeGame g) => (g.shared['want'] as String?) ?? 'red';
  static int nextColor(PracticeGame g) => (g.shared['col'] as int?) ?? 0;

  @override
  void init(PracticeGame g, int p, PracticePlayer st) {
    if (p == 0) {
      g.shared['reds'] = [for (var i = 1; i <= 15; i++) i];
      g.shared['want'] = 'red';
      g.shared['col'] = 0;
    }
  }

  @override
  int? roundLimit(PracticeGame g) => 40;
  @override
  String rulesLabel(PracticeGame g) => '15 rouges';
  @override
  bool over(PracticeGame g) => nextColor(g) >= colors.length;

  @override
  void onTurnStart(PracticeGame g, int p) {
    g.shared['want'] = reds(g).isEmpty ? 'final' : 'red';
    g.stateOf(p).v['brk'] = 0;
  }

  static String ballName(int n) => switch (n) {
        16 => 'JAUNE',
        17 => 'VERTE',
        18 => 'MARRON',
        19 => 'BLEUE',
        20 => 'ROSE',
        25 => 'NOIRE',
        _ => 'ROUGE',
      };

  @override
  String target(PracticeGame g, int p) => switch (want(g)) {
        'red' => 'UNE ROUGE (1-15)',
        'color' => 'UNE COULEUR (16-BULL)',
        _ => nextColor(g) < colors.length
            ? 'LA ${ballName(colors[nextColor(g)])} (${_numLabel(colors[nextColor(g)])})'
            : 'TABLE VIDE',
      };

  @override
  List<DartHit> zones(PracticeGame g, int p) => switch (want(g)) {
        'red' => [for (final n in reds(g).take(4)) DartHit(n, 3, Ring.triple)],
        'color' => const [_t20],
        _ => nextColor(g) < colors.length
            ? _numberZones(colors[nextColor(g)])
            : const [],
      };

  @override
  String info(PracticeGame g, int p) =>
      'BREAK ${g.stateOf(p).v['brk'] ?? 0} · ${plural(reds(g).length, 'rouge')}';

  void _foul(PracticeGame g, int p, PracticeTurn t, int on) {
    final pen = max(4, on);
    final o = (p + 1) % g.players.length;
    g.stateOf(o).score += pen;
    t.note = 'FAUTE : +$pen POUR ${_upper(g, o)}';
    t.maxDarts = t.darts.length;
    _event(g, 'foul', {'p': p, 'o': o, 'pen': pen});
  }

  @override
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d) {
    final st = g.stateOf(p);
    final n = d.hit == null ? null : _num(d.hit!);
    final w = want(g);
    void pot(int ball, int v) {
      st.score += v;
      st.v['brk'] = (st.v['brk'] ?? 0) + v;
      st.hits++;
      d.ok = true;
      d.points = v;
      _event(g, 'pot', {'p': p, 'ball': ball, 'v': v});
      final b = st.v['brk']!;
      if (b >= 20 && t.note == null) t.note = 'BREAK DE $b !';
    }

    if (w == 'red') {
      final r = reds(g);
      if (n != null && r.contains(n)) {
        g.shared['reds'] = [...r]..remove(n);
        g.shared['want'] = 'color';
        pot(n, 1);
      } else {
        _foul(g, p, t, 4);
      }
    } else if (w == 'color') {
      if (n != null && colors.contains(n)) {
        g.shared['want'] = reds(g).isEmpty ? 'final' : 'red';
        pot(n, valueOf(n));
      } else {
        _foul(g, p, t, 7);
      }
    } else {
      final i = nextColor(g);
      if (i >= colors.length) return;
      if (n == colors[i]) {
        g.shared['col'] = i + 1;
        pot(n!, valueOf(n));
        if (i + 1 >= colors.length) {
          t.note = 'TABLE VIDÉE !';
          t.maxDarts = t.darts.length;
        }
      } else {
        _foul(g, p, t, valueOf(colors[i]));
      }
    }
  }
}

/// Rouges restantes, ce qu'il faut viser (red | color | final) et la
/// prochaine couleur de la phase 2 (Snooker).
(List<int>, String, int) snookerState(PracticeGame g) =>
    (_Snooker.reds(g), _Snooker.want(g), _Snooker.nextColor(g));
const kSnookerColors = _Snooker.colors;

// ─── 8 Ball Pool ───

/// 7 numéros par joueur. Tant qu'on en touche un des siens, on garde la
/// main (3 fléchettes de plus) ; un raté finit le tour. Les 7 empochés :
/// le bull (la 8) gagne. Option difficile : 4 billes en double ou triple.
class _Pool extends PracticeRules {
  _Pool(super.s);

  List<int> ballsOf(int p) =>
      _shuffled(s.seed * 17 + 11).sublist(p * 7, p * 7 + 7);
  bool get hard => s.has('hard');

  /// La bille demande un double ou un triple (option difficile).
  bool strong(int i) => hard && i < 4;
  static int potted(PracticePlayer st) => st.v['pot'] ?? 0;
  static bool isPotted(PracticePlayer st, int i) => potted(st) & (1 << i) != 0;
  static int count(PracticePlayer st) {
    var c = 0;
    for (var i = 0; i < 7; i++) {
      if (isPotted(st, i)) c++;
    }
    return c;
  }

  @override
  bool get goalEndsGame => true;
  @override
  int? roundLimit(PracticeGame g) => 30;
  @override
  String rulesLabel(PracticeGame g) => hard ? 'Difficile' : '7 billes + la 8';

  List<int> left(PracticeGame g, int p) {
    final st = g.stateOf(p);
    final b = ballsOf(p);
    return [
      for (var i = 0; i < 7; i++)
        if (!isPotted(st, i)) b[i]
    ];
  }

  @override
  String target(PracticeGame g, int p) {
    final l = left(g, p);
    return l.isEmpty ? 'LA 8 : BULL' : 'TES BILLES : ${l.join(' · ')}';
  }

  @override
  List<DartHit> zones(PracticeGame g, int p) {
    final st = g.stateOf(p);
    final b = ballsOf(p);
    if (count(st) == 7) return _bulls;
    return [
      for (var i = 0; i < 7; i++)
        if (!isPotted(st, i))
          strong(i)
              ? DartHit(b[i], 3, Ring.triple)
              : DartHit(b[i], 1, Ring.singleOuter)
    ];
  }

  @override
  String info(PracticeGame g, int p) =>
      '${count(g.stateOf(p))}/7 · ${plural(g.stateOf(p).darts, 'fléchette')}';
  @override
  String scoreText(PracticeGame g, int p) =>
      g.stateOf(p).done ? '8 !' : '${count(g.stateOf(p))}/7';

  @override
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d) {
    final st = g.stateOf(p);
    if (st.done) return;
    final h = d.hit;
    void endTurn() {
      if (t.okCount > 0 && t.note == null) {
        t.note = 'FIN DE SÉRIE (${t.okCount})';
      }
      t.maxDarts = t.darts.length;
    }

    if (h == null) return endTurn();
    final n = _num(h);
    if (count(st) == 7) {
      if (n == 25) {
        st.done = true;
        st.score = 8;
        d.ok = true;
        t.note = 'LA 8 EST DANS LE TROU !';
        t.maxDarts = t.darts.length;
        _event(g, 'eight', {'p': p});
        return;
      }
      return endTurn();
    }
    final b = ballsOf(p);
    final i = b.indexOf(n);
    if (i < 0 || isPotted(st, i) || (strong(i) && h.multiplier < 2)) {
      return endTurn();
    }
    st.v['pot'] = potted(st) | (1 << i);
    st.score = count(st);
    d.ok = true;
    d.points = 1;
    _event(g, 'pot', {'p': p, 'ball': n});
    final streak = t.okCount;
    if (streak >= 3) t.note = 'SÉRIE ×$streak';
    if (count(st) == 7) t.note = 'À LA 8 !';
    if (t.darts.length >= t.maxDarts) t.maxDarts += 3;
  }

  @override
  int compare(PracticeGame g, int a, int b) {
    final sa = g.stateOf(a), sb = g.stateOf(b);
    final d = (sa.done ? 0 : 1) - (sb.done ? 0 : 1);
    if (d != 0) return d;
    final c = count(sb).compareTo(count(sa));
    if (c != 0) return c;
    return sa.darts.compareTo(sb.darts);
  }
}

/// Billes de chaque joueur (numéro, empochée, double/triple exigé).
List<List<(int, bool, bool)>> poolBalls(PracticeGame g) {
  final r = g.rules;
  if (r is! _Pool) return const [];
  return [
    for (var p = 0; p < g.players.length; p++)
      [
        for (var i = 0; i < 7; i++)
          (r.ballsOf(p)[i], _Pool.isPotted(g.stateOf(p), i), r.strong(i))
      ]
  ];
}

// ─── Zombies ───

/// Un zombie : cible exacte (numéro + multiplicateur ; bull : 1 = 25,
/// 2 = 50), couloir (0-5) et avancée (0 = au loin, 5 = à la base).
class Zombie {
  final int id, n, m, lane, y;
  const Zombie(this.id, this.n, this.m, this.lane, this.y);
  Zombie step() => Zombie(id, n, m, lane, y + 1);
  String get label => n == 25
      ? (m == 2 ? 'BULL' : '25')
      : '${m == 3 ? 'T' : m == 2 ? 'D' : ''}$n';
  bool hitBy(DartHit h) => n == 25
      ? h.isBull && (m == 2) == (h.ring == Ring.innerBull)
      : !h.isBull && h.number == n && h.multiplier == m;
}

/// Coopératif : les zombies descendent d'un cran à chaque fin de manche ;
/// à la base, ils la mordent (5 vies). Touche la cible exacte d'un zombie
/// pour l'abattre. Tenir toutes les vagues = victoire.
class _Zombies extends PracticeRules {
  _Zombies(super.s);

  static const lanes = 6, reach = 5, baseLives = 5;
  int get waves => s.goalOrDefault;

  static List<Zombie> horde(PracticeGame g) =>
      (g.shared['z'] as List<Zombie>?) ?? const [];
  static int lives(PracticeGame g) => (g.shared['hp'] as int?) ?? baseLives;

  void _spawn(PracticeGame g, int wave) {
    final z = [...horde(g)];
    final r = Random(s.seed * 97 + wave * 13);
    var id = (g.shared['id'] as int?) ?? 0;
    final count = 2 + wave ~/ 3;
    for (var k = 0; k < count && z.length < 7; k++) {
      final used = {for (final x in z) x.n};
      final free = [
        for (var i = 0; i < lanes; i++)
          if (!z.any((x) => x.lane == i && x.y == 0)) i
      ];
      if (free.isEmpty) break;
      final lane = free[r.nextInt(free.length)];
      var n = 1 + r.nextInt(20);
      for (var t = 0; t < 20 && used.contains(n); t++) {
        n = n % 20 + 1;
      }
      if (r.nextDouble() < 0.08 && !used.contains(25)) n = 25;
      final roll = r.nextDouble();
      final m = n == 25
          ? (wave >= 4 && roll < 0.4 ? 2 : 1)
          : wave <= 2
              ? 1
              : wave <= 5
                  ? (roll < 0.35 ? 2 : 1)
                  : (roll < 0.25
                      ? 3
                      : roll < 0.6
                          ? 2
                          : 1);
      z.add(Zombie(id++, n, m, lane, 0));
    }
    g.shared['z'] = z;
    g.shared['id'] = id;
  }

  @override
  void init(PracticeGame g, int p, PracticePlayer st) {
    if (p != 0) return;
    g.shared['z'] = const <Zombie>[];
    g.shared['hp'] = baseLives;
    _spawn(g, 1);
    _spawn(g, 2);
  }

  @override
  int? roundLimit(PracticeGame g) => waves;
  @override
  String rulesLabel(PracticeGame g) => plural(waves, 'vague');
  @override
  bool over(PracticeGame g) => lives(g) <= 0;
  @override
  String target(PracticeGame g, int p) =>
      '${plural(horde(g).length, 'ZOMBIE', 'ZOMBIES')} · BASE ${lives(g)}/$baseLives';

  @override
  List<DartHit> zones(PracticeGame g, int p) {
    final z = [...horde(g)]..sort((a, b) => b.y.compareTo(a.y));
    return [
      for (final x in z.take(3))
        x.n == 25
            ? _bulls[x.m == 2 ? 0 : 1]
            : DartHit(
                x.n,
                x.m,
                x.m == 3
                    ? Ring.triple
                    : x.m == 2
                        ? Ring.double
                        : Ring.singleOuter)
    ];
  }

  @override
  String info(PracticeGame g, int p) =>
      plural(g.stateOf(p).hits, 'zombie abattu', 'zombies abattus');

  @override
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d) {
    final h = d.hit;
    if (h == null) return;
    final z = [...horde(g)];
    // le plus avancé d'abord
    z.sort((a, b) => b.y.compareTo(a.y));
    final i = z.indexWhere((x) => x.hitBy(h));
    if (i < 0) return;
    final dead = z.removeAt(i);
    g.shared['z'] = z;
    final st = g.stateOf(p);
    st.hits++;
    final pts = 10 * dead.m + 5 * dead.y;
    st.score += pts;
    d.ok = true;
    d.points = pts;
    t.note = dead.y >= reach - 1 ? 'SAUVÉS DE JUSTESSE !' : null;
    _event(g, 'kill', {'p': p, 'id': dead.id});
  }

  @override
  void onTurnEnd(PracticeGame g, int p, PracticeTurn t) {
    if (p != g.players.length - 1) return;
    var hp = lives(g);
    var bites = 0;
    final z = <Zombie>[];
    for (final x in horde(g)) {
      final moved = x.step();
      if (moved.y >= reach) {
        hp--;
        bites++;
      } else {
        z.add(moved);
      }
    }
    g.shared['z'] = z;
    g.shared['hp'] = max(0, hp);
    if (bites > 0) {
      t.note = hp <= 0
          ? 'LA BASE EST TOMBÉE'
          : 'LA BASE EST MORDUE ! (${max(0, hp)}/$baseLives)';
      _event(g, 'bite', {'k': bites});
    } else {
      _event(g, 'advance');
    }
    if (hp > 0) _spawn(g, g.round + 1);
  }
}

/// Zombies présents et vies de la base.
(List<Zombie>, int) zombiesState(PracticeGame g) =>
    (_Zombies.horde(g), _Zombies.lives(g));
const kZombieLanes = _Zombies.lanes, kZombieReach = _Zombies.reach;
