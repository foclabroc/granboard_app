import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../server.dart';

/// Côté TV : ouvre un salon (code à afficher), écoute le relais temps réel
/// du serveur et relit l'état envoyé par le téléphone.
class TvClient extends ChangeNotifier {
  TvClient({this.realtime = true});

  /// Faux en test (pas de WebSocket).
  final bool realtime;

  static const _prefKey = 'tv_room_v1';

  String? code;
  String? _key;
  String? _topic;
  int _seq = 0;
  String? error;

  /// Dernier état reçu : {screen: lobby|game|results, host, game, colors}
  Map<String, dynamic>? state;

  /// Relais connecté (sinon on relit plus souvent).
  bool live = false;

  Timer? _poll;
  WebSocketChannel? _ws;
  Timer? _heartbeat;
  Timer? _reconnect;
  int _ref = 0;
  bool _fetching = false;
  bool _closed = false;

  Future<void> start() async {
    await _openRoom();
    _schedulePoll();
    if (realtime) _connect();
  }

  @override
  void dispose() {
    _closed = true;
    _poll?.cancel();
    _heartbeat?.cancel();
    _reconnect?.cancel();
    _ws?.sink.close();
    super.dispose();
  }

  /// Reprend le salon mémorisé (même code après un redémarrage), sinon en ouvre un.
  Future<void> _openRoom({bool fresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    if (!fresh) {
      try {
        final j = jsonDecode(prefs.getString(_prefKey) ?? '') as Map;
        code = j['code'] as String?;
        _key = j['key'] as String?;
        _topic = j['topic'] as String?;
      } catch (_) {}
    }
    if (code != null && !fresh) {
      if (await fetch()) return;
    }
    try {
      final r = Map<String, dynamic>.from(
          await GbServer.rpc('gb_tv_open', {}) as Map);
      code = r['code'] as String;
      _key = r['key'] as String;
      _topic = r['topic'] as String;
      _seq = 0;
      state = null;
      error = null;
      await prefs.setString(
          _prefKey, jsonEncode({'code': code, 'key': _key, 'topic': _topic}));
    } on ApiError catch (e) {
      error = e.message;
    }
    notifyListeners();
    if (realtime) _rejoin();
  }

  /// Simule un état reçu (tests, captures).
  @visibleForTesting
  void debugSetState(String roomCode, Map<String, dynamic>? s) {
    code = roomCode;
    state = s;
    notifyListeners();
  }

  /// Nouveau code (le téléphone relié est oublié).
  Future<void> newCode() => _openRoom(fresh: true);

  /// Relit l'état s'il a changé. Renvoie false si le salon n'existe plus.
  Future<bool> fetch() async {
    final c = code, k = _key;
    if (c == null || k == null || _fetching) return true;
    _fetching = true;
    try {
      final r = await GbServer.rpc(
          'gb_tv_get', {'p_code': c, 'p_key': k, 'p_since': _seq});
      final m = Map<String, dynamic>.from(r as Map);
      error = null;
      final seq = (m['seq'] as num?)?.toInt() ?? _seq;
      if (m['state'] is Map && seq > _seq) {
        _seq = seq;
        state = Map<String, dynamic>.from(m['state'] as Map);
        notifyListeners();
      }
      return true;
    } on ApiError catch (e) {
      if (e.code == 'tv_gone') {
        code = null;
        return false;
      }
      if (error != e.message) {
        error = e.message;
        notifyListeners();
      }
      return true;
    } finally {
      _fetching = false;
    }
  }

  void _schedulePoll() {
    _poll?.cancel();
    // Relecture de secours : rapide sans relais, lente avec
    _poll = Timer.periodic(const Duration(milliseconds: 1500), (t) {
      if (!live || t.tick % 8 == 0) fetch();
    });
  }

  // ─── Relais temps réel (protocole Phoenix, comme Pixel Trade) ───

  void _connect() {
    if (_closed) return;
    try {
      final url = kApiUrl.replaceFirst('https://', 'wss://');
      final ws = WebSocketChannel.connect(
          Uri.parse('$url/realtime/v1/websocket?apikey=$kApiKey&vsn=1.0.0'));
      _ws = ws;
      ws.stream.listen(_onMessage,
          onDone: _lost, onError: (_) => _lost(), cancelOnError: true);
      _rejoin();
      _heartbeat?.cancel();
      _heartbeat = Timer.periodic(const Duration(seconds: 25), (_) {
        _sendWs({'topic': 'phoenix', 'event': 'heartbeat', 'payload': {}});
      });
    } catch (_) {
      _lost();
    }
  }

  void _rejoin() {
    final t = _topic;
    if (t == null || _ws == null) return;
    _sendWs({'topic': 'realtime:$t', 'event': 'phx_join', 'payload': {}});
  }

  void _sendWs(Map<String, dynamic> m) {
    try {
      _ws?.sink.add(jsonEncode({...m, 'ref': '${++_ref}'}));
    } catch (_) {}
  }

  void _onMessage(dynamic raw) {
    Map<String, dynamic> m;
    try {
      m = Map<String, dynamic>.from(jsonDecode(raw as String) as Map);
    } catch (_) {
      return;
    }
    if (m['event'] == 'phx_reply' && m['topic'] == 'realtime:$_topic') {
      final ok = (m['payload'] as Map?)?['status'] == 'ok';
      if (ok != live) {
        live = ok;
        notifyListeners();
      }
      fetch();
    } else if (m['event'] == 'broadcast') {
      fetch();
    }
  }

  void _lost() {
    _heartbeat?.cancel();
    _ws = null;
    if (live) {
      live = false;
      notifyListeners();
    }
    if (_closed) return;
    _reconnect?.cancel();
    _reconnect = Timer(const Duration(seconds: 5), _connect);
  }
}
