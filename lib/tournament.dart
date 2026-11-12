import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game/x01.dart';
import 'online/online.dart';
import 'players.dart';
import 'server.dart';

/// Joueur d'un tableau : [id] = numéro dans le tableau (id serveur en ligne,
/// rang d'inscription à la maison), [key] = identifiant du joueur dans les
/// parties (compte ou `guest-N`).
class TnPlayer {
  final int id;
  final String key;
  final String name;
  final Color color;
  const TnPlayer(
      {required this.id,
      required this.key,
      required this.name,
      required this.color});

  /// Joueur du serveur (fiche courte `gb__on_player`) ou de la TV / la maison
  /// ({id, key, name, color ARGB}).
  factory TnPlayer.fromJson(Map j) {
    if (j.containsKey('key')) {
      return TnPlayer(
          id: (j['id'] as num).toInt(),
          key: '${j['key']}',
          name: '${j['name'] ?? '?'}',
          color: Color((j['color'] as num?)?.toInt() ?? 0xFF8D8D9C));
    }
    final o = OnlinePlayer.fromJson(j);
    return TnPlayer(id: o.id, key: o.key, name: o.name, color: o.color);
  }

  Map<String, dynamic> toJson() =>
      {'id': id, 'key': key, 'name': name, 'color': color.toARGB32()};

  /// Pour un défi en ligne.
  OnlinePlayer get online => OnlinePlayer(
      id: id,
      name: name,
      colorIndex: math.max(0,
          kPlayerColors.indexWhere((c) => c.toARGB32() == color.toARGB32())));
}

/// Tournoi en ligne à élimination directe (`sql/2026-11-12_tournois.sql`).
class Tournament {
  final int id;
  final String name;
  final int size;
  final String label;
  final String status; // open | running | done
  final int rounds;
  final int owner;
  final int? winner;
  final Map<String, dynamic> game;
  final List<TnPlayer> players;
  final List<TnMatch> matches;

  /// Tournoi à la maison (sur ce téléphone, pas de serveur).
  final bool local;

  const Tournament({
    this.local = false,
    required this.id,
    required this.name,
    required this.size,
    required this.label,
    required this.status,
    required this.rounds,
    required this.owner,
    required this.winner,
    required this.game,
    required this.players,
    required this.matches,
  });

  bool get open => status == 'open';
  bool get running => status == 'running';
  bool get done => status == 'done';

  factory Tournament.fromJson(Map<String, dynamic> j) => Tournament(
        local: j['local'] == true,
        id: (j['id'] as num).toInt(),
        name: '${j['name'] ?? ''}',
        size: (j['size'] as num?)?.toInt() ?? 8,
        label: '${j['label'] ?? ''}',
        status: '${j['status'] ?? 'open'}',
        rounds: (j['rounds'] as num?)?.toInt() ?? 0,
        owner: (j['owner'] as num?)?.toInt() ?? 0,
        winner: (j['winner'] as num?)?.toInt(),
        game: Map<String, dynamic>.from(j['game'] as Map? ?? const {}),
        players: [
          for (final p in (j['players'] as List? ?? const []))
            if (p is Map) TnPlayer.fromJson(p)
        ],
        matches: [
          for (final m in (j['matches'] as List? ?? const []))
            TnMatch.fromJson(Map<String, dynamic>.from(m as Map))
        ],
      );

  /// Pour l'écran TV (sans la partie modèle).
  Map<String, dynamic> toJson() => {
        'local': local,
        'id': id,
        'name': name,
        'size': size,
        'label': label,
        'status': status,
        'rounds': rounds,
        'owner': owner,
        'winner': winner,
        'players': [for (final p in players) p.toJson()],
        'matches': [for (final m in matches) m.toJson()],
      };

  /// Prochain match à jouer (le plus haut du tour le moins avancé).
  TnMatch? get nextMatch {
    for (final m in matches) {
      if (m.playable) return m;
    }
    return null;
  }

  /// Le match qui suivra celui en cours ([r], [s]) : « A contre B », ou
  /// « vainqueur de ce match contre … » quand il en dépend. Null en finale.
  String? nextLine(int r, int s) {
    for (final m in matches) {
      if (m.playable && !(m.round == r && m.slot == s)) {
        return '${player(m.a)!.name} contre ${player(m.b)!.name}';
      }
    }
    if (r >= rounds) return null;
    TnMatch? fed;
    for (final m in matches) {
      if (m.round == r + 1 && m.slot == s ~/ 2) fed = m;
    }
    final other = player(s.isEven ? fed?.b : fed?.a);
    return 'Vainqueur de ce match contre ${other?.name ?? 'à venir'}';
  }

  TnPlayer? player(int? id) {
    if (id == null) return null;
    for (final p in players) {
      if (p.id == id) return p;
    }
    return null;
  }

  List<TnMatch> round(int r) => [
        for (final m in matches)
          if (m.round == r) m
      ]..sort((a, b) => a.slot.compareTo(b.slot));

  /// Mon match à jouer (les 2 joueurs connus, pas encore de vainqueur).
  TnMatch? myMatch(int me) {
    for (final m in matches) {
      if (m.playable && (m.a == me || m.b == me)) return m;
    }
    return null;
  }

  /// Nom d'un tour : finale, demi-finales, quarts…
  String roundName(int r) {
    final left = rounds - r;
    return switch (left) {
      0 => 'FINALE',
      1 => 'DEMI-FINALES',
      2 => 'QUARTS',
      3 => 'HUITIÈMES',
      _ => 'TOUR $r',
    };
  }
}

class TnMatch {
  final int round;
  final int slot;
  final int? a;
  final int? b;
  final bool bye;
  final int? winner;
  final bool forfeit;
  const TnMatch(
      {required this.round,
      required this.slot,
      this.a,
      this.b,
      this.bye = false,
      this.winner,
      this.forfeit = false});

  factory TnMatch.fromJson(Map<String, dynamic> j) => TnMatch(
        round: (j['r'] as num).toInt(),
        slot: (j['s'] as num).toInt(),
        a: (j['a'] as num?)?.toInt(),
        b: (j['b'] as num?)?.toInt(),
        bye: j['bye'] == true,
        winner: (j['winner'] as num?)?.toInt(),
        forfeit: j['forfeit'] == true,
      );

  bool get playable => a != null && b != null && winner == null && !bye;

  Map<String, dynamic> toJson() => {
        'r': round,
        's': slot,
        'a': a,
        'b': b,
        'bye': bye,
        'winner': winner,
        'forfeit': forfeit
      };
}

/// Résumé d'un tournoi dans la liste.
class TnSummary {
  final int id;
  final String name;
  final int size;
  final String label;
  final String status;
  final int count;
  final bool joined;
  final OnlinePlayer? owner;
  final OnlinePlayer? winner;
  const TnSummary(
      {required this.id,
      required this.name,
      required this.size,
      required this.label,
      required this.status,
      required this.count,
      required this.joined,
      this.owner,
      this.winner});

  factory TnSummary.fromJson(Map<String, dynamic> j) => TnSummary(
        id: (j['id'] as num).toInt(),
        name: '${j['name'] ?? ''}',
        size: (j['size'] as num?)?.toInt() ?? 8,
        label: '${j['label'] ?? ''}',
        status: '${j['status'] ?? 'open'}',
        count: (j['count'] as num?)?.toInt() ?? 0,
        joined: j['joined'] == true,
        owner: j['owner'] is Map ? OnlinePlayer.fromJson(j['owner']) : null,
        winner: j['winner'] is Map ? OnlinePlayer.fromJson(j['winner']) : null,
      );
}

/// Appels au serveur pour les tournois (lèvent ApiError).
class TournamentApi {
  static Map<String, dynamic> _map(Object? r) =>
      Map<String, dynamic>.from(r as Map);

  static Future<List<TnSummary>> list(String token) async => [
        for (final t
            in (await GbServer.rpc('gb_tn_list', {'p_token': token}) as List? ??
                const []))
          TnSummary.fromJson(_map(t))
      ];

  static Future<Tournament> get(int id) async =>
      Tournament.fromJson(_map(await GbServer.rpc('gb_tn_get', {'p_id': id})));

  static Future<int> create(String token,
          {required String name,
          required int size,
          required String label,
          required Map<String, dynamic> game}) async =>
      ((await GbServer.rpc('gb_tn_create', {
        'p_token': token,
        'p_name': name,
        'p_size': size,
        'p_label': label,
        'p_game': game,
      })) as Map)['id'] as int;

  static Future<void> join(String token, int id) =>
      GbServer.rpc('gb_tn_join', {'p_token': token, 'p_id': id});

  static Future<void> leave(String token, int id) =>
      GbServer.rpc('gb_tn_leave', {'p_token': token, 'p_id': id});

  static Future<void> delete(String token, int id) =>
      GbServer.rpc('gb_tn_delete', {'p_token': token, 'p_id': id});

  static Future<Tournament> start(String token, int id) async =>
      Tournament.fromJson(_map(
          await GbServer.rpc('gb_tn_start', {'p_token': token, 'p_id': id})));

  /// Défi « En ligne » de mon match → id du défi.
  static Future<int> challenge(String token, int id, TnMatch m) async =>
      ((await GbServer.rpc('gb_tn_challenge', {
        'p_token': token,
        'p_id': id,
        'p_round': m.round,
        'p_slot': m.slot,
      })) as Map)['id'] as int;

  /// Vainqueur d'un match joué (envoyé par l'appli en fin de partie).
  static Future<void> report(
          String token, int id, int round, int slot, int winner) =>
      GbServer.rpc('gb_tn_report', {
        'p_token': token,
        'p_id': id,
        'p_round': round,
        'p_slot': slot,
        'p_winner': winner,
      });

  /// Vainqueur déclaré par le créateur (forfait).
  static Future<Tournament> setWinner(
          String token, int id, TnMatch m, int winner) async =>
      Tournament.fromJson(_map(await GbServer.rpc('gb_tn_set_winner', {
        'p_token': token,
        'p_id': id,
        'p_round': m.round,
        'p_slot': m.slot,
        'p_winner': winner,
      })));
}

/// Tournoi à la maison : tableau gardé sur ce téléphone, matchs joués sur la
/// cible ; même tirage et mêmes exempts que le serveur (`gb_tn_start`).
class LocalTournament {
  final String uid;
  final String name;
  final String label;
  final Map<String, dynamic> game; // partie modèle, sans joueurs
  final List<X01Player> players; // dans l'ordre du tirage
  final List<Map<String, dynamic>>
      matches; // {r, s, a, b, bye, winner, forfeit}
  int rounds;
  int? winner;
  final DateTime created;

  LocalTournament._(this.uid, this.name, this.label, this.game, this.players,
      this.matches, this.rounds, this.winner, this.created);

  /// Tirage au sort et tableau (exempts au 1er tour s'il manque des joueurs).
  factory LocalTournament.create(
      {required String name,
      required String label,
      required Map<String, dynamic> game,
      required List<X01Player> players,
      math.Random? random}) {
    final ps = [...players]..shuffle(random ?? math.Random());
    final t = LocalTournament._(
        '${DateTime.now().microsecondsSinceEpoch}',
        name,
        label,
        Map<String, dynamic>.from(game)
          ..remove('players')
          ..remove('actions'),
        ps,
        [],
        1,
        null,
        DateTime.now());
    t._start();
    return t;
  }

  void _start() {
    final n = players.length;
    var size = 2;
    rounds = 1;
    while (size < n) {
      size *= 2;
      rounds++;
    }
    final byes = size - n;
    for (var r = 1; r <= rounds; r++) {
      for (var s = 0; s < size >> r; s++) {
        matches.add({
          'r': r,
          's': s,
          'a': null,
          'b': null,
          'bye': false,
          'winner': null,
          'forfeit': false
        });
      }
    }
    var i = 1; // numéros des joueurs = 1..n (index + 1)
    for (var s = 0; s < size ~/ 2; s++) {
      final m = matches[s];
      final bye = (s.isEven && s ~/ 2 < byes) ||
          (s.isOdd && (s - 1) ~/ 2 < byes - size ~/ 4);
      m['a'] = i++;
      if (bye) {
        m['bye'] = true;
      } else {
        m['b'] = i++;
      }
    }
    for (final m in matches.where((m) => m['bye'] == true).toList()) {
      advance(1, m['s'] as int, m['a'] as int);
    }
  }

  Map<String, dynamic> _m(int r, int s) =>
      matches.firstWhere((m) => m['r'] == r && m['s'] == s);

  /// Vainqueur d'un match ([forfeit] = déclaré sans jouer).
  void advance(int r, int s, int winnerNo, {bool forfeit = false}) {
    final m = _m(r, s);
    if (m['winner'] != null) return;
    m['winner'] = winnerNo;
    m['forfeit'] = forfeit;
    if (r >= rounds) {
      winner = winnerNo;
      return;
    }
    _m(r + 1, s ~/ 2)[s.isEven ? 'a' : 'b'] = winnerNo;
  }

  X01Player playerNo(int no) => players[no - 1];

  /// Partie d'un match : la partie modèle avec les 2 joueurs (ordre au hasard).
  Map<String, dynamic> gameFor(TnMatch m, {math.Random? random}) {
    var a = playerNo(m.a!), b = playerNo(m.b!);
    if ((random ?? math.Random()).nextBool()) (a, b) = (b, a);
    return {
      ...game,
      'players': [
        X01Player(id: a.id, name: a.name, team: 0).toJson(),
        X01Player(id: b.id, name: b.name, team: 1).toJson(),
      ],
      'actions': const [],
    };
  }

  /// Vue commune avec les tournois en ligne.
  Tournament view() {
    final store = PlayerStore.instance;
    final colors = store.distinctColors([for (final p in players) p.id]);
    return Tournament(
      local: true,
      id: 0,
      name: name,
      size: players.length,
      label: label,
      status: winner != null ? 'done' : 'running',
      rounds: rounds,
      owner: 0,
      winner: winner,
      game: game,
      players: [
        for (var i = 0; i < players.length; i++)
          TnPlayer(
              id: i + 1,
              key: players[i].id,
              name: players[i].name,
              color: colors[i])
      ],
      matches: [for (final m in matches) TnMatch.fromJson(m)],
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'name': name,
        'label': label,
        'game': game,
        'players': [for (final p in players) p.toJson()],
        'matches': matches,
        'rounds': rounds,
        'winner': winner,
        'created': created.toIso8601String(),
      };

  factory LocalTournament.fromJson(Map<String, dynamic> j) => LocalTournament._(
        '${j['uid']}',
        '${j['name'] ?? ''}',
        '${j['label'] ?? ''}',
        Map<String, dynamic>.from(j['game'] as Map? ?? const {}),
        [
          for (final p in (j['players'] as List? ?? const []))
            X01Player.fromJson(Map<String, dynamic>.from(p as Map))
        ],
        [
          for (final m in (j['matches'] as List? ?? const []))
            Map<String, dynamic>.from(m as Map)
        ],
        (j['rounds'] as num?)?.toInt() ?? 1,
        (j['winner'] as num?)?.toInt(),
        DateTime.tryParse('${j['created']}') ?? DateTime.now(),
      );
}

/// Tournois à la maison gardés sur le téléphone (les 10 derniers).
class LocalTournamentStore extends ChangeNotifier {
  LocalTournamentStore._();
  static final instance = LocalTournamentStore._();
  static const _pref = 'local_tournaments_v1';

  final List<LocalTournament> list = [];
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final p = await SharedPreferences.getInstance();
      final raw = jsonDecode(p.getString(_pref) ?? '[]') as List;
      list
        ..clear()
        ..addAll([
          for (final j in raw)
            LocalTournament.fromJson(Map<String, dynamic>.from(j as Map))
        ]);
    } catch (_) {}
    notifyListeners();
  }

  /// Tests : repart de zéro.
  void debugReset() {
    list.clear();
    _loaded = false;
  }

  LocalTournament? byUid(String uid) {
    for (final t in list) {
      if (t.uid == uid) return t;
    }
    return null;
  }

  Future<void> add(LocalTournament t) async {
    list.insert(0, t);
    if (list.length > 10) list.removeRange(10, list.length);
    await save();
  }

  Future<void> remove(String uid) async {
    list.removeWhere((t) => t.uid == uid);
    await save();
  }

  Future<void> save() async {
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_pref, jsonEncode([for (final t in list) t.toJson()]));
    } catch (_) {}
  }
}
