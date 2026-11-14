// MATCH : série de legs en 01 et/ou Cricket (3 à 13 legs). Le premier qui
// gagne la majorité des legs remporte le match. Le joueur qui commence
// tourne à chaque leg.
//
// Même principe que les autres jeux : le journal d'actions de tout le match
// suffit à tout reconstruire (« n » après la fin d'un leg = leg suivant).

import '../granboard.dart';
import 'cricket.dart';
import 'darts_game.dart';
import 'x01.dart';

enum LegKind { x01, cricket }

const kMatchLegs = [3, 5, 7, 9, 11, 13];

class MatchSettings {
  final int legs;

  /// Jeu de chaque leg (au moins [legs] éléments).
  final List<LegKind> pattern;
  final X01Settings x01;
  final CricketSettings cricket;

  /// Score de départ de chaque leg de 01 (301, 501…) ; manquant = celui de
  /// [x01].
  final List<int> starts;

  const MatchSettings({
    this.legs = 3,
    this.pattern = const [LegKind.x01, LegKind.cricket, LegKind.x01],
    this.x01 = const X01Settings(),
    this.cricket = const CricketSettings(),
    this.starts = const [],
  });

  /// Score de départ du leg [leg] (s'il est en 01).
  int startOf(int leg) =>
      leg < starts.length && starts[leg] > 0 ? starts[leg] : x01.startScore;

  /// Règles 01 du leg [leg] (score de départ du leg).
  X01Settings x01For(int leg) => x01.withStart(startOf(leg));

  /// 01, Cricket, 01, Cricket… pour [legs] legs.
  static List<LegKind> alternate(int legs) =>
      [for (var i = 0; i < legs; i++) i.isEven ? LegKind.x01 : LegKind.cricket];

  LegKind kindOf(int leg) =>
      leg < pattern.length ? pattern[leg] : LegKind.values[leg % 2];

  int get winsNeeded => legs ~/ 2 + 1;

  String get patternLabel => [
        for (var i = 0; i < legs; i++)
          kindOf(i) == LegKind.x01 ? '${startOf(i)}' : 'CR'
      ].join('-');

  Map<String, dynamic> toJson() => {
        'legs': legs,
        'pattern': [for (var i = 0; i < legs; i++) kindOf(i).name],
        'starts': [for (var i = 0; i < legs; i++) startOf(i)],
        'x01': x01.toJson(),
        'cricket': cricket.toJson(),
      };

  factory MatchSettings.fromJson(Map<String, dynamic> j) => MatchSettings(
        legs: (j['legs'] as num?)?.toInt() ?? 3,
        pattern: [
          for (final p in (j['pattern'] as List? ?? const []))
            LegKind.values
                .firstWhere((k) => k.name == p, orElse: () => LegKind.x01)
        ],
        x01: X01Settings.fromJson(
            Map<String, dynamic>.from(j['x01'] as Map? ?? const {})),
        cricket: CricketSettings.fromJson(
            Map<String, dynamic>.from(j['cricket'] as Map? ?? const {})),
        starts: [
          for (final s in (j['starts'] as List? ?? const []))
            (s as num).toInt()
        ],
      );
}

class MatchGame implements DartsGame {
  final MatchSettings settings;
  @override
  final List<X01Player> players;

  final List<String> _log = [];
  late List<DartsGame> legs;
  late Map<String, int> _wins;
  List<int> _winners = [];
  bool _over = false;

  MatchGame(this.settings, this.players) {
    if (players.isEmpty) throw ArgumentError('Aucun joueur');
    _reset();
  }

  factory MatchGame.fromJson(Map<String, dynamic> j) {
    final g = MatchGame(
      MatchSettings.fromJson(Map<String, dynamic>.from(j['settings'] as Map)),
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

  /// Leg en cours (ou dernier leg joué).
  DartsGame get leg => legs.last;
  int get legNumber => legs.length;
  int legWinsOf(int player) => _wins[players[player].id] ?? 0;

  /// Le leg en cours est fini, le match continue : « suivant » lance le leg
  /// d'après.
  bool get betweenLegs => leg.finished && !_over;

  /// Vainqueurs (indices dans [players]) de chaque leg terminé.
  List<List<int>> get legWinners => [
        for (final l in legs)
          if (l.finished)
            [
              for (final w in l.winners)
                players.indexWhere((p) => p.id == l.players[w].id)
            ]
      ];

  // ─── Interface commune ───

  @override
  String get kind => 'match';
  @override
  String get title => 'Medley · leg $legNumber/${settings.legs} · ${leg.title}';
  @override
  String get rulesLabel => [
        for (var i = 0; i < players.length; i++)
          '${players[i].name} ${legWinsOf(i)}'
      ].join(' – ');
  @override
  int get current => players.indexWhere((p) => p.id == leg.currentPlayer.id);
  @override
  X01Player get currentPlayer => leg.currentPlayer;
  @override
  int get round => leg.round;
  @override
  int? get roundLimit => leg.roundLimit;
  @override
  bool get finished => _over;
  @override
  bool get turnOver => _over || leg.finished || leg.turnOver;
  @override
  bool get canUndo => _log.isNotEmpty;
  @override
  List<int> get winners => List.unmodifiable(_winners);
  @override
  List<DartHit?> get turnHits => leg.turnHits;
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
    final e = parseLogEntry(a);
    if (e == null) return false;
    return e.$1 ? next() : throwDart(e.$2);
  }

  @override
  bool throwDart(DartHit? hit) {
    if (_over || leg.finished) return false;
    if (!leg.throwDart(hit)) return false;
    _log.add(logEntryOf(false, hit));
    if (leg.finished) _legDone();
    return true;
  }

  @override
  bool next() {
    if (_over) return false;
    if (leg.finished) {
      _newLeg();
    } else {
      if (!leg.next()) return false;
      if (leg.finished) _legDone(); // limite de manches atteinte
    }
    _log.add('n');
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

  // ─── Règles ───

  void _reset() {
    _wins = {for (final p in players) p.id: 0};
    _winners = [];
    _over = false;
    legs = [];
    _newLeg();
  }

  void _newLeg() {
    final k = legs.length;
    // Le joueur qui commence tourne à chaque leg
    final n = players.length;
    final order = [for (var i = 0; i < n; i++) players[(i + k) % n]];
    legs.add(switch (settings.kindOf(k)) {
      LegKind.x01 => X01Game(settings.x01For(k), order),
      LegKind.cricket => CricketGame(
          settings.cricket.withSeed(settings.cricket.seed + k), order),
    });
  }

  void _legDone() {
    for (final w in leg.winners) {
      final id = leg.players[w].id;
      _wins[id] = (_wins[id] ?? 0) + 1;
    }
    final best = _wins.values.fold(0, (a, b) => a > b ? a : b);
    if (best >= settings.winsNeeded || legs.length >= settings.legs) {
      _over = true;
      _winners = [
        for (var i = 0; i < players.length; i++)
          if (legWinsOf(i) == best) i
      ];
    }
  }
}
