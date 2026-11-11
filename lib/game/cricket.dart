// Moteur Cricket et ses variantes (Standard, Cut Throat, Caché, Cut Throat
// caché, Wildcard, No Score, Triple Only), en individuel ou en équipes.
//
// Pur Dart, même principe que le 01 : l'état est recalculé en rejouant les
// actions (annuler = retirer la dernière). Les tirages au hasard (Caché,
// Wildcard) viennent d'une graine enregistrée dans les réglages : le
// téléphone et la TV obtiennent exactement les mêmes cibles.

import 'dart:math';

import '../granboard.dart';
import 'darts_game.dart';
import 'x01.dart' show X01Player;

enum CricketVariant {
  standard,
  cutThroat,
  hidden,
  hiddenCutThroat,
  wildcard,
  noScore,
  tripleOnly,
  mickeyMouse,
}

extension CricketVariantInfo on CricketVariant {
  String get label => switch (this) {
        CricketVariant.standard => 'Cricket',
        CricketVariant.cutThroat => 'Cut Throat',
        CricketVariant.hidden => 'Cricket caché',
        CricketVariant.hiddenCutThroat => 'Cut Throat caché',
        CricketVariant.wildcard => 'Wildcard',
        CricketVariant.noScore => 'No Score',
        CricketVariant.tripleOnly => 'Triple Only',
        CricketVariant.mickeyMouse => 'Mickey Mouse',
      };

  String get help => switch (this) {
        CricketVariant.standard =>
          '20 à 15 et Bull. 3 marques ferment un numéro, puis il rapporte des '
              'points tant qu\'un adversaire ne l\'a pas fermé. Tout fermer avec '
              'le meilleur score pour gagner.',
        CricketVariant.cutThroat =>
          'Les points vont aux adversaires qui n\'ont pas fermé le numéro. '
              'Le plus petit score gagne.',
        CricketVariant.hidden =>
          '7 cibles cachées au hasard (1 à 20 et Bull) : touche un numéro pour '
              'le découvrir. Puis règles du Cricket.',
        CricketVariant.hiddenCutThroat =>
          'Cibles cachées comme le Cricket caché, points donnés aux '
              'adversaires comme le Cut Throat.',
        CricketVariant.wildcard =>
          '6 numéros tirés entre 7 et 20 (+ Bull) : tant que personne ne les '
              'a marqués, ils changent à chaque manche.',
        CricketVariant.noScore =>
          'Pas de points : le premier qui ferme tout gagne.',
        CricketVariant.tripleOnly =>
          '20 à 15 sans Bull, seuls les triples comptent (un triple ferme).',
        CricketVariant.mickeyMouse =>
          '20 à 12, puis Doubles, Triples et Bull. N\'importe quel double '
              'ou triple marque sur « D » ou « T » quand son numéro ne sert plus.',
      };

  bool get cutThroat =>
      this == CricketVariant.cutThroat ||
      this == CricketVariant.hiddenCutThroat;

  bool get hidden =>
      this == CricketVariant.hidden || this == CricketVariant.hiddenCutThroat;

  bool get scoring => this != CricketVariant.noScore;
}

const kCricketRoundLimits = <int?>[10, 15, 20, 25, 30, null];

class CricketSettings {
  final CricketVariant variant;

  /// Équipes (Team Cricket) : les marques et le score sont communs à l'équipe.
  final bool teams;

  /// Nombre de manches maximum (null = illimité).
  final int? roundLimit;

  /// Graine des tirages au hasard (Caché, Wildcard).
  final int seed;

  const CricketSettings({
    this.variant = CricketVariant.standard,
    this.teams = false,
    this.roundLimit = 20,
    this.seed = 0,
  });

  String get name => teams ? 'Team ${variant.label}' : variant.label;

  String get rulesLabel => [
        if (variant.cutThroat) 'Plus petit score gagne',
        if (variant == CricketVariant.noScore) 'Sans points',
        roundLimit == null ? 'Sans limite' : '$roundLimit manches',
      ].join(' · ');

  CricketSettings withSeed(int s) => CricketSettings(
      variant: variant, teams: teams, roundLimit: roundLimit, seed: s);

  Map<String, dynamic> toJson() => {
        'v': variant.name,
        'teams': teams,
        if (roundLimit != null) 'rounds': roundLimit,
        'seed': seed,
      };

  factory CricketSettings.fromJson(Map<String, dynamic> j) => CricketSettings(
        variant: CricketVariant.values.firstWhere((v) => v.name == j['v'],
            orElse: () => CricketVariant.standard),
        teams: j['teams'] as bool? ?? false,
        roundLimit: (j['rounds'] as num?)?.toInt(),
        seed: (j['seed'] as num?)?.toInt() ?? 0,
      );
}

/// Une cible du Cricket (25 = Bull).
/// Cibles spéciales du Mickey Mouse.
const kDoublesTarget = 101;
const kTriplesTarget = 102;

class CricketTarget {
  int number;
  bool revealed;
  CricketTarget(this.number, {this.revealed = true});

  String get label => switch (number) {
        25 => 'BULL',
        kDoublesTarget => 'D',
        kTriplesTarget => 'T',
        _ => '$number',
      };

  /// Cible « Doubles » ou « Triples » (Mickey Mouse).
  bool get special => number == kDoublesTarget || number == kTriplesTarget;
}

class CricketDart {
  final DartHit? hit;

  /// Marques utiles (fermeture + marques qui ont rapporté des points).
  final int marks;

  /// Points marqués (Cut Throat : points donnés aux adversaires).
  final int points;

  /// Cette fléchette a découvert une cible cachée.
  final bool revealed;

  const CricketDart(this.hit,
      {this.marks = 0, this.points = 0, this.revealed = false});
}

class CricketTurn {
  final int player;
  final int round;
  final List<CricketDart> darts = [];
  CricketTurn(this.player, this.round);

  int get marks => darts.fold(0, (s, d) => s + d.marks);
}

class CricketPlayerStats {
  int darts = 0;
  int marks = 0;
  int points = 0;
  int bestTurn = 0; // marques sur une manche
  int turns5 = 0; // manches à 5 marques ou plus

  /// Marques par manche (3 fléchettes).
  double get mpr => darts == 0 ? 0 : marks * 3 / darts;
}

enum CricketEnd { closed, roundLimit }

class CricketGame implements DartsGame {
  final CricketSettings settings;
  @override
  final List<X01Player> players;

  final List<(bool, DartHit?)> _actions = [];

  // État recalculé
  late List<CricketTarget> targets;
  late List<int> _sides; // équipes (ou index des joueurs)
  late Map<int, List<int>> _marks; // côté → marques par cible (0 à 3)
  late Map<int, int> _score;
  late List<CricketPlayerStats> _stats;
  late List<CricketTurn> _turns;
  int _current = 0;
  int _round = 1;
  List<int> _winners = [];
  CricketEnd? _end;

  CricketGame(this.settings, this.players) {
    if (players.isEmpty) throw ArgumentError('Aucun joueur');
    if (settings.teams && players.map((p) => p.team).toSet().length < 2) {
      throw ArgumentError('Le Team Cricket se joue avec au moins 2 équipes');
    }
    _reset();
  }

  factory CricketGame.fromJson(Map<String, dynamic> j) {
    final g = CricketGame(
      CricketSettings.fromJson(Map<String, dynamic>.from(j['settings'] as Map)),
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

  // ─── Interface commune ───

  @override
  String get kind => 'cricket';
  @override
  String get title => settings.name;
  @override
  String get rulesLabel => settings.rulesLabel;
  @override
  int get current => _current;
  @override
  X01Player get currentPlayer => players[_current];
  @override
  int get round => _round;
  @override
  int? get roundLimit => settings.roundLimit;
  @override
  bool get finished => _end != null;
  CricketEnd? get endReason => _end;
  @override
  bool get turnOver => finished || currentTurn.darts.length >= 3;
  @override
  bool get canUndo => _actions.isNotEmpty;
  @override
  List<int> get winners => List.unmodifiable(_winners);
  @override
  List<DartHit?> get turnHits => [for (final d in currentTurn.darts) d.hit];

  @override
  List<String> get actionLog =>
      [for (final (n, h) in _actions) logEntryOf(n, h)];

  @override
  Map<String, dynamic> toJson() => {
        'kind': kind,
        'settings': settings.toJson(),
        'players': [for (final p in players) p.toJson()],
        'actions': actionLog,
      };

  @override
  bool applyLogEntry(String a) {
    final e = parseLogEntry(a);
    if (e == null) return false;
    return e.$1 ? next() : throwDart(e.$2);
  }

  @override
  bool throwDart(DartHit? hit) => _push((false, hit));

  @override
  bool next() => _push((true, null));

  @override
  bool undo() {
    if (_actions.isEmpty) return false;
    _actions.removeLast();
    _reset();
    for (final a in _actions) {
      _apply(a);
    }
    return true;
  }

  // ─── Lecture de l'état ───

  CricketTurn get currentTurn => _turns.last;
  List<CricketTurn> get turns => List.unmodifiable(_turns);
  CricketVariant get variant => settings.variant;

  /// Côtés de la partie : équipes en Team, sinon un par joueur.
  List<int> get sides => List.unmodifiable(_sides);
  int sideOf(int player) => settings.teams ? players[player].team : player;
  List<int> membersOf(int side) => [
        for (var i = 0; i < players.length; i++)
          if (sideOf(i) == side) i
      ];

  int marksOf(int side, int target) => _marks[side]![target];
  int scoreOf(int side) => _score[side]!;
  CricketPlayerStats statsOf(int player) => _stats[player];
  int dartsLeft() => turnOver ? 0 : 3 - currentTurn.darts.length;

  bool closedBy(int side, int target) => _marks[side]![target] >= 3;

  /// Fermé par tout le monde : ne rapporte plus rien.
  bool dead(int target) => _sides.every((s) => closedBy(s, target));

  bool allClosed(int side) =>
      List.generate(targets.length, (t) => closedBy(side, t)).every((x) => x);

  int closedMarks(int side) =>
      _marks[side]!.fold(0, (s, m) => s + (m > 3 ? 3 : m));

  /// Cut Throat : ne peut plus finir premier (un adversaire a tout fermé avec
  /// moins de points : personne ne peut plus lui en donner).
  bool isSpoiler(int side) {
    if (!variant.cutThroat || _sides.length < 3) return false;
    return _sides
        .any((x) => x != side && allClosed(x) && _score[x]! < _score[side]!);
  }

  /// Classement des côtés (meilleur d'abord).
  List<int> get sideRanking {
    final r = [..._sides];
    int cmp(int a, int b) {
      final wa = _winners.any((i) => sideOf(i) == a) ? 0 : 1;
      final wb = _winners.any((i) => sideOf(i) == b) ? 0 : 1;
      if (wa != wb) return wa - wb;
      if (variant.scoring) {
        final c = variant.cutThroat
            ? _score[a]!.compareTo(_score[b]!)
            : _score[b]!.compareTo(_score[a]!);
        if (c != 0) return c;
      }
      return closedMarks(b).compareTo(closedMarks(a));
    }

    r.sort(cmp);
    return r;
  }

  // ─── Règles ───

  bool _push((bool, DartHit?) a) {
    if (!_apply(a)) return false;
    _actions.add(a);
    return true;
  }

  bool _apply((bool, DartHit?) a) => a.$1 ? _applyNext() : _applyDart(a.$2);

  void _reset() {
    _sides = settings.teams
        ? (players.map((p) => p.team).toSet().toList()..sort())
        : List.generate(players.length, (i) => i);
    targets = _initialTargets();
    _marks = {for (final s in _sides) s: List.filled(targets.length, 0)};
    _score = {for (final s in _sides) s: 0};
    _stats = [for (final _ in players) CricketPlayerStats()];
    _current = 0;
    _round = 1;
    _winners = [];
    _end = null;
    _turns = [CricketTurn(0, 1)];
  }

  List<CricketTarget> _initialTargets() {
    final rnd = Random(settings.seed);
    switch (variant) {
      case CricketVariant.tripleOnly:
        return [for (var n = 20; n >= 15; n--) CricketTarget(n)];
      case CricketVariant.mickeyMouse:
        return [
          for (var n = 20; n >= 12; n--) CricketTarget(n),
          CricketTarget(kDoublesTarget),
          CricketTarget(kTriplesTarget),
          CricketTarget(25),
        ];
      case CricketVariant.hidden:
      case CricketVariant.hiddenCutThroat:
        final pool = [for (var n = 1; n <= 20; n++) n, 25]..shuffle(rnd);
        return [
          for (final n in pool.take(7)) CricketTarget(n, revealed: false)
        ];
      case CricketVariant.wildcard:
        final pool = [for (var n = 7; n <= 20; n++) n]..shuffle(rnd);
        final six = pool.take(6).toList()..sort((a, b) => b - a);
        return [for (final n in six) CricketTarget(n), CricketTarget(25)];
      default:
        return [
          for (var n = 20; n >= 15; n--) CricketTarget(n),
          CricketTarget(25)
        ];
    }
  }

  /// Wildcard : les numéros que personne n'a marqués sont retirés.
  void _redrawWildcard() {
    final rnd = Random(settings.seed * 7919 + _round);
    for (var t = 0; t < targets.length; t++) {
      if (targets[t].number == 25) continue;
      if (_sides.any((s) => _marks[s]![t] > 0)) continue;
      final used = {for (final x in targets) x.number};
      final free = [
        for (var n = 7; n <= 20; n++)
          if (!used.contains(n)) n
      ];
      if (free.isEmpty) continue;
      free.add(targets[t].number); // peut retomber sur le même
      targets[t].number = free[rnd.nextInt(free.length)];
    }
  }

  int _marksFor(DartHit h) {
    if (variant == CricketVariant.tripleOnly) {
      return h.ring == Ring.triple ? 3 : 0;
    }
    if (h.isBull) return h.ring == Ring.innerBull ? 2 : 1;
    return h.multiplier;
  }

  bool _applyDart(DartHit? hit) {
    if (turnOver) return false;
    final t = currentTurn;
    final st = _stats[_current];
    st.darts++;
    if (hit == null) {
      t.darts.add(const CricketDart(null));
      return true;
    }
    final number = hit.isBull ? 25 : hit.number;
    var slot = targets.indexWhere((x) => x.number == number);
    var m = slot < 0 ? 0 : _marksFor(hit);
    // Mickey Mouse : un double / triple dont le numéro ne sert plus marque
    // 1 sur « D » / « T »
    if (variant == CricketVariant.mickeyMouse && !hit.isBull) {
      final sp = hit.ring == Ring.double
          ? targets.indexWhere((x) => x.number == kDoublesTarget)
          : hit.ring == Ring.triple
              ? targets.indexWhere((x) => x.number == kTriplesTarget)
              : -1;
      final side = sideOf(_current);
      final useless = slot < 0 ||
          (closedBy(side, slot) &&
              _sides.every((o) => o == side || closedBy(o, slot)));
      if (sp >= 0 && useless) {
        slot = sp;
        m = 1;
      }
    }
    if (slot < 0 || m == 0) {
      t.darts.add(CricketDart(hit));
      return true;
    }
    var revealed = false;
    if (!targets[slot].revealed) {
      targets[slot].revealed = true;
      revealed = true;
    }
    final side = sideOf(_current);
    final mine = _marks[side]!;
    final toClose = (3 - mine[slot]).clamp(0, 3);
    final closing = m < toClose ? m : toClose;
    final extra = m - closing;
    mine[slot] = (mine[slot] + m).clamp(0, 3);

    var counted = closing;
    var points = 0;
    if (extra > 0 && variant.scoring) {
      final value = targets[slot].special ? hit.score * extra : number * extra;
      final open = [
        for (final s in _sides)
          if (s != side && !closedBy(s, slot)) s
      ];
      if (variant.cutThroat) {
        for (final s in open) {
          _score[s] = _score[s]! + value;
        }
        if (open.isNotEmpty) {
          points = value * open.length;
          counted += extra;
        }
      } else if (open.isNotEmpty || _sides.length == 1) {
        _score[side] = _score[side]! + value;
        points = value;
        counted += extra;
      }
    }
    st.marks += counted;
    st.points += points;
    t.darts.add(
        CricketDart(hit, marks: counted, points: points, revealed: revealed));
    _checkWin();
    if (finished) _closeTurn(t);
    return true;
  }

  void _checkWin() {
    // Le côté qui joue d'abord, puis les autres (Cut Throat : donner des
    // points peut faire gagner un adversaire qui a déjà tout fermé)
    final me = sideOf(_current);
    for (final s in [me, ..._sides.where((x) => x != me)]) {
      if (!allClosed(s)) continue;
      final others = _sides.where((x) => x != s).map((x) => _score[x]!);
      final ok = !variant.scoring ||
          others.isEmpty ||
          (variant.cutThroat
              ? others.every((o) => _score[s]! <= o)
              : others.every((o) => _score[s]! >= o));
      if (ok) {
        _winners = membersOf(s);
        _end = CricketEnd.closed;
        return;
      }
    }
  }

  void _closeTurn(CricketTurn t) {
    final st = _stats[t.player];
    final m = t.marks;
    if (m > st.bestTurn) st.bestTurn = m;
    if (m >= 5) st.turns5++;
  }

  bool _applyNext() {
    if (finished) return false;
    final t = currentTurn;
    if (t.darts.length < 3) {
      final missing = 3 - t.darts.length;
      for (var i = 0; i < missing; i++) {
        t.darts.add(const CricketDart(null));
      }
      _stats[_current].darts += missing;
    }
    _closeTurn(t);
    _current = (_current + 1) % players.length;
    if (_current == 0) {
      _round++;
      final limit = settings.roundLimit;
      if (limit != null && _round > limit) {
        _round = limit;
        _current = players.length - 1;
        _endByLimit();
        return true;
      }
      if (variant == CricketVariant.wildcard) _redrawWildcard();
    }
    _turns.add(CricketTurn(_current, _round));
    return true;
  }

  void _endByLimit() {
    int key(int s) => !variant.scoring
        ? closedMarks(s)
        : variant.cutThroat
            ? -_score[s]!
            : _score[s]!;
    final best = _sides.map(key).reduce(max);
    var top = _sides.where((s) => key(s) == best).toList();
    if (top.length > 1 && variant.scoring) {
      // Égalité de points : le plus de marques départage
      final bm = top.map(closedMarks).reduce(max);
      top = top.where((s) => closedMarks(s) == bm).toList();
    }
    _winners = [for (final s in top) ...membersOf(s)];
    _end = CricketEnd.roundLimit;
  }
}
