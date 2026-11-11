// Décodage des trames BLE de la GranBoard.
//
// La cible envoie du texte ASCII de la forme "ligne.colonne@"
// (position dans la matrice de contacts), ou "BTN@" pour le bouton.

enum Ring { singleInner, triple, singleOuter, double, outerBull, innerBull }

class DartHit {
  /// 1 à 20, ou 25 pour le bull.
  final int number;

  /// 1 = simple, 2 = double (bull 50 compris), 3 = triple.
  final int multiplier;
  final Ring ring;

  const DartHit(this.number, this.multiplier, this.ring);

  int get score => number * multiplier;
  bool get isDouble => multiplier == 2;
  bool get isBull => number == 25;

  String get label {
    switch (ring) {
      case Ring.innerBull:
        return 'BULL';
      case Ring.outerBull:
        return '25';
      case Ring.triple:
        return 'T$number';
      case Ring.double:
        return 'D$number';
      case Ring.singleInner:
      case Ring.singleOuter:
        return '$number';
    }
  }

  @override
  String toString() => '$label ($score)';
}

sealed class BoardEvent {
  const BoardEvent();
  String get label;
}

class HitEvent extends BoardEvent {
  final DartHit hit;
  const HitEvent(this.hit);
  @override
  String get label => hit.toString();
}

class ButtonEvent extends BoardEvent {
  const ButtonEvent();
  @override
  String get label => 'BOUTON';
}

/// Fléchette dans la bordure extérieure (GranBoard 3s) : ratée, 0 point.
class MissEvent extends BoardEvent {
  const MissEvent();
  @override
  String get label => 'HORS CIBLE';
}

class UnknownEvent extends BoardEvent {
  final String raw;
  const UnknownEvent(this.raw);
  @override
  String get label => '? $raw';
}

class GranBoardDecoder {
  static const _i = Ring.singleInner;
  static const _t = Ring.triple;
  static const _o = Ring.singleOuter;
  static const _d = Ring.double;

  /// Table relevée par calibration sur la cible.
  static const Map<String, (int, Ring)> _codes = {
    '2.3': (1, _i),
    '2.4': (1, _t),
    '2.5': (1, _o),
    '2.6': (1, _d),
    '9.1': (2, _i),
    '9.0': (2, _t),
    '9.2': (2, _o),
    '8.2': (2, _d),
    '7.1': (3, _i),
    '7.0': (3, _t),
    '7.2': (3, _o),
    '8.4': (3, _d),
    '0.1': (4, _i),
    '0.3': (4, _t),
    '0.5': (4, _o),
    '0.6': (4, _d),
    '5.1': (5, _i),
    '5.2': (5, _t),
    '5.4': (5, _o),
    '4.6': (5, _d),
    '1.0': (6, _i),
    '1.1': (6, _t),
    '1.3': (6, _o),
    '4.4': (6, _d),
    '11.1': (7, _i),
    '11.2': (7, _t),
    '11.4': (7, _o),
    '8.6': (7, _d),
    '6.2': (8, _i),
    '6.4': (8, _t),
    '6.5': (8, _o),
    '6.6': (8, _d),
    '9.3': (9, _i),
    '9.4': (9, _t),
    '9.5': (9, _o),
    '9.6': (9, _d),
    '2.0': (10, _i),
    '2.1': (10, _t),
    '2.2': (10, _o),
    '4.3': (10, _d),
    '7.3': (11, _i),
    '7.4': (11, _t),
    '7.5': (11, _o),
    '7.6': (11, _d),
    '5.0': (12, _i),
    '5.3': (12, _t),
    '5.5': (12, _o),
    '5.6': (12, _d),
    '0.0': (13, _i),
    '0.2': (13, _t),
    '0.4': (13, _o),
    '4.5': (13, _d),
    '10.3': (14, _i),
    '10.4': (14, _t),
    '10.5': (14, _o),
    '10.6': (14, _d),
    '3.0': (15, _i),
    '3.1': (15, _t),
    '3.2': (15, _o),
    '4.2': (15, _d),
    '11.0': (16, _i),
    '11.3': (16, _t),
    '11.5': (16, _o),
    '11.6': (16, _d),
    '10.1': (17, _i),
    '10.0': (17, _t),
    '10.2': (17, _o),
    '8.3': (17, _d),
    '1.2': (18, _i),
    '1.4': (18, _t),
    '1.5': (18, _o),
    '1.6': (18, _d),
    '6.1': (19, _i),
    '6.0': (19, _t),
    '6.3': (19, _o),
    '8.5': (19, _d),
    '3.3': (20, _i),
    '3.4': (20, _t),
    '3.5': (20, _o),
    '3.6': (20, _d),
    '8.0': (25, Ring.outerBull),
    '4.0': (25, Ring.innerBull),
  };

  /// Texte brut d'une trame (clé des tables de calibration).
  static String frameKey(List<int> bytes) => String.fromCharCodes(bytes).trim();

  static DartHit hitFor(int number, Ring ring) {
    final multiplier = switch (ring) {
      Ring.triple => 3,
      Ring.double || Ring.innerBull => 2,
      _ => 1,
    };
    return DartHit(number, multiplier, ring);
  }

  /// [custom] : table calibrée pour une cible précise (trame brute → zone,
  /// null = bordure extérieure). Sans table, celle de la GranBoard Dash.
  static BoardEvent decode(List<int> bytes, {Map<String, DartHit?>? custom}) {
    final s = frameKey(bytes);
    if (s == 'BTN@') return const ButtonEvent();

    if (custom != null) {
      if (!custom.containsKey(s)) return UnknownEvent(s);
      final h = custom[s];
      return h == null ? const MissEvent() : HitEvent(h);
    }

    if (!s.endsWith('@')) return UnknownEvent(s);
    final entry = _codes[s.substring(0, s.length - 1)];
    if (entry == null) return UnknownEvent(s);
    final (number, ring) = entry;
    return HitEvent(hitFor(number, ring));
  }
}

/// Table de calibration sérialisable : une ligne par trame,
/// « trame⇥numéro⇥anneau » ou « trame⇥OUT » pour la bordure extérieure.
class BoardTable {
  static String encode(Map<String, DartHit?> t) => [
        for (final e in t.entries)
          e.value == null
              ? '${e.key}\tOUT'
              : '${e.key}\t${e.value!.number}\t${e.value!.ring.index}'
      ].join('\n');

  static Map<String, DartHit?> decode(String raw) {
    final out = <String, DartHit?>{};
    for (final line in raw.split('\n')) {
      final p = line.split('\t');
      if (p.length == 2 && p[1] == 'OUT') {
        out[p[0]] = null;
        continue;
      }
      if (p.length != 3) continue;
      final n = int.tryParse(p[1]);
      final r = int.tryParse(p[2]);
      if (n == null || r == null || r < 0 || r >= Ring.values.length) continue;
      out[p[0]] = GranBoardDecoder.hitFor(n, Ring.values[r]);
    }
    return out;
  }
}
