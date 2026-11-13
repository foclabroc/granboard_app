import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'game/darts_game.dart';

/// Partie en cours gardée sur le téléphone après chaque action : si l'appli
/// est fermée (batterie, Android, plantage), elle est proposée au lancement
/// suivant. Une seule partie (la dernière commencée), jamais en ligne.
class SavedGame {
  final DartsGame game;

  /// Match d'un tournoi à la maison : {uid, r, s}.
  final Map<String, dynamic>? tournament;
  final DateTime at;
  SavedGame(this.game, this.tournament, this.at);

  /// « 501 · CED, MAX · MANCHE 7 »
  String get summary {
    final names = game.players.map((p) => p.name.toUpperCase()).join(', ');
    return '${game.title.toUpperCase()} · $names · MANCHE ${game.round}';
  }
}

class GameSave {
  GameSave._();

  static const _pref = 'saved_game_v1';

  /// Garde la partie (ou l'efface si aucune fléchette n'a été lancée : une
  /// nouvelle partie remplace toujours l'ancienne).
  static Future<void> save(DartsGame game,
      {Map<String, dynamic>? tournament}) async {
    try {
      final p = await SharedPreferences.getInstance();
      if (game.actionLog.isEmpty) {
        await p.remove(_pref);
        return;
      }
      await p.setString(
          _pref,
          jsonEncode({
            'game': game.toJson(),
            if (tournament != null) 'tn': tournament,
            'at': DateTime.now().toIso8601String(),
          }));
    } catch (_) {}
  }

  static Future<void> clear() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(_pref);
    } catch (_) {}
  }

  /// Partie gardée, ou null (rien, illisible, ou plus vieille que 3 jours).
  static Future<SavedGame?> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_pref);
      if (raw == null) return null;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final at = DateTime.tryParse('${j['at']}') ?? DateTime.now();
      if (DateTime.now().difference(at).inDays >= 3) {
        await p.remove(_pref);
        return null;
      }
      final game = gameFromJson(Map<String, dynamic>.from(j['game'] as Map));
      final tn = j['tn'];
      return SavedGame(
          game, tn is Map ? Map<String, dynamic>.from(tn) : null, at);
    } catch (_) {
      return null;
    }
  }
}
