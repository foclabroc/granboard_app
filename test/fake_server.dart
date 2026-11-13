import 'dart:convert';

import 'package:granboard_proto/server.dart';

/// Faux serveur en mémoire qui imite les fonctions SQL gb_* (tests).
class FakeServer {
  final accounts = <int, Map<String, dynamic>>{}; // id → {pseudo, pin, color}
  final sessions = <String, int>{}; // jeton → id
  final games = <String, Map<String, dynamic>>{}; // cid → partie
  final statsOf = <int, Map<String, dynamic>>{}; // réponses de gb_stats
  final recentOf = <int, List<Map<String, dynamic>>>{}; // gb_profile.recent
  final tournaments = <int, Map<String, dynamic>>{}; // id → tournoi (comme gb__tn_json)

  Map<String, dynamic> _tnJson(int id) {
    final t = tournaments[id]!;
    return {
      ...t,
      'players': [for (final p in t['ids'] as List<int>) _onPlayer(p)],
    }..remove('ids');
  }

  void _tnAdvance(Map<String, dynamic> t, int r, int sl, int w) {
    final ms = (t['matches'] as List).cast<Map<String, dynamic>>();
    ms.firstWhere((m) => m['r'] == r && m['s'] == sl)['winner'] = w;
    if (r >= (t['rounds'] as int)) {
      t['status'] = 'done';
      t['winner'] = w;
      return;
    }
    final next = ms.firstWhere((m) => m['r'] == r + 1 && m['s'] == sl ~/ 2);
    next[sl.isEven ? 'a' : 'b'] = w;
  }
  bool offline = false;
  final tvSignals = <Map<String, dynamic>>[];
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
      case 'gb_set_board':
        final id = _auth(b['p_token']);
        final m = media[id] ??= {'v': 0, 'sound': ''};
        m['board'] = b['p_board'] ?? '';
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
                      'board': media[id]?['board'] ?? '',
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
          'recent': recentOf[id] ?? [],
        };
      case 'gb_stats':
        final id = b['p_id'] as int;
        return statsOf[id] ??
            {
              'id': id,
              'pseudo': accounts[id]?['pseudo'] ?? '?',
              'color': accounts[id]?['color'] ?? 0,
              'g80': {
                'ppr': null,
                'mpr': null,
                'r01': null,
                'rcr': null,
                'rating': null
              },
              'g100': {
                'ppr': null,
                'mpr': null,
                'r01': null,
                'rcr': null,
                'rating': null
              },
              's01': [],
              'scr': [],
              'practice': {},
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
      case 'gb_tv_signal':
        final me = tvRooms[b['p_code']];
        final to = tvRooms[b['p_to']];
        if (me == null || me['key'] != b['p_key']) {
          throw const ApiError('tv_gone');
        }
        if (b['p_to'] == 'phone') {
          final c = (me['state'] as Map?)?['cam'];
          if (c is! Map || c['from'] != 'phone' || c['to'] != b['p_code']) {
            throw const ApiError('tv_peer');
          }
          tvSignals.add({
            'id': tvSignals.length + 1,
            'to': 'h:${b['p_code']}',
            'from': b['p_code'],
            'msg': b['p_msg'],
          });
          return tvSignals.length;
        }
        bool asked(Map? st) {
          final c = st?['cam'];
          return c is Map &&
              {c['from'], c['to']}.containsAll({b['p_code'], b['p_to']});
        }
        if (to == null ||
            !asked(me['state'] as Map?) ||
            !asked(to['state'] as Map?)) {
          throw const ApiError('tv_peer');
        }
        tvSignals.add({
          'id': tvSignals.length + 1,
          'to': b['p_to'],
          'from': b['p_code'],
          'msg': b['p_msg'],
        });
        return tvSignals.length;
      case 'gb_tv_host_signal':
        final r = tvRooms[b['p_code']];
        if (r == null || r['host'] != b['p_host_key']) {
          throw const ApiError('tv_host');
        }
        tvSignals.add({
          'id': tvSignals.length + 1,
          'to': b['p_code'],
          'from': 'phone',
          'msg': b['p_msg'],
        });
        return tvSignals.length;
      case 'gb_tv_host_signals':
        final r = tvRooms[b['p_code']];
        if (r == null || r['host'] != b['p_host_key']) {
          return {'error': 'tv_host'};
        }
        return {
          'ice': const [],
          'signals': [
            for (final m in tvSignals)
              if (m['to'] == 'h:${b['p_code']}' &&
                  (m['id'] as int) > (b['p_since'] as int))
                {'id': m['id'], 'from': m['from'], 'msg': m['msg']}
          ],
        };
      case 'gb_tv_signals':
        final r = tvRooms[b['p_code']];
        if (r == null || r['key'] != b['p_key']) return {'error': 'tv_gone'};
        final mine = tvSignals.where((m) => m['to'] == b['p_code']);
        return {
          'last': mine.isEmpty ? 0 : mine.last['id'],
          'ice': const [],
          'signals': [
            for (final m in mine)
              if ((m['id'] as int) > (b['p_since'] as int))
                {'id': m['id'], 'from': m['from'], 'msg': m['msg']}
          ],
        };
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
      case 'gb_tn_create':
        final me = _auth(b['p_token']);
        if ('${b['p_name']}'.trim().isEmpty) throw const ApiError('tn_name');
        final id = tournaments.length + 1;
        tournaments[id] = {
          'id': id,
          'name': b['p_name'],
          'size': b['p_size'],
          'label': b['p_label'],
          'game': Map<String, dynamic>.from(_json(b['p_game']))
            ..remove('players')
            ..remove('actions'),
          'status': 'open',
          'rounds': null,
          'owner': me,
          'winner': null,
          'ids': <int>[me],
          'matches': <Map<String, dynamic>>[],
        };
        return {'id': id};
      case 'gb_tn_list':
        final me = _auth(b['p_token']);
        return [
          for (final t in tournaments.values)
            {
              'id': t['id'],
              'name': t['name'],
              'size': t['size'],
              'label': t['label'],
              'status': t['status'],
              'owner': _onPlayer(t['owner'] as int),
              'winner': t['winner'] == null ? null : _onPlayer(t['winner'] as int),
              'count': (t['ids'] as List).length,
              'joined': (t['ids'] as List).contains(me),
            }
        ];
      case 'gb_tn_get':
        final id = b['p_id'] as int;
        if (!tournaments.containsKey(id)) return {'error': 'tn_gone'};
        return _tnJson(id);
      case 'gb_tn_join':
        final me = _auth(b['p_token']);
        final t = tournaments[b['p_id']];
        if (t == null) return {'error': 'tn_gone'};
        if (t['status'] != 'open') return {'error': 'tn_started'};
        final ids = t['ids'] as List<int>;
        if (!ids.contains(me)) {
          if (ids.length >= (t['size'] as int)) return {'error': 'tn_full'};
          ids.add(me);
        }
        return {'ok': true};
      case 'gb_tn_leave':
        final me = _auth(b['p_token']);
        final t = tournaments[b['p_id']];
        if (t != null && t['status'] == 'open' && t['owner'] != me) {
          (t['ids'] as List<int>).remove(me);
        }
        return null;
      case 'gb_tn_delete':
        final me = _auth(b['p_token']);
        if (tournaments[b['p_id']]?['owner'] == me) tournaments.remove(b['p_id']);
        return null;
      case 'gb_tn_start':
        final me = _auth(b['p_token']);
        final t = tournaments[b['p_id']];
        if (t == null || t['owner'] != me) return {'error': 'tn_gone'};
        final ids = List<int>.from(t['ids'] as List<int>); // sans tirage : ordre d'inscription
        if (ids.length < 2) return {'error': 'tn_few'};
        var size = 2, rounds = 1;
        while (size < ids.length) {
          size *= 2;
          rounds++;
        }
        final byes = size - ids.length;
        final ms = <Map<String, dynamic>>[];
        for (var r = 1; r <= rounds; r++) {
          for (var sl = 0; sl < size >> r; sl++) {
            ms.add({'r': r, 's': sl, 'a': null, 'b': null, 'bye': false, 'winner': null, 'forfeit': false});
          }
        }
        var i = 0;
        for (var sl = 0; sl < size ~/ 2; sl++) {
          final m = ms[sl];
          final isBye = (sl.isEven && sl ~/ 2 < byes) ||
              (sl.isOdd && (sl - 1) ~/ 2 < byes - size ~/ 4);
          m['a'] = ids[i++];
          if (isBye) {
            m['bye'] = true;
          } else {
            m['b'] = ids[i++];
          }
        }
        t['matches'] = ms;
        t['rounds'] = rounds;
        t['status'] = 'running';
        for (final m in ms.where((m) => m['bye'] == true).toList()) {
          _tnAdvance(t, 1, m['s'] as int, m['a'] as int);
        }
        return _tnJson(t['id'] as int);
      case 'gb_tn_challenge':
        final me = _auth(b['p_token']);
        final t = tournaments[b['p_id']];
        final m = (t?['matches'] as List?)?.cast<Map<String, dynamic>>().where(
            (m) => m['r'] == b['p_round'] && m['s'] == b['p_slot']).firstOrNull;
        if (t == null || m == null || m['winner'] != null || (m['a'] != me && m['b'] != me)) {
          return {'error': 'tn_match'};
        }
        final opp = (m['a'] == me ? m['b'] : m['a']) as int;
        if (!online.containsKey(opp)) return {'error': 'on_offline'};
        final id = invites.length + 1;
        invites[id] = {
          'id': id,
          'from': me,
          'to': opp,
          'game': {
            ...(t['game'] as Map<String, dynamic>),
            'players': [
              {'id': '$me', 'name': accounts[me]!['pseudo'], 'team': 0},
              {'id': '$opp', 'name': accounts[opp]!['pseudo'], 'team': 1},
            ],
            'actions': [],
            'tn': {'t': t['id'], 'r': m['r'], 's': m['s'], 'name': t['name'], 'rounds': t['rounds']},
          },
          'status': 'pending',
          'room': null
        };
        return {'id': id};
      case 'gb_tn_report':
      case 'gb_tn_set_winner':
        final me = _auth(b['p_token']);
        final t = tournaments[b['p_id']];
        final m = (t?['matches'] as List?)?.cast<Map<String, dynamic>>().where(
            (m) => m['r'] == b['p_round'] && m['s'] == b['p_slot']).firstOrNull;
        final w = b['p_winner'] as int;
        final allowed = fn == 'gb_tn_report'
            ? (m?['a'] == me || m?['b'] == me)
            : t?['owner'] == me;
        if (t == null || m == null || !allowed || (m['a'] != w && m['b'] != w)) {
          return {'error': fn == 'gb_tn_report' ? 'tn_match' : 'tn_owner'};
        }
        if (m['winner'] == null) {
          if (fn == 'gb_tn_set_winner') m['forfeit'] = true;
          _tnAdvance(t, m['r'] as int, m['s'] as int, w);
        }
        return _tnJson(t['id'] as int);
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
        var game = i['game'];
        if ((game as Map)['double'] == true) {
          // Double : la partie complétée par celui qui accepte (4 joueurs)
          final g = b['p_game'];
          if (g is! Map || (g['players'] as List).length != 4) {
            throw const ApiError('on_game');
          }
          game = _json(g);
        }
        final id = rooms.length + 1;
        rooms[id] = {
          'a': i['from'],
          'b': me,
          'game': game,
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
