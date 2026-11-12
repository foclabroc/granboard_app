import 'dart:convert';

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
  final media = <int, Map<String, dynamic>>{}; // id → {v, photo, sound, voice}

  // Jeu en ligne
  final online = <int, bool>{}; // id → occupé
  final invites = <int, Map<String, dynamic>>{};
  final rooms = <int, Map<String, dynamic>>{};

  /// Copie comme après un passage par le réseau.
  dynamic _json(dynamic v) => jsonDecode(jsonEncode(v));

  Map<String, dynamic> _onPlayer(int id) => {
        'id': id,
        'pseudo': accounts[id]!['pseudo'],
        'color': accounts[id]!['color'],
        'rating': null,
      };

  int _auth(dynamic token) {
    final id = sessions[token];
    if (id == null) throw const ApiError('session');
    return id;
  }

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
      case 'gb_set_photo':
        final id = _auth(b['p_token']);
        final photo = b['p_photo'] as String?;
        if (photo != null && !photo.startsWith('/9j/')) {
          throw const ApiError('photo');
        }
        final m = media[id] ??= {'v': 0, 'sound': ''};
        m['photo'] = photo;
        return m['v'] = (m['v'] as int) + 1;
      case 'gb_set_sound':
        final id = _auth(b['p_token']);
        final m = media[id] ??= {'v': 0, 'sound': ''};
        m['sound'] = b['p_sound'];
        if (b['p_voice'] != null) m['voice'] = b['p_voice'];
        return m['v'] = (m['v'] as int) + 1;
      case 'gb_media':
        final known = Map<String, dynamic>.from(b['p_known'] as Map);
        return {
          for (final id in (b['p_ids'] as List).cast<int>())
            if (accounts.containsKey(id))
              '$id': (media[id]?['v'] ?? 0) == known['$id']
                  ? {'v': media[id]?['v'] ?? 0}
                  : {
                      'v': media[id]?['v'] ?? 0,
                      'photo': media[id]?['photo'],
                      'sound': media[id]?['sound'] ?? '',
                      'voice': media[id]?['sound'] == 'voice'
                          ? media[id]!['voice']
                          : null,
                    }
        };
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
      case 'gb_on_ping':
        final me = _auth(b['p_token']);
        online[me] = b['p_busy'] == true;
        final inv = invites.values
            .where((i) => i['to'] == me && i['status'] == 'pending')
            .lastOrNull;
        final snt = invites.values.where((i) => i['from'] == me).lastOrNull;
        final room = rooms.entries
            .where((r) =>
                (r.value['a'] == me || r.value['b'] == me) &&
                r.value['left'] == null)
            .lastOrNull;
        return _json({
          'me': me,
          'topic': 'rc_u$me',
          'online': [
            for (final e in online.entries)
              if (e.key != me) {..._onPlayer(e.key), 'busy': e.value}
          ],
          'invite': inv == null
              ? null
              : {
                  'id': inv['id'],
                  'from': _onPlayer(inv['from'] as int),
                  'game': inv['game']
                },
          'sent': snt == null
              ? null
              : {
                  'id': snt['id'],
                  'to': snt['to'],
                  'status': snt['status'],
                  'room': snt['room']
                },
          'room': room?.key,
        });
      case 'gb_on_bye':
        online.remove(_auth(b['p_token']));
        return null;
      case 'gb_on_invite':
        final me = _auth(b['p_token']);
        final to = b['p_to'] as int;
        if (!online.containsKey(to)) return {'error': 'on_offline'};
        if (online[to] == true) return {'error': 'on_busy'};
        final id = invites.length + 1;
        invites[id] = {
          'id': id,
          'from': me,
          'to': to,
          'game': _json(b['p_game']),
          'status': 'pending',
          'room': null
        };
        return {'id': id};
      case 'gb_on_cancel':
        final me = _auth(b['p_token']);
        final i = invites[b['p_invite']];
        if (i != null && i['from'] == me && i['status'] == 'pending') {
          i['status'] = 'cancelled';
        }
        return null;
      case 'gb_on_answer':
        final me = _auth(b['p_token']);
        final i = invites[b['p_invite']];
        if (i == null || i['to'] != me || i['status'] != 'pending') {
          return {'error': 'on_gone'};
        }
        if (b['p_accept'] != true) {
          i['status'] = 'declined';
          return <String, dynamic>{};
        }
        final id = rooms.length + 1;
        rooms[id] = {
          'a': i['from'],
          'b': me,
          'game': i['game'],
          'seq': 1,
          'left': null,
          'signals': <Map<String, dynamic>>[],
          'age': 0,
        };
        i['status'] = 'accepted';
        i['room'] = id;
        online[i['from'] as int] = true;
        online[me] = true;
        return {'room': id};
      case 'gb_on_get':
        final me = _auth(b['p_token']);
        final r = rooms[b['p_room']];
        if (r == null || (r['a'] != me && r['b'] != me)) {
          return {'error': 'on_room'};
        }
        final a = r['a'] == me;
        return _json({
          'seq': r['seq'],
          'side': a ? 'a' : 'b',
          'peer': _onPlayer((a ? r['b'] : r['a']) as int),
          'peer_age': r['age'],
          'left': r['left'] != null,
          'topic': 'rc_r${b['p_room']}',
          'ice': [],
          'signals': [
            for (final s in (r['signals'] as List))
              if (s['from'] != me && (s['id'] as int) > (b['p_sig'] as int))
                {'id': s['id'], 'data': s['data']}
          ],
          if ((r['seq'] as int) > (b['p_since'] as int)) 'game': r['game'],
        });
      case 'gb_on_push':
        final me = _auth(b['p_token']);
        final r = rooms[b['p_room']];
        if (r == null || (r['a'] != me && r['b'] != me) || r['left'] != null) {
          return {'error': 'on_room'};
        }
        final g = Map<String, dynamic>.from(_json(b['p_game']) as Map);
        final old = Map<String, dynamic>.from(r['game'] as Map);
        if (jsonEncode({...g, 'actions': null}) !=
            jsonEncode({...old, 'actions': null})) {
          throw const ApiError('on_game');
        }
        if (r['seq'] != b['p_seq']) return {'error': 'on_conflict'};
        r['game'] = g;
        r['seq'] = (r['seq'] as int) + 1;
        return {'seq': r['seq']};
      case 'gb_on_signal':
        final me = _auth(b['p_token']);
        final r = rooms[b['p_room']]!;
        final sigs = r['signals'] as List;
        sigs.add(
            {'id': sigs.length + 1, 'from': me, 'data': _json(b['p_data'])});
        return sigs.length;
      case 'gb_on_leave':
        final me = _auth(b['p_token']);
        final r = rooms[b['p_room']];
        if (r != null) r['left'] ??= me;
        online[me] = false;
        return null;
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
