// Jeux d'entraînement (GranDarts) : Count Up, Target 20 / Bull / Choix de
// cible / Hat / Horse, Half It, Delta Shoot, Rotation, Shoot Force, Oniren,
// CR Count Up, CR Multiple, Bob's 27, Finition 121, Spider, Pirates.
//
// Un seul moteur (PracticeGame) gère les tours, les manches, l'annulation et
// le rejeu ; chaque jeu fournit ses règles (PracticeRules). Pur Dart, même
// journal d'actions que les autres jeux, plus « c:<numéro> » (changer de
// cible, Choix de cible). Tirages au hasard tirés d'une graine : téléphone et
// TV obtiennent les mêmes cibles.

import 'dart:math';

import '../granboard.dart';
import 'darts_game.dart';
import 'x01.dart' show BullMode, X01Player;

enum PracticeKind {
  countUp,
  target20,
  targetBull,
  targetChoice,
  targetHat,
  targetHorse,
  halfIt,
  deltaShoot,
  rotation,
  shootForce,
  oniren,
  crCountUp,
  crMultiple,
  bobs27,
  checkout121,
  spider,
  pirates,
}

/// Réglages proposés pour chaque jeu.
class PracticeInfo {
  final String name;
  final String help;

  /// Choix de manches (null = pas de choix).
  final List<int>? rounds;
  final int? defaultRounds;

  /// Objectifs (touches, hat tricks…) ; 0 = « en 10 manches ».
  final List<int>? goals;
  final int? defaultGoal;

  /// Cible au choix (Choix de cible, Target Hat).
  final bool target;

  /// Options (clé → libellé).
  final Map<String, String> options;
  final bool bull;
  const PracticeInfo(this.name, this.help,
      {this.rounds,
      this.defaultRounds,
      this.goals,
      this.defaultGoal,
      this.target = false,
      this.options = const {},
      this.bull = false});
}

const kPracticeInfo = <PracticeKind, PracticeInfo>{
  PracticeKind.countUp: PracticeInfo('Count Up',
      'Chaque fléchette rapporte sa valeur : le plus gros total gagne. 33 manches = défi des 99 fléchettes.',
      rounds: [1, 2, 3, 4, 5, 6, 7, 8, 10, 15, 33],
      defaultRounds: 8,
      bull: true),
  PracticeKind.target20: PracticeInfo('Target 20',
      'Vise le 20 : simple = 1 touche, double = 2, triple = 3. Le premier à l\'objectif gagne (ou le plus de touches en 10 manches).',
      goals: [5, 10, 30, 50, 100, 0], defaultGoal: 10),
  PracticeKind.targetBull: PracticeInfo('Target Bull',
      'Vise le bull : 25 = 1 touche, 50 = 2. Le premier à l\'objectif gagne (ou le plus de touches en 10 manches).',
      goals: [5, 10, 30, 50, 100, 0], defaultGoal: 10),
  PracticeKind.targetChoice: PracticeInfo('Choix de cible',
      'Choisis ta cible (et changes-en quand tu veux, avant ta 1re fléchette) : simple = 1 touche, double = 2, triple = 3.',
      goals: [5, 10, 30, 50, 100], defaultGoal: 10, target: true),
  PracticeKind.targetHat: PracticeInfo('Target Hat',
      'Hat trick : tes 3 fléchettes de la manche dans la cible choisie. Le premier à l\'objectif gagne.',
      goals: [5, 10, 30, 50, 100], defaultGoal: 5, target: true),
  PracticeKind.targetHorse: PracticeInfo('Target Horse',
      'White Horse : 3 triples sur 3 numéros différents du Cricket (15 à 20) dans la même manche.',
      goals: [5, 10, 15, 20, 25, 30], defaultGoal: 5),
  PracticeKind.halfIt: PracticeInfo('Half It',
      'Départ à 40. 9 manches : 15, 16, doubles, 17, 18, triples, 19, 20, bull. Aucune touche dans la manche = score divisé par 2.'),
  PracticeKind.deltaShoot: PracticeInfo('Delta Shoot',
      '16 manches : 10, 11, 12, double ou triple, 13, 14, double, 15, 16, 17, triple, 18, 19, 20, bull, double bull. Aucune touche = score ÷ 2.'),
  PracticeKind.rotation: PracticeInfo('Rotation',
      'Touche le 1, puis le 2… jusqu\'au 20, puis 3 bulls. Chaque cible rapporte son numéro ; touche à la 3e fléchette = 3 fléchettes de plus. Fini en moins de 8 manches = bonus.',
      options: {'double': 'Doubles seulement', 'triple': 'Triples seulement'}),
  PracticeKind.shootForce: PracticeInfo('Shoot Force',
      '1 à 20 puis le bull : chaque touche vaut sa valeur × ta série de touches. 3 triples dans la manche = +3000, simple bull 10 000, double bull 100 000. 8 manches.'),
  PracticeKind.oniren: PracticeInfo('Oniren',
      'Une cible au hasard par manche : 2 simples + 1 double ou triple dessus pour la valider. Manche ratée = une vie en moins (3 vies).'),
  PracticeKind.crCountUp: PracticeInfo('CR Count Up',
      '20, 19, 18, 17, 16, 15, bull, puis au choix 15, 20 ou bull. Points = valeur × marques.'),
  PracticeKind.crMultiple: PracticeInfo('CR Multiple',
      '20 à 15 puis bull : 1re fléchette ×1, 2e ×2, 3e ×3. Manches 4 et 7 : 3 numéros bonus (×2 ×4 ×6 puis ×3 ×6 ×9). Rien touché = -3 × la cible.'),
  PracticeKind.bobs27: PracticeInfo('Bob\'s 27',
      'Départ à 27. D1 à D20 puis double bull, 3 fléchettes chacun : + valeur du double à chaque touche, - sa valeur si aucune.',
      options: {
        'hard': 'Hard (éliminé à 0)',
        'even': 'Doubles pairs seulement'
      }),
  PracticeKind.checkout121: PracticeInfo('Finition 121',
      'Finis 121 en Double Out avec 9 fléchettes : réussi = cible +1, raté = cible -1. Le premier à finir 125 gagne (sinon la plus haute cible en 30 manches).',
      rounds: [3, 6, 9, 12, 15, 18], defaultRounds: 9),
  PracticeKind.spider: PracticeInfo('Spider',
      'Abats des araignées : ramène leur nombre à 0 pile (dépasser = rien). Bonus : manche sans raté ×2, fin sur double/triple ×2, les 8 araignées = 500 par manche restante. 15 manches.'),
  PracticeKind.pirates: PracticeInfo('Pirates',
      'Bull seulement (25 / 50) : un navire coule tous les 200 points. Après 3 navires, chance au trésor (bulls bonus) puis bonus de vitesse. 15 manches.',
      options: {
        'kids': 'Kids (12 manches, tout bull = 50)',
        'master': 'Master (50 seulement)'
      }),
};

class PracticeSettings {
  final PracticeKind kind;
  final int? rounds;
  final int? goal;
  final int target;
  final BullMode bull;
  final Set<String> options;
  final int seed;
  const PracticeSettings(this.kind,
      {this.rounds,
      this.goal,
      this.target = 20,
      this.bull = BullMode.split,
      this.options = const {},
      this.seed = 0});

  PracticeInfo get info => kPracticeInfo[kind]!;
  String get name => info.name;
  int get goalOrDefault => goal ?? info.defaultGoal ?? 0;
  int get roundsOrDefault => rounds ?? info.defaultRounds ?? 0;
  bool has(String o) => options.contains(o);

  PracticeSettings withSeed(int s) => PracticeSettings(kind,
      rounds: rounds,
      goal: goal,
      target: target,
      bull: bull,
      options: options,
      seed: s);

  Map<String, dynamic> toJson() => {
        'k': kind.name,
        if (rounds != null) 'rounds': rounds,
        if (goal != null) 'goal': goal,
        'target': target,
        'bull': bull.index,
        'opt': options.toList(),
        'seed': seed,
      };

  factory PracticeSettings.fromJson(Map<String, dynamic> j) => PracticeSettings(
        PracticeKind.values.firstWhere((k) => k.name == j['k'],
            orElse: () => PracticeKind.countUp),
        rounds: (j['rounds'] as num?)?.toInt(),
        goal: (j['goal'] as num?)?.toInt(),
        target: (j['target'] as num?)?.toInt() ?? 20,
        bull: BullMode.values[(j['bull'] as num?)?.toInt() ?? 0],
        options: {for (final o in (j['opt'] as List? ?? const [])) '$o'},
        seed: (j['seed'] as num?)?.toInt() ?? 0,
      );
}

/// Une fléchette : points gagnés (ou perdus) et si elle a servi.
class PracticeDart {
  final DartHit? hit;
  int points;
  bool ok;
  PracticeDart(this.hit, {this.points = 0, this.ok = false});
}

class PracticeTurn {
  final int player;
  final int round;
  final List<PracticeDart> darts = [];
  int maxDarts = 3;

  /// Cible au début de la manche (affichage, historique).
  final String target;
  final int scoreBefore;

  /// Effet de fin de manche (« ÷ 2 », « -10 », « VALIDÉ »…).
  String? note;
  PracticeTurn(this.player, this.round, this.target, this.scoreBefore);

  int get points => darts.fold(0, (s, d) => s + d.points);
  int get okCount => darts.where((d) => d.ok).length;
}

class PracticePlayer {
  int score = 0;
  int hits = 0; // touches / hats / horses / navires… selon le jeu
  int lives = 3;
  bool out = false; // éliminé
  bool done = false; // a fini
  int step = 0; // position dans la suite de cibles
  int streak = 0;
  int darts = 0;
  int good = 0; // fléchettes utiles
  int? doneRound;
  final Map<String, int> v = {};
}

enum PracticeEnd { goal, limit, allOut }

class PracticeGame implements DartsGame {
  final PracticeSettings settings;
  @override
  final List<X01Player> players;
  late final PracticeRules rules = PracticeRules.of(settings);

  final List<String> _log = [];
  late List<PracticePlayer> _st;
  late List<PracticeTurn> _turns;
  int _current = 0;
  int _round = 1;
  List<int> _winners = [];
  PracticeEnd? _end;

  PracticeGame(this.settings, this.players) {
    if (players.isEmpty) throw ArgumentError('Aucun joueur');
    _reset();
  }

  factory PracticeGame.fromJson(Map<String, dynamic> j) {
    final g = PracticeGame(
      PracticeSettings.fromJson(
          Map<String, dynamic>.from(j['settings'] as Map)),
      [
        for (final p in (j['players'] as List))
          X01Player.fromJson(Map<String, dynamic>.from(p as Map))
      ],
    );
    for (final a in (j['actions'] as List? ?? const [])) {
      g.applyLogEntry('$a');
    }
    return g;
  }

  // ─── Lecture ───

  PracticePlayer stateOf(int i) => _st[i];
  PracticeTurn get currentTurn => _turns.last;
  List<PracticeTurn> get turns => List.unmodifiable(_turns);
  PracticeEnd? get endReason => _end;
  int get roundCount => _round;

  /// Classement (meilleur d'abord).
  List<int> get ranking {
    final r = List.generate(players.length, (i) => i);
    r.sort((a, b) {
      final w = (_winners.contains(a) ? 0 : 1) - (_winners.contains(b) ? 0 : 1);
      if (w != 0) return w;
      return rules.compare(this, a, b);
    });
    return r;
  }

  /// Texte de la cible du joueur en cours.
  String get targetLabel => rules.target(this, _current);

  /// Zones à mettre en valeur sur la cible.
  List<DartHit> get targetZones => rules.zones(this, _current);

  /// Infos du joueur (vies, série, navires…).
  String infoOf(int p) => rules.info(this, p);

  /// Score affiché du joueur.
  String scoreText(int p) => rules.scoreText(this, p);

  // ─── Interface commune ───

  @override
  String get kind => 'practice';
  @override
  String get title => settings.name;
  @override
  String get rulesLabel => rules.rulesLabel(this);
  @override
  int get current => _current;
  @override
  X01Player get currentPlayer => players[_current];
  @override
  int get round => _round;
  @override
  int? get roundLimit => rules.roundLimit(this);
  @override
  bool get finished => _end != null;
  @override
  bool get turnOver {
    if (finished) return true;
    final t = currentTurn;
    final s = _st[_current];
    return t.darts.length >= t.maxDarts || s.done || s.out;
  }

  @override
  bool get canUndo => _log.isNotEmpty;
  @override
  List<int> get winners => List.unmodifiable(_winners);
  @override
  List<DartHit?> get turnHits => [for (final d in currentTurn.darts) d.hit];
  @override
  List<String> get actionLog => List.unmodifiable(_log);

  @override
  Map<String, dynamic> toJson() => {
        'kind': kind,
        'settings': settings.toJson(),
        'players': [for (final p in players) p.toJson()],
        'actions': actionLog,
      };

  @override
  bool applyLogEntry(String a) {
    if (a.startsWith('c:')) {
      final n = int.tryParse(a.substring(2));
      return n != null && changeTarget(n);
    }
    final e = parseLogEntry(a);
    if (e == null) return false;
    return e.$1 ? next() : throwDart(e.$2);
  }

  /// Choix de cible : nouvelle cible (1-20 ou 25), avant la 1re fléchette.
  bool get canChangeTarget =>
      settings.info.target &&
      !finished &&
      currentTurn.darts.isEmpty &&
      settings.kind == PracticeKind.targetChoice;

  bool changeTarget(int n) {
    if (!canChangeTarget || !((n >= 1 && n <= 20) || n == 25)) return false;
    _st[_current].v['t'] = n;
    _log.add('c:$n');
    _turns.last = PracticeTurn(
        _current, _round, rules.target(this, _current), _st[_current].score);
    return true;
  }

  @override
  bool throwDart(DartHit? hit) {
    if (turnOver) return false;
    final t = currentTurn;
    final s = _st[_current];
    final d = PracticeDart(hit);
    t.darts.add(d);
    s.darts++;
    rules.onDart(this, _current, t, d);
    if (d.ok) s.good++;
    _log.add(logEntryOf(false, hit));
    _checkEnd(afterDart: true);
    return true;
  }

  @override
  bool next() {
    if (finished) return false;
    final t = currentTurn;
    final s = _st[_current];
    // Fléchettes non lancées = ratées (si le joueur joue encore)
    while (t.darts.length < t.maxDarts && !s.done && !s.out) {
      final d = PracticeDart(null);
      t.darts.add(d);
      s.darts++;
      rules.onDart(this, _current, t, d);
    }
    rules.onTurnEnd(this, _current, t);
    _log.add('n');
    _checkEnd(afterDart: false);
    if (finished) return true;

    // Joueur suivant encore en jeu
    final n = players.length;
    var i = _current;
    for (var k = 0; k < n; k++) {
      i = (i + 1) % n;
      if (i == 0) _round++;
      if (!_st[i].done && !_st[i].out) break;
    }
    _current = i;
    final limit = roundLimit;
    if (limit != null && _round > limit) {
      _round = limit;
      _finish(PracticeEnd.limit);
      return true;
    }
    rules.onTurnStart(this, _current);
    _turns.add(PracticeTurn(
        _current, _round, rules.target(this, _current), _st[_current].score));
    return true;
  }

  @override
  bool undo() {
    if (_log.isEmpty) return false;
    final log = [..._log]..removeLast();
    _log.clear();
    _reset();
    for (final a in log) {
      applyLogEntry(a);
    }
    return true;
  }

  // ─── Fonctionnement ───

  void _reset() {
    _st = [for (final _ in players) PracticePlayer()];
    for (var i = 0; i < players.length; i++) {
      rules.init(this, i, _st[i]);
    }
    _current = 0;
    _round = 1;
    _winners = [];
    _end = null;
    _turns = [];
    rules.onTurnStart(this, 0);
    _turns.add(PracticeTurn(0, 1, rules.target(this, 0), _st[0].score));
  }

  void _checkEnd({required bool afterDart}) {
    if (finished) return;
    final s = _st[_current];
    if (s.done) s.doneRound ??= _round;
    // Objectif atteint : la partie s'arrête (le premier gagne)
    if (rules.goalEndsGame && s.done) {
      _finish(PracticeEnd.goal);
      return;
    }
    if (_st.every((x) => x.done || x.out)) {
      _finish(_st.every((x) => x.out) ? PracticeEnd.allOut : PracticeEnd.goal);
    }
  }

  void _finish(PracticeEnd e) {
    _end = e;
    final r = List.generate(players.length, (i) => i)
      ..sort((a, b) => rules.compare(this, a, b));
    final best = r.first;
    _winners = [
      for (final i in r)
        if (rules.compare(this, i, best) == 0) i
    ];
  }
}

// ─── Règles ───

int _value(DartHit? h, BullMode bull) {
  if (h == null) return 0;
  if (h.isBull && bull == BullMode.fat) return 50;
  return h.score;
}

List<DartHit> _numberZones(int n) => n == 25
    ? const [DartHit(25, 1, Ring.outerBull), DartHit(25, 2, Ring.innerBull)]
    : [
        DartHit(n, 1, Ring.singleInner),
        DartHit(n, 1, Ring.singleOuter),
        DartHit(n, 2, Ring.double),
        DartHit(n, 3, Ring.triple),
      ];

String _numLabel(int n) => n == 25 ? 'BULL' : '$n';

abstract class PracticeRules {
  final PracticeSettings s;
  PracticeRules(this.s);

  factory PracticeRules.of(PracticeSettings s) => switch (s.kind) {
        PracticeKind.countUp => _CountUp(s),
        PracticeKind.target20 => _TargetHits(s, 20),
        PracticeKind.targetBull => _TargetHits(s, 25),
        PracticeKind.targetChoice => _TargetHits(s, s.target),
        PracticeKind.targetHat => _TargetHat(s),
        PracticeKind.targetHorse => _TargetHorse(s),
        PracticeKind.halfIt => _Sequence(s, _halfIt, start: 40),
        PracticeKind.deltaShoot => _Sequence(s, _delta, start: 0),
        PracticeKind.rotation => _Rotation(s),
        PracticeKind.shootForce => _ShootForce(s),
        PracticeKind.oniren => _Oniren(s),
        PracticeKind.crCountUp => _CrCountUp(s),
        PracticeKind.crMultiple => _CrMultiple(s),
        PracticeKind.bobs27 => _Bobs27(s),
        PracticeKind.checkout121 => _Checkout121(s),
        PracticeKind.spider => _Spider(s),
        PracticeKind.pirates => _Pirates(s),
      };

  void init(PracticeGame g, int p, PracticePlayer st) {}
  void onTurnStart(PracticeGame g, int p) {}
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d);
  void onTurnEnd(PracticeGame g, int p, PracticeTurn t) {}
  int? roundLimit(PracticeGame g);
  String target(PracticeGame g, int p);
  List<DartHit> zones(PracticeGame g, int p) => const [];
  String info(PracticeGame g, int p) => '';
  String scoreText(PracticeGame g, int p) => '${g.stateOf(p).score}';
  String rulesLabel(PracticeGame g) {
    final l = roundLimit(g);
    return l == null ? '' : '$l manches';
  }

  /// Le premier qui finit gagne tout de suite.
  bool get goalEndsGame => false;

  /// < 0 si a est mieux classé que b.
  int compare(PracticeGame g, int a, int b) =>
      g.stateOf(b).score.compareTo(g.stateOf(a).score);
}

class _CountUp extends PracticeRules {
  _CountUp(super.s);
  @override
  int? roundLimit(PracticeGame g) => s.roundsOrDefault;
  @override
  String target(PracticeGame g, int p) => 'TOUT COMPTE';
  @override
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d) {
    d.points = _value(d.hit, s.bull);
    d.ok = d.hit != null;
    g.stateOf(p).score += d.points;
  }

  @override
  String info(PracticeGame g, int p) {
    final st = g.stateOf(p);
    return st.darts == 0
        ? ''
        : 'MOYENNE ${(st.score * 3 / st.darts).toStringAsFixed(1)}';
  }
}

/// Target 20 / Bull / Choix de cible : touches sur un numéro.
class _TargetHits extends PracticeRules {
  final int fixed;
  _TargetHits(super.s, this.fixed);

  int _goal() => s.goalOrDefault;
  int targetOf(PracticeGame g, int p) => g.stateOf(p).v['t'] ?? fixed;

  @override
  void init(PracticeGame g, int p, PracticePlayer st) => st.v['t'] = fixed;
  @override
  bool get goalEndsGame => true;
  @override
  int? roundLimit(PracticeGame g) => _goal() == 0 ? 10 : null;
  @override
  String rulesLabel(PracticeGame g) =>
      _goal() == 0 ? '10 manches' : 'Objectif ${_goal()} touches';
  @override
  String target(PracticeGame g, int p) => _numLabel(targetOf(g, p));
  @override
  List<DartHit> zones(PracticeGame g, int p) => _numberZones(targetOf(g, p));
  @override
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d) {
    final h = d.hit;
    final n = targetOf(g, p);
    if (h == null || (h.isBull ? 25 : h.number) != n) return;
    final k = h.isBull ? (h.ring == Ring.innerBull ? 2 : 1) : h.multiplier;
    final st = g.stateOf(p);
    st.hits += k;
    st.score = st.hits;
    d.points = k;
    d.ok = true;
    if (_goal() > 0 && st.hits >= _goal()) st.done = true;
  }

  @override
  String scoreText(PracticeGame g, int p) =>
      _goal() == 0 ? '${g.stateOf(p).hits}' : '${g.stateOf(p).hits}/${_goal()}';
  @override
  String info(PracticeGame g, int p) {
    final st = g.stateOf(p);
    return st.darts == 0
        ? ''
        : 'RÉUSSITE ${(st.good * 100 / st.darts).round()} %';
  }
}

class _TargetHat extends PracticeRules {
  _TargetHat(super.s);
  @override
  bool get goalEndsGame => true;
  @override
  int? roundLimit(PracticeGame g) => null;
  @override
  String rulesLabel(PracticeGame g) => 'Objectif ${s.goalOrDefault} hat tricks';
  @override
  String target(PracticeGame g, int p) => '3 × ${_numLabel(s.target)}';
  @override
  List<DartHit> zones(PracticeGame g, int p) => _numberZones(s.target);
  @override
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d) {
    final h = d.hit;
    d.ok = h != null && (h.isBull ? 25 : h.number) == s.target;
    if (t.darts.length == 3 && t.darts.every((x) => x.ok)) {
      final st = g.stateOf(p);
      st.hits++;
      st.score = st.hits;
      d.points = 1;
      t.note = 'HAT TRICK';
      if (st.hits >= s.goalOrDefault) st.done = true;
    }
  }

  @override
  String scoreText(PracticeGame g, int p) =>
      '${g.stateOf(p).hits}/${s.goalOrDefault}';
}

class _TargetHorse extends PracticeRules {
  _TargetHorse(super.s);
  @override
  bool get goalEndsGame => true;
  @override
  int? roundLimit(PracticeGame g) => null;
  @override
  String rulesLabel(PracticeGame g) =>
      'Objectif ${s.goalOrDefault} White Horse';
  @override
  String target(PracticeGame g, int p) => '3 TRIPLES 15-20';
  @override
  List<DartHit> zones(PracticeGame g, int p) => [
        for (var n = 15; n <= 20; n++)
          if (!g.currentTurn.darts.any((d) => d.hit?.number == n && d.ok))
            DartHit(n, 3, Ring.triple)
      ];
  @override
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d) {
    final h = d.hit;
    final before = t.darts.sublist(0, t.darts.length - 1);
    d.ok = h != null &&
        h.ring == Ring.triple &&
        h.number >= 15 &&
        h.number <= 20 &&
        !before.any((x) => x.ok && x.hit!.number == h.number);
    if (t.darts.length == 3 && t.darts.every((x) => x.ok)) {
      final st = g.stateOf(p);
      st.hits++;
      st.score = st.hits;
      d.points = 1;
      t.note = 'WHITE HORSE';
      if (st.hits >= s.goalOrDefault) st.done = true;
    }
  }

  @override
  String scoreText(PracticeGame g, int p) =>
      '${g.stateOf(p).hits}/${s.goalOrDefault}';
}

// Half It / Delta Shoot : une cible par manche, rien touché = score ÷ 2
enum _Kind { number, doubles, triples, doubleOrTriple, bull, doubleBull }

class _Step {
  final _Kind kind;
  final int n;
  const _Step(this.kind, [this.n = 0]);

  String get label => switch (kind) {
        _Kind.number => '$n',
        _Kind.doubles => 'DOUBLES',
        _Kind.triples => 'TRIPLES',
        _Kind.doubleOrTriple => 'DOUBLE OU TRIPLE',
        _Kind.bull => 'BULL',
        _Kind.doubleBull => 'DOUBLE BULL',
      };

  bool ok(DartHit? h) {
    if (h == null) return false;
    return switch (kind) {
      _Kind.number => !h.isBull && h.number == n,
      _Kind.doubles => h.ring == Ring.double || h.ring == Ring.innerBull,
      _Kind.triples => h.ring == Ring.triple,
      _Kind.doubleOrTriple => h.ring == Ring.double ||
          h.ring == Ring.triple ||
          h.ring == Ring.innerBull,
      _Kind.bull => h.isBull,
      _Kind.doubleBull => h.ring == Ring.innerBull,
    };
  }

  List<DartHit> get zones => switch (kind) {
        _Kind.number => _numberZones(n),
        _Kind.doubles => [
            for (var i = 1; i <= 20; i++) DartHit(i, 2, Ring.double),
            const DartHit(25, 2, Ring.innerBull)
          ],
        _Kind.triples => [
            for (var i = 1; i <= 20; i++) DartHit(i, 3, Ring.triple)
          ],
        _Kind.doubleOrTriple => [
            for (var i = 1; i <= 20; i++) ...[
              DartHit(i, 2, Ring.double),
              DartHit(i, 3, Ring.triple)
            ],
            const DartHit(25, 2, Ring.innerBull)
          ],
        _Kind.bull => _numberZones(25),
        _Kind.doubleBull => const [DartHit(25, 2, Ring.innerBull)],
      };
}

const _halfIt = [
  _Step(_Kind.number, 15),
  _Step(_Kind.number, 16),
  _Step(_Kind.doubles),
  _Step(_Kind.number, 17),
  _Step(_Kind.number, 18),
  _Step(_Kind.triples),
  _Step(_Kind.number, 19),
  _Step(_Kind.number, 20),
  _Step(_Kind.bull),
];

const _delta = [
  _Step(_Kind.number, 10),
  _Step(_Kind.number, 11),
  _Step(_Kind.number, 12),
  _Step(_Kind.doubleOrTriple),
  _Step(_Kind.number, 13),
  _Step(_Kind.number, 14),
  _Step(_Kind.doubles),
  _Step(_Kind.number, 15),
  _Step(_Kind.number, 16),
  _Step(_Kind.number, 17),
  _Step(_Kind.triples),
  _Step(_Kind.number, 18),
  _Step(_Kind.number, 19),
  _Step(_Kind.number, 20),
  _Step(_Kind.bull),
  _Step(_Kind.doubleBull),
];

class _Sequence extends PracticeRules {
  final List<_Step> steps;
  final int start;
  _Sequence(super.s, this.steps, {required this.start});

  _Step stepOf(PracticeGame g) =>
      steps[(g.round - 1).clamp(0, steps.length - 1)];

  @override
  void init(PracticeGame g, int p, PracticePlayer st) => st.score = start;
  @override
  int? roundLimit(PracticeGame g) => steps.length;
  @override
  String target(PracticeGame g, int p) => stepOf(g).label;
  @override
  List<DartHit> zones(PracticeGame g, int p) => stepOf(g).zones;
  @override
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d) {
    if (!stepOf(g).ok(d.hit)) return;
    d.ok = true;
    d.points = _value(d.hit, s.bull);
    g.stateOf(p).score += d.points;
  }

  @override
  void onTurnEnd(PracticeGame g, int p, PracticeTurn t) {
    if (t.okCount > 0) return;
    final st = g.stateOf(p);
    final before = st.score;
    st.score = st.score ~/ 2;
    t.note = '÷ 2 (-${before - st.score})';
  }
}

class _Rotation extends PracticeRules {
  _Rotation(super.s);

  int targetNumber(PracticeGame g, int p) {
    final step = g.stateOf(p).step;
    return step < 20 ? step + 1 : 25;
  }

  bool _ok(DartHit? h, int n) {
    if (h == null || (h.isBull ? 25 : h.number) != n) return false;
    if (n == 25) return true;
    if (s.has('double')) return h.ring == Ring.double;
    if (s.has('triple')) return h.ring == Ring.triple;
    return true;
  }

  @override
  bool get goalEndsGame => true;
  @override
  int? roundLimit(PracticeGame g) => 20;
  @override
  String rulesLabel(PracticeGame g) => s.has('double')
      ? 'Doubles seulement'
      : s.has('triple')
          ? 'Triples seulement'
          : '1 à 20 puis 3 bulls';
  @override
  String target(PracticeGame g, int p) {
    final n = targetNumber(g, p);
    if (n == 25) return 'BULL (${g.stateOf(p).v['bulls'] ?? 0}/3)';
    return s.has('double')
        ? 'D$n'
        : s.has('triple')
            ? 'T$n'
            : '$n';
  }

  @override
  List<DartHit> zones(PracticeGame g, int p) {
    final n = targetNumber(g, p);
    if (n == 25) return _numberZones(25);
    if (s.has('double')) return [DartHit(n, 2, Ring.double)];
    if (s.has('triple')) return [DartHit(n, 3, Ring.triple)];
    return _numberZones(n);
  }

  @override
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d) {
    final st = g.stateOf(p);
    final n = targetNumber(g, p);
    if (!_ok(d.hit, n)) return;
    d.ok = true;
    d.points = n;
    st.score += n;
    if (n == 25) {
      final b = (st.v['bulls'] ?? 0) + 1;
      st.v['bulls'] = b;
      if (b >= 3) {
        st.done = true;
        if (g.round < 8) {
          final bonus = (8 - g.round) * 100;
          st.score += bonus;
          t.note = 'BONUS +$bonus';
        }
        return;
      }
    } else {
      st.step++;
    }
    // Touche à la dernière fléchette : 3 fléchettes de plus
    if (t.darts.length == t.maxDarts) t.maxDarts += 3;
  }

  @override
  String info(PracticeGame g, int p) {
    final st = g.stateOf(p);
    return 'CIBLE ${st.step >= 20 ? 21 : st.step + 1}/21';
  }
}

class _ShootForce extends PracticeRules {
  _ShootForce(super.s);

  int targetNumber(PracticeGame g, int p) {
    final step = g.stateOf(p).step;
    return step < 20 ? step + 1 : 25;
  }

  @override
  int? roundLimit(PracticeGame g) => 8;
  @override
  String target(PracticeGame g, int p) => _numLabel(targetNumber(g, p));
  @override
  List<DartHit> zones(PracticeGame g, int p) =>
      _numberZones(targetNumber(g, p));
  @override
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d) {
    final st = g.stateOf(p);
    final n = targetNumber(g, p);
    final h = d.hit;
    if (h == null || (h.isBull ? 25 : h.number) != n) {
      st.streak = 0;
      return;
    }
    st.streak++;
    d.ok = true;
    if (n == 25) {
      d.points = h.ring == Ring.innerBull ? 100000 : 10000;
      st.score += d.points;
      st.done = true;
      return;
    }
    d.points = h.score * st.streak;
    st.score += d.points;
    st.step++;
    final triples = t.darts.where((x) => x.ok && x.hit?.ring == Ring.triple);
    if (t.darts.length == 3 && triples.length == 3) {
      st.score += 3000;
      d.points += 3000;
      t.note = '3 TRIPLES +3000';
    }
  }

  @override
  String info(PracticeGame g, int p) => 'SÉRIE ×${g.stateOf(p).streak}';
}

class _Oniren extends PracticeRules {
  _Oniren(super.s);

  int targetOf(PracticeGame g) => 1 + Random(s.seed * 31 + g.round).nextInt(20);

  @override
  void init(PracticeGame g, int p, PracticePlayer st) => st.lives = 3;
  @override
  int? roundLimit(PracticeGame g) => 99;
  @override
  String rulesLabel(PracticeGame g) => '3 vies · jusqu\'à 99 manches';
  @override
  String target(PracticeGame g, int p) => '${targetOf(g)}';
  @override
  List<DartHit> zones(PracticeGame g, int p) => _numberZones(targetOf(g));
  @override
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d) {
    final h = d.hit;
    d.ok = h != null && !h.isBull && h.number == targetOf(g);
  }

  @override
  void onTurnEnd(PracticeGame g, int p, PracticeTurn t) {
    final st = g.stateOf(p);
    final ok = [
      for (final d in t.darts)
        if (d.ok) d.hit!
    ];
    final singles = ok.where((h) => h.multiplier == 1).length;
    final big = ok.where((h) => h.multiplier >= 2).length;
    if (singles >= 2 && big >= 1) {
      st.score++;
      t.note = 'VALIDÉ';
    } else {
      st.lives--;
      t.note = 'VIE PERDUE';
      if (st.lives <= 0) st.out = true;
    }
  }

  @override
  String info(PracticeGame g, int p) =>
      'VIES ${g.stateOf(p).lives.clamp(0, 3)}/3';
}

class _CrCountUp extends PracticeRules {
  _CrCountUp(super.s);
  static const _seq = [20, 19, 18, 17, 16, 15, 25];

  @override
  int? roundLimit(PracticeGame g) => 8;
  @override
  String target(PracticeGame g, int p) =>
      g.round <= 7 ? _numLabel(_seq[g.round - 1]) : '15, 20 OU BULL';
  @override
  List<DartHit> zones(PracticeGame g, int p) => g.round <= 7
      ? _numberZones(_seq[g.round - 1])
      : [..._numberZones(15), ..._numberZones(20), ..._numberZones(25)];
  @override
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d) {
    final h = d.hit;
    if (h == null) return;
    final n = h.isBull ? 25 : h.number;
    final ok =
        g.round <= 7 ? n == _seq[g.round - 1] : const [15, 20, 25].contains(n);
    if (!ok) return;
    d.ok = true;
    d.points = _value(h, s.bull);
    g.stateOf(p).score += d.points;
  }
}

class _CrMultiple extends PracticeRules {
  _CrMultiple(super.s);
  static const _seq = [20, 19, 18, 17, 16, 15, 25];

  /// Numéros bonus (manches 4 et 7) : numéro → multiplicateur.
  Map<int, int> bonus(PracticeGame g) {
    if (g.round != 4 && g.round != 7) return const {};
    final pool = [for (var i = 1; i <= 14; i++) i]
      ..shuffle(Random(s.seed * 17 + g.round));
    final m = g.round == 4 ? const [2, 4, 6] : const [3, 6, 9];
    return {for (var i = 0; i < 3; i++) pool[i]: m[i]};
  }

  int targetOf(PracticeGame g) => _seq[(g.round - 1).clamp(0, 6)];

  @override
  int? roundLimit(PracticeGame g) => 7;
  @override
  String target(PracticeGame g, int p) {
    final b = bonus(g);
    final t = _numLabel(targetOf(g));
    return b.isEmpty
        ? t
        : '$t + ${b.entries.map((e) => '${e.key}×${e.value}').join(' ')}';
  }

  @override
  List<DartHit> zones(PracticeGame g, int p) => [
        ..._numberZones(targetOf(g)),
        for (final n in bonus(g).keys) ..._numberZones(n),
      ];
  @override
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d) {
    final h = d.hit;
    if (h == null) return;
    final n = h.isBull ? 25 : h.number;
    final k = t.darts.length; // 1re ×1, 2e ×2, 3e ×3
    final st = g.stateOf(p);
    if (n == targetOf(g)) {
      d.ok = true;
      d.points = _value(h, s.bull) * k;
    } else if (bonus(g).containsKey(n)) {
      d.ok = true;
      d.points = h.score * bonus(g)[n]!;
    }
    st.score += d.points;
  }

  @override
  void onTurnEnd(PracticeGame g, int p, PracticeTurn t) {
    if (t.okCount > 0) return;
    final pen = (targetOf(g) == 25 ? 25 : targetOf(g)) * 3;
    g.stateOf(p).score -= pen;
    t.note = '-$pen';
  }
}

class _Bobs27 extends PracticeRules {
  _Bobs27(super.s);

  List<int> get _seq => [
        for (var n = 1; n <= 20; n++)
          if (!s.has('even') || n.isEven) n,
        25
      ];

  int targetOf(PracticeGame g) => _seq[(g.round - 1).clamp(0, _seq.length - 1)];

  @override
  void init(PracticeGame g, int p, PracticePlayer st) => st.score = 27;
  @override
  int? roundLimit(PracticeGame g) => _seq.length;
  @override
  String rulesLabel(PracticeGame g) => [
        if (s.has('hard')) 'Hard',
        if (s.has('even')) 'Doubles pairs',
        '${_seq.length} manches',
      ].join(' · ');
  @override
  String target(PracticeGame g, int p) =>
      targetOf(g) == 25 ? 'DOUBLE BULL' : 'D${targetOf(g)}';
  @override
  List<DartHit> zones(PracticeGame g, int p) => targetOf(g) == 25
      ? const [DartHit(25, 2, Ring.innerBull)]
      : [DartHit(targetOf(g), 2, Ring.double)];
  @override
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d) {
    final h = d.hit;
    final n = targetOf(g);
    final ok = h != null &&
        (n == 25
            ? h.ring == Ring.innerBull
            : h.ring == Ring.double && h.number == n);
    if (!ok) return;
    d.ok = true;
    d.points = n == 25 ? 50 : n * 2;
    g.stateOf(p).score += d.points;
  }

  @override
  void onTurnEnd(PracticeGame g, int p, PracticeTurn t) {
    final st = g.stateOf(p);
    if (t.okCount == 0) {
      final n = targetOf(g);
      final pen = n == 25 ? 50 : n * 2;
      st.score -= pen;
      t.note = '-$pen';
    }
    if (s.has('hard') && st.score <= 0) {
      st.out = true;
      t.note = '${t.note ?? ''} ÉLIMINÉ'.trim();
    }
  }
}

class _Checkout121 extends PracticeRules {
  _Checkout121(super.s);
  static const start = 121;
  static const finish = 125;

  int get perAttempt => s.roundsOrDefault; // fléchettes par tentative

  @override
  void init(PracticeGame g, int p, PracticePlayer st) {
    st.v['target'] = start;
    st.v['rem'] = start;
    st.v['used'] = 0;
    st.score = start;
  }

  @override
  void onTurnStart(PracticeGame g, int p) =>
      g.stateOf(p).v['turnRem'] = g.stateOf(p).v['rem']!;

  @override
  bool get goalEndsGame => true;
  @override
  int? roundLimit(PracticeGame g) => 30;
  @override
  String rulesLabel(PracticeGame g) =>
      'Double Out · $perAttempt fléchettes · finir $finish';
  @override
  String target(PracticeGame g, int p) => 'FINIR ${g.stateOf(p).v['target']}';
  @override
  String scoreText(PracticeGame g, int p) => '${g.stateOf(p).v['rem']}';
  @override
  String info(PracticeGame g, int p) {
    final st = g.stateOf(p);
    return 'CIBLE ${st.v['target']} · ${perAttempt - st.v['used']!} FL.';
  }

  void _newAttempt(PracticePlayer st, int target) {
    st.v['target'] = target;
    st.v['rem'] = target;
    st.v['turnRem'] = target;
    st.v['used'] = 0;
    st.score = target;
  }

  @override
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d) {
    final st = g.stateOf(p);
    final h = d.hit;
    final v = _value(h, s.bull);
    final rem = st.v['rem']!;
    st.v['used'] = st.v['used']! + 1;
    final left = rem - v;
    final isDouble = h != null &&
        (h.ring == Ring.double ||
            h.ring == Ring.innerBull ||
            (h.isBull && s.bull == BullMode.fat));
    if (h != null && left == 0 && isDouble) {
      d.ok = true;
      d.points = v;
      final target = st.v['target']!;
      t.note = 'RÉUSSI $target';
      if (target >= finish) {
        st.done = true;
        st.score = target + 1;
        return;
      }
      _newAttempt(st, target + 1);
      t.maxDarts = t.darts.length; // la manche s'arrête
      return;
    }
    if (h != null && left < 2) {
      // Bust : retour au score du début de la manche
      st.v['rem'] = st.v['turnRem']!;
      t.note = 'BUST';
      t.maxDarts = t.darts.length;
    } else if (h != null) {
      st.v['rem'] = left;
      d.ok = true;
      d.points = v;
    }
    if (st.v['used']! >= perAttempt) {
      final target = st.v['target']!;
      t.note = 'RATÉ $target';
      _newAttempt(st, max(start, target - 1));
      t.maxDarts = t.darts.length;
    }
  }

  @override
  int compare(PracticeGame g, int a, int b) {
    final c = g.stateOf(b).score.compareTo(g.stateOf(a).score);
    return c != 0
        ? c
        : g.stateOf(a).v['rem']!.compareTo(g.stateOf(b).v['rem']!);
  }
}

class _Spider extends PracticeRules {
  _Spider(super.s);

  int spiderValue(PracticeGame g, int killed) =>
      40 + killed * 10 + Random(s.seed * 13 + killed).nextInt(4) * 5;

  @override
  void init(PracticeGame g, int p, PracticePlayer st) {
    st.v['spider'] = spiderValue(g, 0);
    st.v['rem'] = st.v['spider']!;
  }

  @override
  void onTurnStart(PracticeGame g, int p) =>
      g.stateOf(p).v['turnRem'] = g.stateOf(p).v['rem']!;
  @override
  int? roundLimit(PracticeGame g) => 15;
  @override
  String target(PracticeGame g, int p) =>
      'ARAIGNÉE ${g.stateOf(p).hits + 1} : ${g.stateOf(p).v['rem']}';
  @override
  String info(PracticeGame g, int p) => 'ARAIGNÉES ${g.stateOf(p).hits}/8';
  @override
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d) {
    final st = g.stateOf(p);
    final h = d.hit;
    if (h == null) return;
    final v = _value(h, s.bull);
    final left = st.v['rem']! - v;
    if (left < 0) {
      st.v['rem'] = st.v['turnRem']!;
      t.note = 'TROP !';
      t.maxDarts = t.darts.length;
      return;
    }
    d.ok = true;
    d.points = v;
    st.score += v;
    st.v['rem'] = left;
    if (left == 0) {
      var kill = st.v['spider']!;
      if (h.multiplier >= 2) kill *= 2; // Arrange
      st.score += kill;
      d.points += kill;
      st.hits++;
      t.note = 'ARAIGNÉE ABATTUE +$kill';
      if (st.hits >= 8) {
        final clear = (15 - g.round) * 500;
        st.score += clear;
        d.points += clear;
        t.note = 'TOUTES ABATTUES +$clear';
        st.done = true;
        return;
      }
      st.v['spider'] = spiderValue(g, st.hits);
      st.v['rem'] = st.v['spider']!;
      st.v['turnRem'] = st.v['rem']!;
    }
  }

  @override
  void onTurnEnd(PracticeGame g, int p, PracticeTurn t) {
    // Combo : aucune fléchette ratée dans la manche
    if (t.darts.length >= 3 && t.darts.every((d) => d.ok)) {
      final st = g.stateOf(p);
      final bonus = t.darts.fold(0, (a, d) => a + _value(d.hit, s.bull));
      st.score += bonus;
      t.note = '${t.note ?? ''} COMBO +$bonus'.trim();
    }
  }
}

class _Pirates extends PracticeRules {
  _Pirates(super.s);
  static const ship = 200;

  int get _rounds => s.has('kids') ? 12 : 15;

  @override
  int? roundLimit(PracticeGame g) => _rounds;
  @override
  String rulesLabel(PracticeGame g) => [
        if (s.has('kids')) 'Kids',
        if (s.has('master')) 'Master',
        '$_rounds manches',
      ].join(' · ');
  @override
  String target(PracticeGame g, int p) {
    final st = g.stateOf(p);
    if ((st.v['chance'] ?? 0) == 1) return 'CHANCE AU TRÉSOR';
    final hp = ship - (st.v['dmg'] ?? 0);
    return 'NAVIRE ${st.hits + 1} : $hp';
  }

  @override
  List<DartHit> zones(PracticeGame g, int p) => _numberZones(25);
  @override
  String info(PracticeGame g, int p) => 'NAVIRES COULÉS ${g.stateOf(p).hits}/3';

  int _bullValue(DartHit h) {
    if (s.has('master')) return h.ring == Ring.innerBull ? 50 : 0;
    if (s.has('kids') || s.bull == BullMode.fat) return 50;
    return h.ring == Ring.innerBull ? 50 : 25;
  }

  @override
  void onDart(PracticeGame g, int p, PracticeTurn t, PracticeDart d) {
    final st = g.stateOf(p);
    final h = d.hit;
    if (h == null || !h.isBull) return;
    final v = _bullValue(h);
    if (v == 0) return;
    d.ok = true;
    if ((st.v['chance'] ?? 0) == 1) {
      // Chance au trésor : chaque bull = un coffre
      d.points = h.ring == Ring.innerBull ? 500 : 300;
      st.score += d.points;
      return;
    }
    d.points = v;
    st.score += v;
    final dmg = (st.v['dmg'] ?? 0) + v;
    if (dmg >= ship) {
      st.hits++;
      st.v['dmg'] = dmg - ship;
      t.note = 'NAVIRE ${st.hits} COULÉ !';
      if (st.hits >= 3) {
        st.v['chance'] = 1;
        st.v['dmg'] = 0;
        t.maxDarts = t.darts.length; // la chance au trésor arrive
      }
    } else {
      st.v['dmg'] = dmg;
    }
  }

  @override
  void onTurnEnd(PracticeGame g, int p, PracticeTurn t) {
    final st = g.stateOf(p);
    final chance = st.v['chance'] ?? 0;
    if (chance == 1 && t.note?.contains('COULÉ') != true) {
      // Fin de la chance au trésor : bonus de vitesse
      final bonus = (_rounds - g.round) * 100;
      st.score += bonus;
      t.note = 'TRÉSOR · VITESSE +$bonus';
      st.v['chance'] = 2;
      st.done = true;
    }
  }
}
