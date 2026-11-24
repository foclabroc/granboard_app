// Cibles VDarts (H2, H2L, H3, H3L, H4, H4L, MINI) en Bluetooth LE.
//
// Protocole relevé dans l'appli DartMate 0.8.44 (com.dartmate.game,
// paquet com.dartmate.board : VdartsGatt, VdartsProtocolParser,
// VdartsH4ProtocolParser, VdartsMatrixResolver, VdartsH2Session,
// VdartsHeartbeatHandshake, VdartsH4LedController). Jamais essayé sur une
// vraie cible VDarts depuis Foclaboard.
//
// La cible envoie la position du contact touché dans sa matrice
// (ligne 0-11, colonne 0-6), sous 2 formes :
// - texte (anciens H3) : « MAT <ligne> <colonne> <valeur> » + fin de ligne,
//   « BTN <n> <valeur> » pour le bouton ;
// - binaire (H2, H3L, H4) : 2 octets = une lettre (ligne, A-L) et un
//   chiffre (colonne, 1-8) brouillés par un OU exclusif avec 0xD2 ou 0xC9
//   (les 2 clés existent) ; « M » = bouton, « N » = capteur de la bordure
//   (fléchette hors cible).
// Selon le modèle, la cible attend une ouverture avant d'envoyer les
// fléchettes : voir [VdartsLink].

import 'dart:async';

import 'granboard.dart';

/// Famille de contrôleur, d'après le nom Bluetooth.
enum VdartsFamily {
  /// H2 / H2L : négociation « RS, OK, VD, clé, 6 réglages ».
  h2,

  /// H3 / H3L / MINI : rien à envoyer (H3L : ouverture si la cible ne fait
  /// qu'envoyer « AT »).
  h3,

  /// H4 / H4L : séquence d'initialisation officielle après l'abonnement.
  h4,

  /// Nom VDarts inconnu : on écoute sans rien envoyer.
  unknown,
}

/// Services et caractéristiques Bluetooth des cibles VDarts.
class VdartsGattProfile {
  final String service;
  final String notify;
  final String write;
  const VdartsGattProfile(this.service, this.notify, this.write);
}

class Vdarts {
  /// 3 profils vus selon les modèles (A, B, puis UART Nordic).
  static const profiles = [
    VdartsGattProfile(
      '000018f0-0000-1000-8000-00805f9b34fb',
      '00002af0-0000-1000-8000-00805f9b34fb',
      '00002af1-0000-1000-8000-00805f9b34fb',
    ),
    VdartsGattProfile(
      '0000ffe0-0000-1000-8000-00805f9b34fb',
      '0000ffe1-0000-1000-8000-00805f9b34fb',
      '0000ffe1-0000-1000-8000-00805f9b34fb',
    ),
    VdartsGattProfile(
      '6e400001-b5a3-f393-e0a9-e50e24dcca9e',
      '6e400003-b5a3-f393-e0a9-e50e24dcca9e',
      '6e400002-b5a3-f393-e0a9-e50e24dcca9e',
    ),
  ];

  static const _models = [
    ('mini+', 'VDarts MINI+'),
    ('mini', 'VDarts MINI'),
    ('h2l', 'VDarts H2L'),
    ('h3l', 'VDarts H3L'),
    ('h3n', 'VDarts H3L'),
    ('h4l', 'VDarts H4L'),
    ('h2', 'VDarts H2'),
    ('h3', 'VDarts H3'),
    ('h4', 'VDarts H4'),
  ];

  /// Minuscules, lettres, chiffres et « + » seulement.
  static String? _norm(String? name, {bool plus = true}) {
    if (name == null) return null;
    final b = StringBuffer();
    for (final c in name.toLowerCase().runes) {
      final ch = String.fromCharCode(c);
      if (RegExp(r'[a-z0-9]').hasMatch(ch) || (plus && ch == '+')) {
        b.write(ch);
      }
    }
    return b.toString();
  }

  /// Le nom Bluetooth est celui d'une cible VDarts.
  static bool isVdarts(String? name) =>
      _norm(name)?.contains('vdarts') ?? false;

  /// Partie du nom après « vdarts » (et « ble »).
  static String? _rest(String? name) {
    final n = _norm(name);
    if (n == null || !n.contains('vdarts')) return null;
    final after = n.substring(n.indexOf('vdarts') + 6);
    return after.startsWith('ble') ? after.substring(3) : after;
  }

  /// « VDarts H4L », « VDarts » si le modèle est inconnu, null si ce
  /// n'est pas une VDarts.
  static String? model(String? name) {
    final rest = _rest(name);
    if (rest == null) return null;
    for (final (prefix, label) in _models) {
      if (rest.startsWith(prefix)) return label;
    }
    return 'VDarts';
  }

  static VdartsFamily family(String? name) {
    final n = _norm(name);
    final rest = _rest(name);
    if (n == null || rest == null) return VdartsFamily.unknown;
    final bare = _norm(name, plus: false)!;
    final m = model(name);
    if (bare.startsWith('vdartsh2') &&
        (m == 'VDarts H2' || m == 'VDarts H2L')) {
      return VdartsFamily.h2;
    }
    if (n == 'vdartsble2010b') return VdartsFamily.h3;
    if (rest.startsWith('h2') ||
        rest.startsWith('h3') ||
        rest.startsWith('mini')) {
      return VdartsFamily.h3;
    }
    final after = n.substring(n.indexOf('vdarts') + 6);
    if (rest.startsWith('h4') || after.startsWith('ble')) {
      return VdartsFamily.h4;
    }
    return VdartsFamily.unknown;
  }

  /// Seule la H3L demande l'ouverture « AT/OK ».
  static bool isH3l(String? name) => model(name) == 'VDarts H3L';

  // ─── Zones ───

  static const _i = Ring.singleInner;
  static const _t = Ring.triple;
  static const _o = Ring.singleOuter;
  static const _d = Ring.double;

  /// (ligne, colonne) de la matrice → zone. (6, 1) = 25, (4, 1) = bull 50
  /// (vérifiés sur une capture par DartMate, comme S20, T20, D20, S19, T19,
  /// D19, T10, D10, T1, D1).
  static const Map<(int, int), (int, Ring)> matrix = {
    (0, 0): (4, _d),
    (0, 1): (13, _i),
    (0, 2): (4, _i),
    (0, 3): (13, _t),
    (0, 4): (4, _t),
    (0, 5): (13, _o),
    (0, 6): (4, _o),
    (1, 0): (18, _d),
    (1, 1): (6, _i),
    (1, 2): (6, _t),
    (1, 3): (18, _i),
    (1, 4): (6, _o),
    (1, 5): (18, _t),
    (1, 6): (18, _o),
    (2, 0): (1, _d),
    (2, 1): (10, _i),
    (2, 2): (10, _t),
    (2, 3): (10, _o),
    (2, 4): (1, _i),
    (2, 5): (1, _t),
    (2, 6): (1, _o),
    (3, 0): (20, _d),
    (3, 1): (15, _i),
    (3, 2): (15, _t),
    (3, 3): (15, _o),
    (3, 4): (20, _i),
    (3, 5): (20, _t),
    (3, 6): (20, _o),
    (4, 0): (5, _d),
    (4, 1): (25, Ring.innerBull),
    (4, 3): (15, _d),
    (4, 4): (10, _d),
    (4, 5): (6, _d),
    (4, 6): (13, _d),
    (5, 0): (12, _d),
    (5, 1): (12, _i),
    (5, 2): (5, _i),
    (5, 3): (5, _t),
    (5, 4): (12, _t),
    (5, 5): (5, _o),
    (5, 6): (12, _o),
    (6, 0): (7, _d),
    (6, 1): (25, Ring.outerBull),
    (6, 3): (2, _d),
    (6, 4): (17, _d),
    (6, 5): (3, _d),
    (6, 6): (19, _d),
    (7, 0): (9, _d),
    (7, 1): (2, _t),
    (7, 2): (2, _i),
    (7, 3): (2, _o),
    (7, 4): (9, _i),
    (7, 5): (9, _t),
    (7, 6): (9, _o),
    (7, 7): (9, _d),
    (8, 0): (14, _d),
    (8, 1): (17, _t),
    (8, 2): (17, _i),
    (8, 3): (17, _o),
    (8, 4): (14, _i),
    (8, 5): (14, _t),
    (8, 6): (14, _o),
    (9, 0): (11, _d),
    (9, 1): (3, _t),
    (9, 2): (3, _i),
    (9, 3): (3, _o),
    (9, 4): (11, _i),
    (9, 5): (11, _t),
    (9, 6): (11, _o),
    (10, 0): (8, _d),
    (10, 1): (19, _t),
    (10, 2): (19, _i),
    (10, 3): (8, _i),
    (10, 4): (19, _o),
    (10, 5): (8, _t),
    (10, 6): (8, _o),
    (11, 0): (16, _d),
    (11, 1): (16, _i),
    (11, 2): (7, _i),
    (11, 3): (7, _t),
    (11, 4): (16, _t),
    (11, 5): (7, _o),
    (11, 6): (16, _o),
  };

  static DartHit? hitAt(int row, int column) {
    final z = matrix[(row, column)];
    return z == null ? null : GranBoardDecoder.hitFor(z.$1, z.$2);
  }

  /// Octet brouillé → ligne (clé 0xD2 ; la clé 0xC9 = même octet ^ 27).
  static const _rows = {
    147: 0, 145: 1, 151: 2, 149: 3, 155: 4, 153: 5, //
    144: 6, 150: 7, 148: 8, 154: 9, 152: 10, 158: 11,
  };
  static const _cols = {
    227: 0,
    234: 1,
    228: 2,
    230: 3,
    229: 4,
    231: 5,
    225: 6,
  };

  static int? rowOf(int b) => _rows[b] ?? _rows[b ^ 27];
  static int? columnOf(int b) => _cols[b] ?? _cols[b ^ 27];

  /// 2 octets binaires d'une fléchette (tests, démonstrations).
  static List<int>? pairFor(int number, Ring ring, {bool altKey = false}) {
    for (final e in matrix.entries) {
      if (e.value.$1 == number && e.value.$2 == ring) {
        final r = _rows.entries.firstWhere((x) => x.value == e.key.$1).key;
        final c = _cols.entries.firstWhere((x) => x.value == e.key.$2).key;
        return altKey ? [r ^ 27, c ^ 27] : [r, c];
      }
    }
    return null;
  }

  // ─── Trames de service (ignorées) ───

  static const heartbeat = [65, 84]; // « AT »
  static const _serviceFrames = [
    [65, 84], // AT
    [118, 100], // vd
    [86, 68], // VD
    [0xE2, 0x36, 0xE2, 0x36, 0xE2, 0x36, 0xE2, 0x36], // accusé d'init H4
    [0xE2, 0x36],
  ];

  static bool _same(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] & 255 != b[i]) return false;
    }
    return true;
  }

  static bool isServiceFrame(List<int> b) =>
      _serviceFrames.any((f) => _same(b, f));

  static bool isHeartbeat(List<int> b) => _same(b, heartbeat);

  // ─── Commandes envoyées à la cible ───

  /// Commande de réglage / lumière : « & c & a & b & d ».
  static List<int> command(int c, int a, int b, int d) =>
      [38, c, 38, a, 38, b, 38, d];

  /// Séquence d'initialisation officielle (H4 ; ses 3 premiers paquets =
  /// ouverture de la H3L) et délai après chaque paquet (ms).
  static final h4Init = <List<int>>[
    [79, 75], // OK
    [86, 68], // VD
    [0xC9, 0x36], // clé
    command(37, 97, 0, 30),
    command(37, 97, 1, 160),
    command(37, 97, 2, 160),
    command(37, 97, 10, 30),
    command(37, 97, 11, 160),
    command(37, 97, 12, 160),
    command(43, 25, 4, 1),
  ];
  static const h4InitDelays = [10, 350, 200, 50, 50, 50, 50, 50, 550, 150];

  /// Réglages envoyés par la H2 après la clé.
  static final h2Settings = <List<int>>[
    for (final v in [0, 1, 2, 10, 11, 12]) command(37, 97, v, 160),
  ];
}

/// Décodeur d'une connexion VDarts (garde la fin de ligne en cours et les
/// délais du capteur de bordure).
class VdartsDecoder {
  VdartsDecoder({int Function()? clock})
      : _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch);

  final int Function() _clock;
  final _line = <int>[];
  int? _lastHit;
  int? _lastMiss;

  /// Délai pendant lequel le capteur de bordure est ignoré après une
  /// fléchette ou un autre signal (ms).
  static const missDebounce = 200;

  void reset() {
    _line.clear();
    _lastHit = null;
    _lastMiss = null;
  }

  static bool _ascii(int b) => b == 10 || b == 13 || (b >= 32 && b < 127);

  List<BoardEvent> accept(List<int> raw) {
    final bytes = [for (final b in raw) b & 255];
    if (bytes.isEmpty || Vdarts.isServiceFrame(bytes)) return const [];
    if (!bytes.every(_ascii)) {
      if (bytes.length.isOdd) return [UnknownEvent(_hex(bytes))];
      final out = <BoardEvent>[];
      for (var i = 0; i < bytes.length; i += 2) {
        final e = _pair(bytes[i], bytes[i + 1]);
        if (e != null) out.add(e);
      }
      return out;
    }
    final out = <BoardEvent>[];
    for (final b in bytes) {
      if (b == 10 || b == 13 || b == 64) {
        final e = _flush();
        if (e != null) out.add(e);
      } else {
        _line.add(b);
        if (_line.length > 64) _line.clear();
      }
    }
    return out;
  }

  BoardEvent? _flush() {
    final s = String.fromCharCodes(_line).trim();
    _line.clear();
    if (s.isEmpty) return null;
    if (s.toUpperCase() == 'BTN') return const ButtonEvent();
    final p = s.split(RegExp(r'\s+'));
    final cmd = p.first.toUpperCase();
    if (cmd == 'MAT' && p.length >= 4) {
      final r = int.tryParse(p[1]);
      final c = int.tryParse(p[2]);
      if (r != null && c != null && int.tryParse(p[3]) != null) {
        final h = Vdarts.hitAt(r, c);
        if (h != null) {
          _lastHit = _clock();
          return HitEvent(h);
        }
      }
    }
    if (cmd == 'BTN' && p.length >= 3 && int.tryParse(p[1]) != null) {
      return const ButtonEvent();
    }
    return UnknownEvent(s);
  }

  BoardEvent? _pair(int a, int b) {
    // Bouton : « M5 » brouillé (9F E7 ou 84 FC)
    if ((a ^ 0xD2) == 77 || (a ^ 0xC9) == 77) return const ButtonEvent();
    // Capteur de bordure : « N » + niveau
    if (a == 156 || a == 135) {
      final level = ((a ^ 78) ^ b) - 97;
      final known = level >= 0 && level < 32;
      if (known && level * 10 < 30) return null;
      final now = _clock();
      bool recent(int? t) =>
          t != null && now - t >= 0 && now - t < missDebounce;
      if (recent(_lastHit) || recent(_lastMiss)) return null;
      _lastMiss = now;
      return const MissEvent();
    }
    final r = Vdarts.rowOf(a);
    final c = Vdarts.columnOf(b);
    final h = r == null || c == null ? null : Vdarts.hitAt(r, c);
    if (h == null) return UnknownEvent(_hex([a, b]));
    _lastHit = _clock();
    return HitEvent(h);
  }

  static String _hex(List<int> b) =>
      b.map((x) => x.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
}

/// Ouverture de la connexion selon le modèle, une fois abonné aux
/// notifications. [write] envoie un paquet (et se termine quand la cible
/// l'a reçu) ; [gameplay] reçoit les octets à décoder ; [log] trace les
/// étapes pour le diagnostic.
class VdartsLink {
  VdartsLink({
    required this.family,
    required this.h3l,
    required this.write,
    required this.gameplay,
    this.log,
  });

  final VdartsFamily family;
  final bool h3l;
  final Future<void> Function(List<int> bytes, {bool h2}) write;
  final void Function(List<int> bytes) gameplay;
  final void Function(String message)? log;

  int _gen = 0;
  bool _closed = false;

  void _log(String m) => log?.call(m);

  /// Envoie des paquets un par un, avec un délai après chacun.
  Future<bool> _send(List<List<int>> packets, List<int> delays,
      {bool h2 = false}) async {
    final gen = _gen;
    for (var i = 0; i < packets.length; i++) {
      if (_closed || gen != _gen) return false;
      try {
        await write(packets[i], h2: h2).timeout(const Duration(seconds: 3));
      } catch (e) {
        _log('écriture refusée : $e');
        return false;
      }
      if (i < delays.length && delays[i] > 0) {
        await Future<void>.delayed(Duration(milliseconds: delays[i]));
      }
    }
    return !_closed && gen == _gen;
  }

  /// Abonnement fait : la H4 reçoit sa séquence, la H2 sa négociation.
  Future<void> start() async {
    switch (family) {
      case VdartsFamily.h4:
        _log('H4 : séquence d\'initialisation');
        final ok = await _send(Vdarts.h4Init, Vdarts.h4InitDelays);
        _log(ok ? 'H4 prête' : 'H4 : initialisation incomplète');
      case VdartsFamily.h2:
        _h2Ready = true;
        if (_h2 == _H2.idle) _h2Begin();
      case VdartsFamily.h3:
      case VdartsFamily.unknown:
        break;
    }
  }

  void close() {
    _closed = true;
    _gen++;
  }

  /// Trame reçue de la cible.
  void onNotification(List<int> raw) {
    final bytes = [for (final b in raw) b & 255];
    if (bytes.isEmpty) return;
    if (family == VdartsFamily.h2) {
      _h2Notification(bytes);
      return;
    }
    if (family == VdartsFamily.h3 && h3l && Vdarts.isHeartbeat(bytes)) {
      _h3lHeartbeat();
      return;
    }
    gameplay(bytes);
  }

  /// Une fléchette ou le bouton a été décodé.
  void onGameFrame() {
    if (_h3l != _H3l.accepted) {
      if (_h3l != _H3l.idle) _log('H3L : la cible envoie les fléchettes');
      _h3l = _H3l.accepted;
    }
    if (family == VdartsFamily.h2 && _h2 == _H2.idle) {
      _h2 = _H2.active;
      _log('H2 déjà active : pas de négociation');
    }
  }

  // ─── H3L : la cible ne fait qu'envoyer « AT » ───

  _H3l _h3l = _H3l.idle;
  int _beats = 0;

  void _h3lHeartbeat() {
    switch (_h3l) {
      case _H3l.idle:
        _h3l = _H3l.opening;
        _beats = 0;
        _log('H3L : ouverture OK, VD, clé');
        _send(Vdarts.h4Init.take(3).toList(), const [10, 350, 200]);
      case _H3l.opening:
        if (++_beats < 2) return;
        _h3l = _H3l.full;
        _beats = 0;
        _log('H3L : séquence complète');
        _send(Vdarts.h4Init, Vdarts.h4InitDelays);
      case _H3l.full:
        if (++_beats >= 2) {
          _h3l = _H3l.gaveUp;
          _log('H3L : pas de fléchette après l\'ouverture');
        }
      case _H3l.gaveUp:
      case _H3l.accepted:
        break;
    }
  }

  // ─── H2 : négociation ───

  _H2 _h2 = _H2.idle;
  bool _h2Ready = false;
  bool _idleA = false;
  int? _carry;
  bool _hello = false;
  bool _ack = false;
  bool _keySent = false;
  int _serial = 0;
  int _keySerial = 0;
  int _attempts = 0;
  final _buffered = <List<int>>[];

  static bool _eq(List<int> a, List<int> b) =>
      a.length == 2 && a[0] == b[0] && a[1] == b[1];

  void _h2Notification(List<int> bytes) {
    _serial++;
    if (_h2 == _H2.idle) {
      var b = bytes;
      if (_idleA) b = [65, ...b];
      _idleA = false;
      if (b.length >= 2 && b[0] == 65 && b[1] == 84) {
        if (b.length > 2) gameplay(b.sublist(2));
        if (_h2Ready) _h2Begin();
        return;
      }
      if (b.length == 1 && b[0] == 65) {
        _idleA = true;
        return;
      }
      gameplay(b);
      return;
    }
    if (_h2 == _H2.active) {
      gameplay(bytes);
      return;
    }
    if (_h2 == _H2.failed || _h2 == _H2.backoff) return;
    for (final x in bytes) {
      final c = _carry;
      if (c == null) {
        _carry = x;
      } else {
        _carry = null;
        _h2Pair([c, x]);
      }
    }
  }

  void _h2Pair(List<int> p) {
    final hello = _eq(p, [65, 84]) || _eq(p, [118, 100]);
    final vd = _eq(p, [86, 68]);
    switch (_h2) {
      case _H2.opening:
        if (hello) _hello = true;
      case _H2.waitHello:
        if (hello) _h2Key();
      case _H2.waitAck:
        if (vd && !_ack && _serial > _keySerial) {
          _ack = true;
          _log('H2 : confirmation VD reçue');
          if (_keySent) _h2Settings();
          return;
        }
        if (_ack && !hello && !vd) _h2Buffer(p);
      case _H2.settings:
        if (!hello && !vd) _h2Buffer(p);
      case _H2.ready:
        if (!hello && !vd) _h2Input(p);
      case _H2.idle:
      case _H2.active:
      case _H2.backoff:
      case _H2.failed:
        break;
    }
  }

  void _h2Buffer(List<int> p) {
    if (_buffered.length >= 64) {
      _h2Fail('trop de données pendant les réglages');
    } else {
      _buffered.add(p);
    }
  }

  void _h2Input(List<int> p) {
    final r = p[0] ^ 201;
    final c = p[1] ^ 201;
    if ((r >= 65 && r < 77 && c >= 49 && c < 57) ||
        r == 77 ||
        (r >= 78 && r < 82)) {
      gameplay(p);
    }
  }

  Future<void> _h2Begin() async {
    _attempts++;
    _h2 = _H2.opening;
    _carry = null;
    _hello = false;
    _ack = false;
    _keySent = false;
    _buffered.clear();
    final gen = ++_gen;
    _log('H2 : ouverture $_attempts/3 (RS, OK, VD)');
    final ok = await _send(
      const [
        [32, 32, 82, 83], // « RS »
        [79, 75], // OK
        [86, 68], // VD
      ],
      const [400, 100, 300],
      h2: true,
    );
    if (!ok || gen != _gen) return _h2Retry('ouverture refusée');
    _h2 = _H2.waitHello;
    if (_hello) return _h2Key();
    await Future<void>.delayed(const Duration(seconds: 2));
    if (gen == _gen && _h2 == _H2.waitHello) _h2Retry('pas de réponse AT');
  }

  Future<void> _h2Key() async {
    _h2 = _H2.waitAck;
    _carry = null;
    _ack = false;
    _keySent = false;
    _keySerial = _serial;
    final gen = _gen;
    final ok = await _send(const [
      [0xC9, 0x36]
    ], const [
      30
    ], h2: true);
    if (!ok || gen != _gen) return _h2Retry('clé refusée');
    _keySent = true;
    if (_ack) return _h2Settings();
    await Future<void>.delayed(const Duration(milliseconds: 570));
    if (gen == _gen && _h2 == _H2.waitAck) _h2Retry('pas de confirmation VD');
  }

  Future<void> _h2Settings() async {
    _h2 = _H2.settings;
    final gen = _gen;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final ok =
        await _send(Vdarts.h2Settings, const [50, 50, 50, 50, 50, 0], h2: true);
    if (!ok || gen != _gen) return _h2Retry('réglages refusés');
    _h2 = _H2.ready;
    _log('H2 prête');
    final pending = [..._buffered];
    _buffered.clear();
    pending.forEach(_h2Input);
  }

  Future<void> _h2Retry(String reason) async {
    if (_closed || _h2 == _H2.failed) return;
    if (_attempts >= 3) return _h2Fail(reason);
    _h2 = _H2.backoff;
    _carry = null;
    _log('H2 : $reason, nouvel essai');
    final gen = ++_gen;
    await Future<void>.delayed(const Duration(milliseconds: 1700));
    if (gen == _gen && !_closed) _h2Begin();
  }

  void _h2Fail(String reason) {
    _h2 = _H2.failed;
    _carry = null;
    _buffered.clear();
    _log('H2 : arrêt ($reason), reconnecte la cible pour réessayer');
  }
}

enum _H3l { idle, opening, full, gaveUp, accepted }

enum _H2 {
  idle,
  active,
  opening,
  waitHello,
  waitAck,
  settings,
  backoff,
  ready,
  failed
}
