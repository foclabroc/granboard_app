import 'package:granboard_proto/server.dart';

/// Faux serveur en mémoire qui imite les fonctions SQL gb_* (tests).
class FakeServer {
  final accounts = <int, Map<String, dynamic>>{}; // id → {pseudo, pin, color}
  final sessions = <String, int>{}; // jeton → id
  final games = <String, Map<String, dynamic>>{}; // cid → partie
  bool offline = false;
  final tvRooms =
      <String, Map<String, dynamic>>{}; // code → {key, host, state, seq}
  int _next = 1;

  void install() => GbServer.debugRpc = call;

  Future<dynamic> call(String fn, Map<String, dynamic> b) async {
    if (offline) throw const ApiError('offline', offline: true);
    switch (fn) {
      case 'gb_register':
        final pseudo = (b['p_pseudo'] as String).trim();
        if (accounts.values.any((a) =>
            (a['pseudo'] as String).toLowerCase() == pseudo.toLowerCase())) {
          throw const ApiError('taken');
        }
        final id = _next++;
        accounts[id] = {
          'pseudo': pseudo,
          'pin': b['p_pin'],
          'color': b['p_color']
        };
        return _session(id);
      case 'gb_login':
        final e = accounts.entries.where((e) =>
            (e.value['pseudo'] as String).toLowerCase() ==
            (b['p_pseudo'] as String).toLowerCase());
        if (e.isEmpty) return {'error': 'unknown'};
        if (e.first.value['pin'] != b['p_pin']) {
          return {'error': 'pin', 'left': 4};
        }
        return _session(e.first.key);
      case 'gb_check':
        return [
          for (final t in (b['p_tokens'] as List))
            if (sessions.containsKey(t)) _account(sessions[t]!, t as String)
        ];
      case 'gb_logout':
        sessions.remove(b['p_token']);
        return null;
      case 'gb_set_color':
        return null;
      case 'gb_submit':
        final g = Map<String, dynamic>.from(b['p_game'] as Map);
        for (final p in (g['players'] as List)) {
          if (!sessions.containsKey((p as Map)['token'])) {
            throw const ApiError('session');
          }
        }
        games[g['cid'] as String] = g;
        return games.length;
      case 'gb_profile':
        final id = b['p_id'] as int;
        return {
          'id': id,
          'pseudo': accounts[id]!['pseudo'],
          'color': accounts[id]!['color'],
          'stats': {'games': 0, 'wins': 0, 'avg': 0, 'rating': null},
          'rank': null,
          'recent': [],
        };
      case 'gb_tv_open':
        final code = 'AB${tvRooms.length + 10}'.substring(0, 4);
        tvRooms[code] = {
          'key': 'k$code',
          'host': null,
          'state': null,
          'seq': 0,
          'name': b['p_name'] ?? 'Écran',
        };
        return {
          'code': code,
          'key': 'k$code',
          'topic': 'rc_000000000000000000000000'
        };
      case 'gb_tv_link':
        final r = tvRooms[(b['p_code'] as String).toUpperCase()];
        if (r == null) return {'error': 'tv_code'};
        r['host'] = 'h${r['seq']}';
        r['seq'] = (r['seq'] as int) + 1;
        r['state'] = {'screen': 'lobby', 'host': b['p_name']};
        return {
          'code': (b['p_code'] as String).toUpperCase(),
          'host_key': r['host'],
          'name': r['name'],
        };
      case 'gb_tv_push':
        final r = tvRooms[b['p_code']];
        if (r == null || r['host'] != b['p_host_key']) {
          throw const ApiError('tv_host');
        }
        r['seq'] = (r['seq'] as int) + 1;
        r['state'] = b['p_state'];
        return r['seq'];
      case 'gb_tv_get':
        final r = tvRooms[b['p_code']];
        if (r == null || r['key'] != b['p_key']) return {'error': 'tv_gone'};
        if ((r['seq'] as int) <= (b['p_since'] as int)) {
          return {'seq': r['seq']};
        }
        return {'seq': r['seq'], 'state': r['state']};
      case 'gb_top':
        return [
          for (final e in accounts.entries)
            {
              'id': e.key,
              'pseudo': e.value['pseudo'],
              'color': e.value['color'],
              'games': 3,
              'value': 40.0 + e.key
            }
        ];
    }
    throw ApiError('fn $fn');
  }

  Map<String, dynamic> _session(int id) {
    final t = 'tok-$id-${sessions.length}';
    sessions[t] = id;
    return _account(id, t);
  }

  Map<String, dynamic> _account(int id, String token) => {
        'id': id,
        'pseudo': accounts[id]!['pseudo'],
        'color': accounts[id]!['color'],
        'token': token,
      };
}
