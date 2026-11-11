// Interface commune des jeux (01, Cricket…) : l'écran de partie, l'écran TV
// et l'envoi au serveur ne dépendent que de ce qui est ici.

import '../granboard.dart';
import 'cricket.dart';
import 'match.dart';
import 'x01.dart';

abstract interface class DartsGame {
  /// « x01 », « cricket »… (envoyé à la TV pour rejouer le bon jeu).
  String get kind;

  /// Nom affiché (« 501 », « CRICKET CUT THROAT »…).
  String get title;
  String get rulesLabel;

  List<X01Player> get players;
  int get current;
  X01Player get currentPlayer;
  int get round;
  int? get roundLimit;

  bool get finished;

  /// Manche terminée : on attend « joueur suivant ».
  bool get turnOver;
  bool get canUndo;
  List<int> get winners;

  /// Fléchettes de la manche en cours (null = ratée).
  List<DartHit?> get turnHits;

  bool throwDart(DartHit? hit);
  bool next();
  bool undo();

  List<String> get actionLog;
  Map<String, dynamic> toJson();
  bool applyLogEntry(String a);
}

/// Rejoue une partie reçue (écran TV).
DartsGame gameFromJson(Map<String, dynamic> j) => switch (j['kind']) {
      'cricket' => CricketGame.fromJson(j),
      'match' => MatchGame.fromJson(j),
      _ => X01Game.fromJson(j),
    };

/// Décode une entrée du journal : « n », « m » ou « d:<numéro>:<anneau> ».
/// Renvoie (suivant ?, fléchette) ; null si l'entrée est invalide.
(bool, DartHit?)? parseLogEntry(String a) {
  if (a == 'n') return (true, null);
  if (a == 'm') return (false, null);
  final p = a.split(':');
  if (p.length != 3 || p[0] != 'd') return null;
  final n = int.tryParse(p[1]);
  final r = int.tryParse(p[2]);
  if (n == null || r == null || r < 0 || r >= Ring.values.length) return null;
  return (false, GranBoardDecoder.hitFor(n, Ring.values[r]));
}

String logEntryOf(bool next, DartHit? hit) => next
    ? 'n'
    : hit == null
        ? 'm'
        : 'd:${hit.number}:${hit.ring.index}';
