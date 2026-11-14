import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../lan.dart';
import '../server.dart';
import 'screen_cam.dart' show CamPort;

/// Côté TV : ouvre un salon (code à afficher), écoute le relais temps réel
/// du serveur et relit l'état envoyé par le téléphone.
class TvClient extends ChangeNotifier implements CamPort {
  TvClient(
      {this.realtime = true,
      this.deviceName = 'TV',
      this.prefKey = 'tv_room_v1'});

  /// Clé du salon mémorisé (différente en test pour simuler deux appareils).
  final String prefKey;

  /// « TV » sur une Android TV, « Tablette » sinon (affiché sur le téléphone).
  final String deviceName;

  /// Faux en test (pas de WebSocket).
  final bool realtime;

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

  /// Wi-Fi local : le téléphone envoie aussi l'état directement.
  LanServer? _lan;

  /// Code fait par l'écran lui-même (serveur injoignable au démarrage) :
  /// seul le Wi-Fi local marche.
  bool lanOnly = false;

  Future<void> start() async {
    await _openRoom();
    _schedulePoll();
    if (realtime) _connect();
    if (realtime && Lan.enabled) {
      _lan = LanServer(
          code: () => code,
          name: deviceName,
          onState: (st) => _applyState(st, lan: true));
      await _lan!.start();
    }
  }

  int _lastAt = 0;

  /// Appareil qui pilote, d'après le dernier état venu du serveur (seul
  /// l'appareil relié en dernier peut y écrire).
  String? _hostSrc;
  String? _lastSrc;

  /// Nouvel état (serveur ou Wi-Fi) : le plus récent gagne (`at` = heure
  /// d'envoi du téléphone). Le même envoi arrive souvent 2 fois (serveur
  /// ET Wi-Fi) : le 2e est ignoré (sinon la partie était reconstruite sans
  /// effets : ni bandeau, ni vidéo).
  ///
  /// Sur le Wi-Fi, n'importe quel appareil qui croit encore piloter cet
  /// écran peut envoyer (pas de clé) : on n'y écoute que l'appareil qui
  /// pilote d'après le serveur ([_hostSrc]), sauf si le serveur ne répond
  /// pas. Sans ça, la partie et l'écran d'attente d'un 2e appareil
  /// s'affichaient en alternance.
  void _applyState(Map<String, dynamic> s, {bool lan = false}) {
    final at = (s['at'] as num?)?.toInt() ?? 0;
    // Autre téléphone (ou téléphone redémarré) : son horloge peut retarder
    final src = s['src'] as String?;
    if (lan &&
        src != null &&
        _hostSrc != null &&
        src != _hostSrc &&
        !lanOnly &&
        error == null) {
      return;
    }
    if (!lan && src != null) _hostSrc = src;
    if (src != null && src != _lastSrc) {
      _lastSrc = src;
      _lastAt = 0;
    }
    if (at != 0 && at <= _lastAt) return;
    if (at != 0) _lastAt = at;
    state = s;
    notifyListeners();
  }

  @override
  void dispose() {
    _closed = true;
    _signals.close();
    _lan?.close();
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
        final j = jsonDecode(prefs.getString(prefKey) ?? '') as Map;
        code = j['code'] as String?;
        _key = j['key'] as String?;
        _topic = j['topic'] as String?;
      } catch (_) {}
    }
    if (code != null && !fresh) {
      lanOnly = prefs.getBool('${prefKey}_lan') ?? false;
      if (lanOnly || await fetch()) return;
    }
    try {
      final r = Map<String, dynamic>.from(
          await GbServer.rpc('gb_tv_open', {'p_name': deviceName}) as Map);
      code = r['code'] as String;
      _key = r['key'] as String;
      _topic = r['topic'] as String;
      _seq = 0;
      _lastAt = 0;
      state = null;
      error = null;
      lanOnly = false;
      await prefs.setString(
          prefKey, jsonEncode({'code': code, 'key': _key, 'topic': _topic}));
      await prefs.remove('${prefKey}_lan');
    } on ApiError catch (e) {
      error = e.message;
      // Pas d'internet : un code à soi, pour le Wi-Fi local seulement
      if (e.offline && Lan.enabled && (code == null || fresh)) {
        code = _localCode();
        _key = null;
        _topic = null;
        _seq = 0;
        _lastAt = 0;
        state = null;
        lanOnly = true;
        await prefs.setString(prefKey, jsonEncode({'code': code}));
        await prefs.setBool('${prefKey}_lan', true);
      }
    }
    notifyListeners();
    if (realtime) _rejoin();
  }

  static const _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  String _localCode() {
    final r = Random();
    return List.generate(4, (_) => _alphabet[r.nextInt(_alphabet.length)])
        .join();
  }

  /// Simule un état reçu (tests, captures).
  @visibleForTesting

  /// Tests : état reçu comme par le serveur ou le Wi-Fi.
  void debugApplyState(Map<String, dynamic> s, {bool lan = false}) =>
      _applyState(s, lan: lan);

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
        _applyState(Map<String, dynamic>.from(m['state'] as Map));
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
      if (signalsWanted && (!live || t.tick % 4 == 0)) fetchSignals();
    });
  }

  // ─── Messages entre écrans (caméra de la tablette sur la TV) ───

  final _signals = StreamController<Map<String, dynamic>>.broadcast();

  @override
  String? get camId => code;

  /// Messages reçus d'un autre écran : {from, …message}.
  @override
  Stream<Map<String, dynamic>> get signals => _signals.stream;

  /// Vrai pendant une liaison caméra : les messages sont relus.
  @override
  bool signalsWanted = false;

  /// Serveurs STUN/TURN (gb_config).
  @override
  List<dynamic> ice = const [];
  int _sigSince = 0;
  bool _sigFetching = false;

  @override
  Future<void> fetchSignals() async {
    final c = code, k = _key;
    if (c == null || k == null || _sigFetching) return;
    _sigFetching = true;
    try {
      final r = Map<String, dynamic>.from(await GbServer.rpc(
              'gb_tv_signals', {'p_code': c, 'p_key': k, 'p_since': _sigSince})
          as Map);
      if (r['ice'] is List) ice = r['ice'] as List;
      for (final e in (r['signals'] as List? ?? const [])) {
        final m = Map<String, dynamic>.from(e as Map);
        _sigSince = max(_sigSince, (m['id'] as num).toInt());
        _signals.add(
            {...Map<String, dynamic>.from(m['msg'] as Map), 'from': m['from']});
      }
    } catch (_) {
    } finally {
      _sigFetching = false;
    }
  }

  /// Envoie un message à l'écran [to] (relié au même téléphone), ou à
  /// l'appareil qui pilote ([to] = 'phone').
  @override
  Future<bool> signal(String to, Map<String, dynamic> msg) async {
    final c = code, k = _key;
    if (c == null || k == null) return false;
    try {
      await GbServer.rpc(
          'gb_tv_signal', {'p_code': c, 'p_key': k, 'p_to': to, 'p_msg': msg});
      return true;
    } catch (_) {
      return false;
    }
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
      final sig = jsonEncode(m['payload']).contains('"sig"');
      if (sig) {
        if (signalsWanted) fetchSignals();
      } else {
        fetch();
      }
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
