// Liaison téléphone → écran par le Wi-Fi de la maison, sans internet.
//
// L'écran (TV, tablette) ouvre un petit serveur HTTP et répond aux appels
// UDP en diffusion : le téléphone crie « FOCLA?<code> » sur le réseau,
// l'écran qui affiche ce code répond « FOCLA!<code>|<port>|<nom> ». Ensuite
// le téléphone envoie l'état par HTTP (POST /push), en plus du serveur
// maison quand internet marche.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const kLanHttpPort = 47811;
const kLanUdpPort = 47812;

/// Écran trouvé sur le réseau local.
class LanFound {
  final String address; // ip:port
  final String code;
  final String name;
  const LanFound(this.address, this.code, this.name);
}

class Lan {
  Lan._();

  /// Faux en test (pas de sockets), sauf dans les tests du Wi-Fi local.
  static bool enabled = true;

  /// Cherche l'écran qui affiche [code] (null si personne ne répond).
  static Future<LanFound?> discover(String code,
      {List<InternetAddress>? targets,
      int udpPort = kLanUdpPort,
      Duration timeout = const Duration(milliseconds: 1800)}) async {
    if (!enabled) return null;
    final want = code.trim().toUpperCase();
    RawDatagramSocket? sock;
    final done = Completer<LanFound?>();
    try {
      sock = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      sock.broadcastEnabled = true;
      sock.listen((e) {
        if (e != RawSocketEvent.read) return;
        final dg = sock!.receive();
        if (dg == null) return;
        final msg = utf8.decode(dg.data, allowMalformed: true);
        if (!msg.startsWith('FOCLA!')) return;
        final p = msg.substring(6).split('|');
        if (p.length < 3 || p[0].toUpperCase() != want) return;
        if (!done.isCompleted) {
          done.complete(LanFound(
              '${dg.address.address}:${p[1]}', p[0].toUpperCase(), p[2]));
        }
      });
      final to = targets ?? await _broadcasts();
      final ask = utf8.encode('FOCLA?$want');
      for (var i = 0; i < 3 && !done.isCompleted; i++) {
        for (final a in to) {
          try {
            sock.send(ask, a, udpPort);
          } catch (_) {}
        }
        await Future.any([
          done.future,
          Future<void>.delayed(
              Duration(milliseconds: timeout.inMilliseconds ~/ 3)),
        ]);
      }
      return done.isCompleted ? await done.future : null;
    } catch (_) {
      return null;
    } finally {
      sock?.close();
    }
  }

  /// Adresses de diffusion : générale + celle de chaque réseau (en /24).
  static Future<List<InternetAddress>> _broadcasts() async {
    final out = <InternetAddress>[InternetAddress('255.255.255.255')];
    try {
      for (final i in await NetworkInterface.list(
          type: InternetAddressType.IPv4, includeLoopback: false)) {
        for (final a in i.addresses) {
          final b = a.rawAddress;
          if (b.length != 4) continue;
          out.add(InternetAddress('${b[0]}.${b[1]}.${b[2]}.255'));
        }
      }
    } catch (_) {}
    return out;
  }

  static final _http = http.Client();

  /// Envoie l'état à l'écran ; false s'il ne répond pas.
  static Future<bool> push(
      String address, String code, Map<String, dynamic> state) async {
    if (!enabled) return false;
    try {
      final r = await _http
          .post(Uri.parse('http://$address/push'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'code': code, 'state': state}))
          .timeout(const Duration(seconds: 3));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

/// Côté écran : serveur HTTP + réponse aux appels UDP.
class LanServer {
  /// Code affiché en ce moment (peut changer : « Nouveau code »).
  final String? Function() code;
  final String name;
  final void Function(Map<String, dynamic> state) onState;
  LanServer({required this.code, required this.name, required this.onState});

  HttpServer? _http;
  RawDatagramSocket? _udp;
  int port = 0;

  Future<void> start(
      {int httpPort = kLanHttpPort, int udpPort = kLanUdpPort}) async {
    if (!Lan.enabled) return;
    try {
      try {
        _http = await HttpServer.bind(InternetAddress.anyIPv4, httpPort,
            shared: true);
      } catch (_) {
        _http = await HttpServer.bind(InternetAddress.anyIPv4, 0);
      }
      port = _http!.port;
      _http!.listen(_onRequest, onError: (_) {});
    } catch (_) {
      return;
    }
    try {
      final u = await RawDatagramSocket.bind(InternetAddress.anyIPv4, udpPort,
          reuseAddress: true);
      u.broadcastEnabled = true;
      _udp = u;
      u.listen((e) {
        if (e != RawSocketEvent.read) return;
        final dg = u.receive();
        if (dg == null) return;
        final msg = utf8.decode(dg.data, allowMalformed: true);
        final c = code();
        if (c == null || !msg.startsWith('FOCLA?')) return;
        if (msg.substring(6).trim().toUpperCase() != c.toUpperCase()) return;
        try {
          u.send(utf8.encode('FOCLA!${c.toUpperCase()}|$port|$name'),
              dg.address, dg.port);
        } catch (_) {}
      });
    } catch (_) {}
  }

  Future<void> _onRequest(HttpRequest req) async {
    try {
      if (req.method == 'POST' && req.uri.path == '/push') {
        final body = await utf8.decoder.bind(req).join();
        final j = jsonDecode(body) as Map;
        final c = code();
        if (c != null &&
            '${j['code']}'.toUpperCase() == c.toUpperCase() &&
            j['state'] is Map) {
          onState(Map<String, dynamic>.from(j['state'] as Map));
          req.response.statusCode = 200;
        } else {
          req.response.statusCode = 403; // autre code : écran changé
        }
      } else {
        req.response.statusCode = 404;
      }
    } catch (_) {
      req.response.statusCode = 400;
    }
    await req.response.close();
  }

  Future<void> close() async {
    _udp?.close();
    await _http?.close(force: true);
  }
}
