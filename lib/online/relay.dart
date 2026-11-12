import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../server.dart';

/// Relais temps réel du serveur maison (protocole Phoenix, comme l'écran
/// TV) : prévient quand quelque chose a changé sur un canal. Une seule
/// connexion pour tous les canaux ; elle se ferme quand plus personne
/// n'écoute.
class Relay extends ChangeNotifier {
  Relay._();
  static final instance = Relay._();

  /// Faux en test (pas de WebSocket).
  static bool enabled = true;

  final _subs = <String, Set<VoidCallback>>{};
  final _joined = <String>{};
  WebSocketChannel? _ws;
  Timer? _heartbeat;
  Timer? _reconnect;
  int _ref = 0;

  /// Connecté et au moins un canal rejoint.
  bool get live => _joined.isNotEmpty;

  bool isLive(String topic) => _joined.contains(topic);

  /// Écoute [topic] ; renvoie la fonction qui arrête l'écoute.
  VoidCallback listen(String topic, VoidCallback onEvent) {
    final first = !_subs.containsKey(topic);
    _subs.putIfAbsent(topic, () => {}).add(onEvent);
    if (enabled) {
      if (_ws == null) {
        _connect();
      } else if (first) {
        _join(topic);
      }
    }
    return () {
      final s = _subs[topic];
      if (s == null) return;
      s.remove(onEvent);
      if (s.isEmpty) {
        _subs.remove(topic);
        _joined.remove(topic);
        _send(
            {'topic': 'realtime:$topic', 'event': 'phx_leave', 'payload': {}});
      }
      if (_subs.isEmpty) _close();
    };
  }

  void _connect() {
    _reconnect?.cancel();
    if (_subs.isEmpty || _ws != null) return;
    try {
      final url = kApiUrl.replaceFirst('https://', 'wss://');
      final ws = WebSocketChannel.connect(
          Uri.parse('$url/realtime/v1/websocket?apikey=$kApiKey&vsn=1.0.0'));
      _ws = ws;
      ws.stream.listen(_onMessage,
          onDone: () => _lost(ws),
          onError: (_) => _lost(ws),
          cancelOnError: true);
      for (final t in _subs.keys) {
        _join(t);
      }
      _heartbeat?.cancel();
      _heartbeat = Timer.periodic(const Duration(seconds: 25), (_) {
        _send({'topic': 'phoenix', 'event': 'heartbeat', 'payload': {}});
      });
    } catch (_) {
      _ws = null;
      _retryLater();
    }
  }

  void _join(String topic) =>
      _send({'topic': 'realtime:$topic', 'event': 'phx_join', 'payload': {}});

  void _send(Map<String, dynamic> m) {
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
    final t = '${m['topic'] ?? ''}';
    if (!t.startsWith('realtime:')) return;
    final topic = t.substring(9);
    final subs = _subs[topic];
    if (subs == null) return;
    if (m['event'] == 'phx_reply') {
      final ok = (m['payload'] as Map?)?['status'] == 'ok';
      if (ok ? _joined.add(topic) : _joined.remove(topic)) notifyListeners();
      if (!ok) return;
    } else if (m['event'] != 'broadcast') {
      return;
    }
    for (final cb in subs.toList()) {
      cb();
    }
  }

  void _lost(WebSocketChannel ws) {
    if (!identical(ws, _ws)) return;
    _heartbeat?.cancel();
    _ws = null;
    if (_joined.isNotEmpty) {
      _joined.clear();
      notifyListeners();
    }
    _retryLater();
  }

  void _retryLater() {
    if (_subs.isEmpty) return;
    _reconnect?.cancel();
    _reconnect = Timer(const Duration(seconds: 5), _connect);
  }

  void _close() {
    _heartbeat?.cancel();
    _reconnect?.cancel();
    final ws = _ws;
    _ws = null;
    _joined.clear();
    try {
      ws?.sink.close();
    } catch (_) {}
  }
}
