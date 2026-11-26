import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bot.dart';
import 'darts_game.dart';

/// Adversaires virtuels à niveau fixe (portraits de foclabroc dans
/// `assets/bots/<id>.jpg`, maquette `adversaires.html`). Ce sont des joueurs
/// virtuels (`guest-bot-<id>`) : même moteur que le « Joueur virtuel », mais
/// le niveau est celui de leur note au lieu de suivre les humains.
/// Progression : il faut battre un personnage pour débloquer le suivant.
class Persona {
  final String id;
  final String name;
  final String title;

  /// Note sur 20 (rang : C … GM, voir `rank.dart`).
  final double note;
  final Color color;
  const Persona(this.id, this.name, this.title, this.note, this.color);

  String get playerId => 'guest-bot-$id';
  String get asset => 'assets/bots/$id.jpg';

  /// Petit son du tour (`assets/sounds/turn/bot_<id>.ogg`,
  /// `tools/motion_hits/bot_sounds.py`), à la place d'un son de compte.
  String get sound => 'bot_$id';
}

const kPersonas = <Persona>[
  Persona('enzo', 'Enzo', 'le grand débutant', 2, Color(0xFF1EA7FF)),
  Persona('chloe', 'Chloé', 'la gauchère timide', 4, Color(0xFFB45CFF)),
  Persona('nico', 'Nico', 'le joueur du dimanche', 6, Color(0xFFFF8A1F)),
  Persona('karim', 'Karim', 'le créatif', 8, Color(0xFFFF3D5A)),
  Persona('antoine', 'Antoine', 'le persévérant', 10, Color(0xFF4FB3D9)),
  Persona('valerie', 'Valérie', 'la compétitrice', 12, Color(0xFFFF8A1F)),
  Persona('gege', 'Gégé', 'le vétéran des pubs', 14, Color(0xFFB45CFF)),
  Persona('sarah', 'Sarah', 'la machine', 17, Color(0xFF1EA7FF)),
  Persona('boss', 'Le Boss', 'le roi du bullseye', 20, Color(0xFFFF2D46)),
];

/// Personnage d'un identifiant de joueur (`guest-bot-<id>`), sinon null.
Persona? personaOf(String playerId) {
  if (!playerId.startsWith('guest-bot-')) return null;
  final id = playerId.substring(10);
  for (final p in kPersonas) {
    if (p.id == id) return p;
  }
  return null;
}

/// Bilan contre chaque personnage (pref `personas_v1` = {id: [victoires,
/// défaites]} du point de vue des joueurs du téléphone, gardé sur le
/// compte) et déblocage.
class PersonaRecords extends ChangeNotifier {
  PersonaRecords._();
  static final instance = PersonaRecords._();
  static const pref = 'personas_v1';

  final Map<String, (int, int)> _r = {};

  (int, int) of(String id) => _r[id] ?? (0, 0);

  /// Le 1er est toujours ouvert ; ensuite, il faut avoir battu le précédent.
  bool unlocked(Persona p) {
    final i = kPersonas.indexOf(p);
    return i <= 0 || of(kPersonas[i - 1].id).$1 > 0;
  }

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final m = jsonDecode(p.getString(pref) ?? '{}') as Map<String, dynamic>;
      _r
        ..clear()
        ..addAll({
          for (final e in m.entries)
            e.key: ((e.value as List)[0] as int, (e.value as List)[1] as int)
        });
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
          pref,
          jsonEncode({
            for (final e in _r.entries) e.key: [e.value.$1, e.value.$2]
          }));
    } catch (_) {}
  }

  /// Partie finie : un humain a gagné → victoire contre chaque personnage de
  /// la partie ; sinon défaite. Rien sans humain ni personnage.
  Future<void> record(DartsGame g) async {
    if (!g.finished) return;
    final personas = [
      for (final p in g.players)
        if (personaOf(p.id) case final x?) x
    ];
    final humans = g.players.where((p) => !isBotId(p.id));
    if (personas.isEmpty || humans.isEmpty) return;
    final humanWon = g.winners.any((i) => !isBotId(g.players[i].id));
    for (final p in personas) {
      final (w, l) = of(p.id);
      _r[p.id] = humanWon ? (w + 1, l) : (w, l + 1);
    }
    notifyListeners();
    await _save();
  }

  @visibleForTesting
  void debugSet(String id, int w, int l) {
    _r[id] = (w, l);
    notifyListeners();
  }
}
