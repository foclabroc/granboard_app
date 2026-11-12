import 'online/online.dart';
import 'server.dart';

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
  final List<OnlinePlayer> players;
  final List<TnMatch> matches;

  const Tournament({
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
            if (p is Map) OnlinePlayer.fromJson(p)
        ],
        matches: [
          for (final m in (j['matches'] as List? ?? const []))
            TnMatch.fromJson(Map<String, dynamic>.from(m as Map))
        ],
      );

  OnlinePlayer? player(int? id) {
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
