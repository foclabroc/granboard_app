// Moteur X01 (301 / 501 / 701 / 901) et Freeze 01.
//
// Pur Dart, sans Flutter : l'interface (téléphone aujourd'hui, TV plus tard)
// ne fait qu'envoyer des actions (fléchette, raté, joueur suivant, annuler)
// et lire l'état.
//
// L'état est recalculé en rejouant la liste des actions : « annuler » consiste
// simplement à retirer la dernière action, sans risque d'incohérence.

import '../granboard.dart';
import 'darts_game.dart';
import '../format.dart';

enum InRule { open, double, master }

enum OutRule { open, double, master }

enum BullMode { split, fat }

const kStartScores = [301, 501, 701, 901];

extension InRuleLabel on InRule {
  String get label => switch (this) {
        InRule.open => 'Open In',
        InRule.double => 'Double In',
        InRule.master => 'Master In',
      };
}

extension OutRuleLabel on OutRule {
  String get label => switch (this) {
        OutRule.open => 'Open Out',
        OutRule.double => 'Double Out',
        OutRule.master => 'Master Out',
      };
}

extension BullModeLabel on BullMode {
  String get label => switch (this) {
        BullMode.split => 'Bull 25/50',
        BullMode.fat => 'Bull 50/50',
      };
}

class X01Settings {
  final int startScore;
  final InRule inRule;
  final OutRule outRule;
  final BullMode bullMode;

  /// Nombre de manches maximum (null = illimité). À la fin, le plus petit
  /// score restant gagne (total d'équipe en Freeze).
  final int? roundLimit;

  /// Freeze 01 : jeu en équipes, une équipe dont le total restant est
  /// supérieur à celui de l'adversaire est « gelée » et ne peut pas finir.
  final bool freeze;

  const X01Settings({
    this.startScore = 501,
    this.inRule = InRule.open,
    this.outRule = OutRule.double,
    this.bullMode = BullMode.split,
    this.roundLimit,
    this.freeze = false,
  });

  String get name => freeze ? 'Freeze $startScore' : '$startScore';

  Map<String, dynamic> toJson() => {
        'start': startScore,
        'in': inRule.index,
        'out': outRule.index,
        'bull': bullMode.index,
        if (roundLimit != null) 'rounds': roundLimit,
        'freeze': freeze,
      };

  factory X01Settings.fromJson(Map<String, dynamic> j) => X01Settings(
        startScore: (j['start'] as num?)?.toInt() ?? 501,
        inRule: InRule.values[(j['in'] as num?)?.toInt() ?? 0],
        outRule: OutRule.values[(j['out'] as num?)?.toInt() ?? 1],
        bullMode: BullMode.values[(j['bull'] as num?)?.toInt() ?? 0],
        roundLimit: (j['rounds'] as num?)?.toInt(),
        freeze: j['freeze'] as bool? ?? false,
      );

  String get rulesLabel => [
        inRule.label,
        outRule.label,
        bullMode.label,
        if (roundLimit != null) plural(roundLimit!, 'manche'),
      ].join(' · ');
}

class X01Player {
  final String id;
  final String name;

  /// Équipe (Freeze). En individuel, chaque joueur a sa propre équipe.
  final int team;

  const X01Player({required this.id, required this.name, this.team = 0});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'team': team};

  factory X01Player.fromJson(Map<String, dynamic> j) => X01Player(
        id: '${j['id']}',
        name: '${j['name']}',
        team: (j['team'] as num?)?.toInt() ?? 0,
      );
}

/// Une fléchette lancée : [hit] null = ratée (hors cible ou bouton « Raté »).
class ThrownDart {
  final DartHit? hit;

  /// Points réellement décomptés (0 si raté ou joueur pas encore ouvert).
  final int points;

  const ThrownDart(this.hit, this.points);

  String get label {
    final h = hit;
    if (h == null) return 'Raté';
    return h.label;
  }
}

enum BustReason { overshoot, leftOne, badFinish, frozen }

extension BustReasonLabel on BustReason {
  String get label => switch (this) {
        BustReason.overshoot => 'Score dépassé',
        BustReason.leftOne => 'Reste 1 : impossible à finir',
        BustReason.badFinish => 'Mauvaise fléchette de fin',
        BustReason.frozen => 'Équipe gelée : fin interdite',
      };
}

class Turn {
  final int player;
  final int round;
  final int scoreBefore;
  final bool openedBefore;
  final List<ThrownDart> darts = [];
  BustReason? bust;
  bool checkout = false;

  Turn(this.player, this.round, this.scoreBefore, this.openedBefore);

  bool get isBust => bust != null;

  /// Points marqués pendant la manche (0 si bust).
  int get total => isBust ? 0 : darts.fold(0, (s, d) => s + d.points);
}

class PlayerState {
  int remaining;
  bool opened;

  // Statistiques de la partie
  int darts = 0;
  int points = 0;
  int highestTurn = 0;
  int count180 = 0;
  int count100 = 0; // manches à 100 ou plus (180 compris)
  int? checkout;

  PlayerState(this.remaining, this.opened);

  /// Moyenne sur 3 fléchettes.
  double get average => darts == 0 ? 0 : points * 3 / darts;
}

enum EndReason { checkout, roundLimit }

sealed class _Action {
  const _Action();
}

class _DartAction extends _Action {
  final DartHit? hit;
  const _DartAction(this.hit);
}

class _NextAction extends _Action {
  const _NextAction();
}

class X01Game implements DartsGame {
  final X01Settings settings;

  /// Joueurs dans l'ordre de lancer.
  @override
  final List<X01Player> players;

  final List<_Action> _actions = [];

  // État recalculé
  late List<PlayerState> _states;
  late List<Turn> _turns;
  int _current = 0;
  int _round = 1;
  List<int> _winners = [];
  EndReason? _endReason;

  X01Game(this.settings, this.players) {
    if (players.isEmpty) throw ArgumentError('Aucun joueur');
    if (settings.freeze) {
      final teams = players.map((p) => p.team).toSet();
      if (teams.length < 2) {
        throw ArgumentError('Le Freeze se joue avec au moins 2 équipes');
      }
    }
    _reset();
  }

  // ─── Interface commune ───

  @override
  String get kind => 'x01';
  @override
  String get title => settings.name;
  @override
  String get rulesLabel => settings.rulesLabel;
  @override
  int? get roundLimit => settings.roundLimit;
  @override
  List<DartHit?> get turnHits => [for (final d in currentTurn.darts) d.hit];

  // ─── Lecture de l'état ───

  @override
  int get current => _current;
  @override
  X01Player get currentPlayer => players[_current];
  PlayerState get currentState => _states[_current];
  @override
  int get round => _round;
  List<Turn> get turns => List.unmodifiable(_turns);
  Turn get currentTurn => _turns.last;
  @override
  bool get finished => _endReason != null;
  EndReason? get endReason => _endReason;
  @override
  List<int> get winners => List.unmodifiable(_winners);
  @override
  bool get canUndo => _actions.isNotEmpty;

  /// Nombre d'actions jouées (fléchettes + « suivant »).
  int get actionCount => _actions.length;

  // ─── Sérialisation (écran TV, jeu à distance) ───
  // Actions : « n » = suivant, « m » = ratée, « d:<numéro>:<anneau> » = fléchette.

  @override
  List<String> get actionLog => [
        for (final a in _actions)
          switch (a) {
            _NextAction() => 'n',
            _DartAction(:final hit) =>
              hit == null ? 'm' : 'd:${hit.number}:${hit.ring.index}',
          }
      ];

  @override
  Map<String, dynamic> toJson() => {
        'kind': kind,
        'settings': settings.toJson(),
        'players': [for (final p in players) p.toJson()],
        'actions': actionLog,
      };

  /// Rejoue une partie envoyée par [toJson] (actions invalides ignorées).
  factory X01Game.fromJson(Map<String, dynamic> j) {
    final g = X01Game(
      X01Settings.fromJson(Map<String, dynamic>.from(j['settings'] as Map)),
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

  /// Applique une action du journal ; renvoie false si elle est refusée.
  @override
  bool applyLogEntry(String a) {
    if (a == 'n') return next();
    if (a == 'm') return throwDart(null);
    final p = a.split(':');
    if (p.length != 3 || p[0] != 'd') return false;
    final n = int.tryParse(p[1]);
    final r = int.tryParse(p[2]);
    if (n == null || r == null || r < 0 || r >= Ring.values.length) {
      return false;
    }
    return throwDart(GranBoardDecoder.hitFor(n, Ring.values[r]));
  }

  PlayerState stateOf(int i) => _states[i];

  /// La manche du joueur est terminée (3 fléchettes, bust ou victoire) :
  /// on attend « joueur suivant ».
  @override
  bool get turnOver {
    final t = currentTurn;
    return finished || t.darts.length >= 3 || t.isBust || t.checkout;
  }

  int get dartsLeft => turnOver ? 0 : 3 - currentTurn.darts.length;

  List<int> get teams => players.map((p) => p.team).toSet().toList()..sort();

  List<int> membersOf(int team) => [
        for (var i = 0; i < players.length; i++)
          if (players[i].team == team) i
      ];

  int teamRemaining(int team) =>
      membersOf(team).fold(0, (s, i) => s + _states[i].remaining);

  /// Freeze : le joueur est gelé si le total de son équipe est supérieur
  /// au plus petit total des équipes adverses.
  bool isFrozen(int player) {
    if (!settings.freeze) return false;
    final team = players[player].team;
    final mine = teamRemaining(team);
    final others = teams.where((t) => t != team).map(teamRemaining);
    return mine > others.reduce((a, b) => a < b ? a : b);
  }

  /// Dernière manche jouée par le joueur (null s'il n'a pas encore joué).
  Turn? lastTurnOf(int player) {
    for (var i = _turns.length - 1; i >= 0; i--) {
      final t = _turns[i];
      if (t.player == player && (t != currentTurn || turnOver)) return t;
    }
    return null;
  }

  /// Fins possibles pour le joueur en cours (meilleure d'abord, 3 au plus).
  List<List<String>> get checkoutOptions {
    if (finished || turnOver) return const [];
    final s = currentState;
    if (!s.opened || isFrozen(_current)) return const [];
    return checkoutRoutes(
        s.remaining, dartsLeft, settings.outRule, settings.bullMode);
  }

  /// Suggestion de fin pour le joueur en cours (null si aucune).
  List<String>? get checkoutHint {
    if (finished || turnOver) return null;
    final s = currentState;
    if (!s.opened || isFrozen(_current)) return null;
    return suggestCheckout(
        s.remaining, dartsLeft, settings.outRule, settings.bullMode);
  }

  // ─── Actions ───

  /// Fléchette détectée par la cible ([hit] null = ratée).
  /// Renvoie false si elle est ignorée (manche déjà terminée).
  @override
  bool throwDart(DartHit? hit) => _push(_DartAction(hit));

  /// Joueur suivant (bouton de la cible ou de l'écran). Les fléchettes
  /// non lancées de la manche comptent comme ratées.
  @override
  bool next() => _push(const _NextAction());

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

  bool _push(_Action a) {
    if (!_apply(a)) return false;
    _actions.add(a);
    return true;
  }

  void _reset() {
    final opened = settings.inRule == InRule.open;
    _states = [
      for (final _ in players) PlayerState(settings.startScore, opened)
    ];
    _current = 0;
    _round = 1;
    _winners = [];
    _endReason = null;
    _turns = [Turn(0, 1, settings.startScore, opened)];
  }

  bool _apply(_Action a) => switch (a) {
        _DartAction(:final hit) => _applyDart(hit),
        _NextAction() => _applyNext(),
      };

  bool _applyDart(DartHit? hit) {
    if (turnOver) return false;
    final s = currentState;
    final t = currentTurn;

    final value = _value(hit, settings.bullMode);
    final isDouble = _isDoubleLike(hit, settings.bullMode);
    final isMaster = _isMasterLike(hit, settings.bullMode);

    var counted = value;
    if (!s.opened) {
      final opens = switch (settings.inRule) {
        InRule.open => true,
        InRule.double => isDouble,
        InRule.master => isMaster,
      };
      if (opens) {
        s.opened = true;
      } else {
        counted = 0;
      }
    }

    final frozen = isFrozen(_current); // avant la fléchette
    t.darts.add(ThrownDart(hit, counted));
    s.darts++;
    s.points += counted;

    final left = s.remaining - counted;
    BustReason? bust;
    var finish = false;

    if (left < 0) {
      bust = BustReason.overshoot;
    } else if (left == 0) {
      final okFinish = switch (settings.outRule) {
        OutRule.open => true,
        OutRule.double => isDouble,
        OutRule.master => isMaster,
      };
      if (!okFinish) {
        bust = BustReason.badFinish;
      } else if (frozen) {
        bust = BustReason.frozen;
      } else {
        finish = true;
      }
    } else if (left == 1 && settings.outRule != OutRule.open) {
      bust = BustReason.leftOne;
    }

    if (bust != null) {
      // Retour au score du début de manche, les points de la manche sont perdus
      s.points -= t.darts.fold<int>(0, (sum, d) => sum + d.points);
      s.remaining = t.scoreBefore;
      s.opened = t.openedBefore;
      t.bust = bust;
      return true;
    }

    s.remaining = left;
    if (finish) {
      t.checkout = true;
      s.checkout = t.total;
      _closeTurnStats(t);
      _winners = settings.freeze ? membersOf(currentPlayer.team) : [_current];
      _endReason = EndReason.checkout;
    } else if (t.darts.length >= 3) {
      _closeTurnStats(t);
    }
    return true;
  }

  bool _applyNext() {
    if (finished) return false;
    final t = currentTurn;
    final s = currentState;
    if (!turnOver) {
      // Fléchettes non lancées = ratées
      final missing = 3 - t.darts.length;
      for (var i = 0; i < missing; i++) {
        t.darts.add(const ThrownDart(null, 0));
      }
      s.darts += missing;
      _closeTurnStats(t);
    } else if (t.isBust) {
      // Les fléchettes non lancées après un bust comptent dans la moyenne
      s.darts += 3 - t.darts.length;
    }

    _current = (_current + 1) % players.length;
    if (_current == 0) _round++;

    final limit = settings.roundLimit;
    if (limit != null && _round > limit) {
      _round = limit;
      _current = (_current - 1 + players.length) % players.length;
      _endByLimit();
      return true;
    }

    final n = currentState;
    _turns.add(Turn(_current, _round, n.remaining, n.opened));
    return true;
  }

  void _closeTurnStats(Turn t) {
    final s = _states[t.player];
    final total = t.total;
    if (total > s.highestTurn) s.highestTurn = total;
    if (total >= 100) s.count100++;
    if (total == 180) s.count180++;
  }

  void _endByLimit() {
    if (settings.freeze) {
      final scores = {for (final t in teams) t: teamRemaining(t)};
      final best = scores.values.reduce((a, b) => a < b ? a : b);
      _winners = [
        for (final t in teams)
          if (scores[t] == best) ...membersOf(t)
      ];
    } else {
      final best =
          _states.map((s) => s.remaining).reduce((a, b) => a < b ? a : b);
      _winners = [
        for (var i = 0; i < players.length; i++)
          if (_states[i].remaining == best) i
      ];
    }
    _endReason = EndReason.roundLimit;
  }
}

// ─── Valeur des fléchettes selon le mode de bull ───

int _value(DartHit? h, BullMode bull) {
  if (h == null) return 0;
  if (h.isBull && bull == BullMode.fat) return 50;
  return h.score;
}

bool _isDoubleLike(DartHit? h, BullMode bull) {
  if (h == null) return false;
  if (h.isBull && bull == BullMode.fat) return true;
  return h.isDouble;
}

bool _isMasterLike(DartHit? h, BullMode bull) {
  if (h == null) return false;
  return h.isBull || h.multiplier >= 2;
}

// ─── Suggestion de fin ───

class _Dart {
  final String label;
  final int value;
  final bool isDouble;
  final bool isMaster;
  const _Dart(this.label, this.value, this.isDouble, this.isMaster);
}

List<_Dart> _setupDarts(BullMode bull) => [
      for (var n = 20; n >= 1; n--) _Dart('T$n', n * 3, false, true),
      for (var n = 20; n >= 1; n--) _Dart('$n', n, false, false),
      if (bull == BullMode.split) const _Dart('25', 25, false, true),
      const _Dart('BULL', 50, true, true),
    ];

const _preferredDoubles = [
  20,
  16,
  18,
  12,
  10,
  8,
  14,
  6,
  4,
  2,
  19,
  17,
  15,
  13,
  11,
  9,
  7,
  5,
  3,
  1
];

List<_Dart> _finishDarts(OutRule out, BullMode bull) {
  final doubles = [
    for (final n in _preferredDoubles) _Dart('D$n', n * 2, true, true),
    const _Dart('BULL', 50, true, true),
  ];
  return switch (out) {
    OutRule.double => doubles,
    OutRule.master => [
        ...doubles,
        for (var n = 20; n >= 1; n--) _Dart('T$n', n * 3, false, true),
        if (bull == BullMode.split) const _Dart('25', 25, false, true),
      ],
    OutRule.open => [
        for (var n = 20; n >= 1; n--) _Dart('$n', n, false, false),
        if (bull == BullMode.split) const _Dart('25', 25, false, true),
        ...doubles,
        for (var n = 20; n >= 1; n--) _Dart('T$n', n * 3, false, true),
      ],
  };
}

/// Combinaison de fin en [dartsLeft] fléchettes au plus, ou null.
List<String>? suggestCheckout(
    int remaining, int dartsLeft, OutRule out, BullMode bull) {
  final r = checkoutRoutes(remaining, dartsLeft, out, bull, max: 1);
  return r.isEmpty ? null : r.first;
}

/// Fins possibles en [dartsLeft] fléchettes au plus, la meilleure d'abord
/// (en Double Out : celle des tableaux de fins des joueurs), puis jusqu'à
/// [max] - 1 autres. Vide si on ne peut pas finir.
List<List<String>> checkoutRoutes(
    int remaining, int dartsLeft, OutRule out, BullMode bull,
    {int max = 3}) {
  if (remaining <= 0 || dartsLeft <= 0 || remaining > 180) return const [];
  final key = '$remaining|$dartsLeft|${out.name}|${bull.name}|$max';
  return _routesCache[key] ??=
      _computeRoutes(remaining, dartsLeft, out, bull, max);
}

final _routesCache = <String, List<List<String>>>{};

List<List<String>> _computeRoutes(
    int remaining, int dartsLeft, OutRule out, BullMode bull, int max) {
  final setup = _setupDarts(bull);
  final finish = _finishDarts(out, bull);
  final minLeft = out == OutRule.open ? 1 : 2;

  // Toutes les fins, notées (plus petit = mieux)
  final found = <(double, List<String>)>[];
  final seen = <String>{};
  void add(List<_Dart> ds) {
    // T20 T19 D16 et T19 T20 D16 sont la même fin
    final setupKey = [for (final d in ds.sublist(0, ds.length - 1)) d.label]
      ..sort();
    final k = '${setupKey.join(',')}>${ds.last.label}';
    if (!seen.add(k)) return;
    var cost = ds.length * 10.0;
    for (final d in ds.sublist(0, ds.length - 1)) {
      cost += _setupCost(d);
    }
    cost += _finishCost(ds.last);
    found.add((cost, [for (final d in ds) d.label]));
  }

  for (final f in finish) {
    if (f.value == remaining) add([f]);
  }
  if (dartsLeft >= 2) {
    for (final a in setup) {
      final left = remaining - a.value;
      if (left < minLeft) continue;
      for (final f in finish) {
        if (f.value == left) add([a, f]);
      }
    }
  }
  if (dartsLeft >= 3) {
    for (final a in setup) {
      for (final b in setup) {
        final left = remaining - a.value - b.value;
        if (left < minLeft || remaining - a.value < minLeft) continue;
        for (final f in finish) {
          if (f.value == left) add([a, b, f]);
        }
      }
    }
  }
  if (found.isEmpty) return const [];
  found.sort((x, y) => x.$1.compareTo(y.$1));
  final routes = [for (final f in found) f.$2];

  // En Double Out, la fin « classique » passe en premier
  if (out == OutRule.double) {
    final chart = _doubleOutChart[remaining]?.split(' ');
    if (chart != null &&
        chart.length <= dartsLeft &&
        _routeValid(chart, remaining, out, bull)) {
      routes.removeWhere((r) => r.join(' ') == chart.join(' '));
      routes.insert(0, chart);
    }
  }
  return routes.take(max).toList();
}

int? _labelValue(String l, BullMode bull) {
  if (l == 'BULL') return 50;
  if (l == '25') return bull == BullMode.fat ? 50 : 25;
  final m = RegExp(r'^([DT]?)(\d+)$').firstMatch(l);
  if (m == null) return null;
  final n = int.parse(m.group(2)!);
  return n * switch (m.group(1)) { 'D' => 2, 'T' => 3, _ => 1 };
}

bool _routeValid(List<String> r, int remaining, OutRule out, BullMode bull) {
  var sum = 0;
  for (final l in r) {
    final v = _labelValue(l, bull);
    if (v == null) return false;
    sum += v;
  }
  if (sum != remaining) return false;
  return _finishDarts(out, bull).any((d) => d.label == r.last);
}

double _setupCost(_Dart d) {
  if (d.label == 'BULL') return 7;
  if (d.label == '25') return 6;
  if (d.label.startsWith('T')) {
    final n = int.parse(d.label.substring(1));
    return switch (n) {
      20 => 0.0,
      19 => 0.5,
      18 => 1.0,
      17 => 1.5,
      16 => 2.0,
      _ => 4.0
    };
  }
  return 1; // simple : facile à toucher
}

double _finishCost(_Dart d) {
  if (d.label == 'BULL') return 7;
  final i = _preferredDoubles
      .indexOf(int.tryParse(d.label.replaceFirst(RegExp('^[DT]'), '')) ?? 0);
  if (d.label.startsWith('D')) return i < 0 ? 8 : i * 0.5;
  return 3 + (i < 0 ? 5 : i * 0.3); // Master / Open Out : triple ou simple
}

/// Tableau classique des fins en Double Out (3 fléchettes).
const _doubleOutChart = <int, String>{
  170: 'T20 T20 BULL',
  167: 'T20 T19 BULL',
  164: 'T20 T18 BULL',
  161: 'T20 T17 BULL',
  160: 'T20 T20 D20',
  158: 'T20 T20 D19',
  157: 'T20 T19 D20',
  156: 'T20 T20 D18',
  155: 'T20 T19 D19',
  154: 'T20 T18 D20',
  153: 'T20 T19 D18',
  152: 'T20 T20 D16',
  151: 'T20 T17 D20',
  150: 'T20 T18 D18',
  149: 'T20 T19 D16',
  148: 'T20 T16 D20',
  147: 'T20 T17 D18',
  146: 'T20 T18 D16',
  145: 'T20 T15 D20',
  144: 'T20 T20 D12',
  143: 'T20 T17 D16',
  142: 'T20 T14 D20',
  141: 'T20 T19 D12',
  140: 'T20 T20 D10',
  139: 'T19 T14 D20',
  138: 'T20 T18 D12',
  137: 'T20 T19 D10',
  136: 'T20 T20 D8',
  135: 'BULL T15 D20',
  134: 'T20 T14 D16',
  133: 'T20 T19 D8',
  132: 'BULL BULL D16',
  131: 'T20 T13 D16',
  130: 'T20 T20 D5',
  129: 'T19 T16 D12',
  128: 'T18 T14 D16',
  127: 'T20 T17 D8',
  126: 'T19 T19 D6',
  125: '25 T20 D20',
  124: 'T20 T14 D11',
  123: 'T19 T16 D9',
  122: 'T18 T18 D7',
  121: 'T20 T11 D14',
  120: 'T20 20 D20',
  119: 'T19 T12 D13',
  118: 'T20 18 D20',
  117: 'T20 17 D20',
  116: 'T20 16 D20',
  115: 'T20 15 D20',
  114: 'T20 14 D20',
  113: 'T20 13 D20',
  112: 'T20 12 D20',
  111: 'T20 19 D16',
  110: 'T20 BULL',
  109: 'T20 17 D16',
  108: 'T20 16 D16',
  107: 'T19 BULL',
  106: 'T20 6 D20',
  105: 'T20 13 D16',
  104: 'T18 BULL',
  103: 'T19 6 D20',
  102: 'T20 10 D16',
  101: 'T17 BULL',
  100: 'T20 D20',
  99: 'T19 10 D16',
  98: 'T20 D19',
  97: 'T19 D20',
  96: 'T20 D18',
  95: 'T19 D19',
  94: 'T18 D20',
  93: 'T19 D18',
  92: 'T20 D16',
  91: 'T17 D20',
  90: 'T20 D15',
  89: 'T19 D16',
  88: 'T16 D20',
  87: 'T17 D18',
  86: 'T18 D16',
  85: 'T15 D20',
  84: 'T20 D12',
  83: 'T17 D16',
  82: 'T14 D20',
  81: 'T19 D12',
  80: 'T20 D10',
  79: 'T19 D11',
  78: 'T18 D12',
  77: 'T19 D10',
  76: 'T20 D8',
  75: 'T17 D12',
  74: 'T14 D16',
  73: 'T19 D8',
  72: 'T16 D12',
  71: 'T13 D16',
  70: 'T18 D8',
  69: 'T19 D6',
  68: 'T20 D4',
  67: 'T17 D8',
  66: 'T10 D18',
  65: 'T19 D4',
  64: 'T16 D8',
  63: 'T13 D12',
  62: 'T10 D16',
  61: 'T15 D8',
  60: '20 D20',
  59: '19 D20',
  58: '18 D20',
  57: '17 D20',
  56: '16 D20',
  55: '15 D20',
  54: '14 D20',
  53: '13 D20',
  52: '20 D16',
  51: '19 D16',
  50: 'BULL',
  49: '17 D16',
  48: '16 D16',
  47: '15 D16',
  46: '6 D20',
  45: '13 D16',
  44: '4 D20',
  43: '3 D20',
  42: '10 D16',
  41: '9 D16',
  39: '7 D16',
  37: '5 D16',
  35: '3 D16',
  33: '1 D16',
  31: '15 D8',
  29: '13 D8',
  27: '11 D8',
  25: '9 D8',
  23: '7 D8',
  21: '5 D8',
  19: '3 D8',
  17: '1 D8',
  15: '7 D4',
  13: '5 D4',
  11: '3 D4',
  9: '1 D4',
  7: '3 D2',
  5: '1 D2',
  3: '1 D1',
};
