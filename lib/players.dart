import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game/cricket.dart';
import 'game/match.dart';
import 'game/practice.dart';
import 'game/x01.dart';
import 'media.dart';
import 'server.dart';

const kPlayerColors = [
  Color(0xFFE53935),
  Color(0xFF1E88E5),
  Color(0xFF43A047),
  Color(0xFFFDD835),
  Color(0xFF8E24AA),
  Color(0xFFFB8C00),
  Color(0xFF00ACC1),
  Color(0xFFD81B60),
];

const kGuestColor = Color(0xFF8D8D9C);

/// Classe de niveau d'après la note (moyenne aux 3 fléchettes).
String ratingClass(double r) {
  if (r >= 80) return 'MASTER';
  if (r >= 65) return 'AAA';
  if (r >= 55) return 'AA';
  if (r >= 45) return 'A';
  if (r >= 35) return 'B';
  if (r >= 25) return 'C';
  return 'D';
}

bool isGuestId(String id) => id.startsWith('guest-');

/// Compte joueur mémorisé sur ce téléphone (pseudo + PIN sur le serveur).
class PlayerProfile {
  final int id;
  String name;
  int colorIndex;
  String token;

  /// Session refusée par le serveur : il faut se reconnecter.
  bool expired;

  /// Dernier profil reçu du serveur (stats, note, rang, parties récentes).
  Map<String, dynamic>? profile;

  PlayerProfile({
    required this.id,
    required this.name,
    required this.token,
    this.colorIndex = 0,
    this.expired = false,
    this.profile,
  });

  /// Identifiant utilisé dans les parties (X01Player.id).
  String get key => '$id';

  Color get color => kPlayerColors[colorIndex % kPlayerColors.length];

  Map<String, dynamic> get stats =>
      (profile?['stats'] as Map?)?.cast<String, dynamic>() ?? const {};

  double? get rating => (stats['rating'] as num?)?.toDouble();
  int? get rank => (profile?['rank'] as num?)?.toInt();
  int get games => (stats['games'] as num?)?.toInt() ?? 0;
  int get wins => (stats['wins'] as num?)?.toInt() ?? 0;
  double get average => (stats['avg'] as num?)?.toDouble() ?? 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': colorIndex,
        'token': token,
        'expired': expired,
        if (profile != null) 'profile': profile,
      };

  factory PlayerProfile.fromJson(Map<String, dynamic> j) => PlayerProfile(
        id: (j['id'] as num).toInt(),
        name: j['name'] as String,
        token: j['token'] as String,
        colorIndex: (j['color'] as num?)?.toInt() ?? 0,
        expired: j['expired'] as bool? ?? false,
        profile: (j['profile'] as Map?)?.cast<String, dynamic>(),
      );
}

/// Comptes mémorisés + parties en attente d'envoi (hors ligne).
class PlayerStore extends ChangeNotifier {
  PlayerStore._();
  static final instance = PlayerStore._();

  static const _keyAccounts = 'accounts_v1';
  static const _keyPending = 'pending_games_v1';
  static const _keyWelcome = 'welcome_done_v1';

  /// Accueil du premier lancement déjà passé (profil principal créé ou
  /// « plus tard »).
  bool welcomed = false;

  /// Profil principal du téléphone (son propriétaire) : toujours le premier.
  PlayerProfile? get owner => players.isEmpty ? null : players.first;

  bool isOwner(PlayerProfile p) => identical(owner, p);

  /// Fait de ce compte le profil principal.
  Future<void> setOwner(PlayerProfile p) async {
    players
      ..remove(p)
      ..insert(0, p);
    await _save();
  }

  Future<void> setWelcomed() async {
    welcomed = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyWelcome, true);
    } catch (_) {}
    notifyListeners();
  }

  final List<PlayerProfile> players = [];

  /// Parties pas encore envoyées. Les joueurs y sont désignés par leur id :
  /// le jeton est ajouté au moment de l'envoi (il peut changer entre-temps).
  final List<Map<String, dynamic>> pending = [];

  bool syncing = false;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    players.clear();
    pending.clear();
    welcomed = prefs.getBool(_keyWelcome) ?? false;
    try {
      for (final p
          in jsonDecode(prefs.getString(_keyAccounts) ?? '[]') as List) {
        players
            .add(PlayerProfile.fromJson(Map<String, dynamic>.from(p as Map)));
      }
    } catch (_) {}
    try {
      for (final g
          in jsonDecode(prefs.getString(_keyPending) ?? '[]') as List) {
        pending.add(Map<String, dynamic>.from(g as Map));
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _keyAccounts, jsonEncode(players.map((p) => p.toJson()).toList()));
    await prefs.setString(_keyPending, jsonEncode(pending));
    notifyListeners();
  }

  PlayerProfile? byId(String id) {
    for (final p in players) {
      if (p.key == id) return p;
    }
    return null;
  }

  /// Couleurs reçues du téléphone (écran TV : il ne connaît pas les comptes).
  final Map<String, Color> remoteColors = {};

  /// Couleurs de joueurs toutes différentes pour une partie : la couleur du
  /// compte, sauf invité ou couleur déjà prise (on prend une couleur libre).
  List<Color> distinctColors(List<String> ids) {
    final used = <int>{};
    final out = <Color?>[];
    for (final id in ids) {
      final c = isGuestId(id) ? null : colorOf(id);
      out.add(c != null && used.add(c.toARGB32()) ? c : null);
    }
    return [
      for (final c in out)
        c ??
            (() {
              final free = kPlayerColors.firstWhere(
                  (k) => !used.contains(k.toARGB32()),
                  orElse: () => kGuestColor);
              used.add(free.toARGB32());
              return free;
            })()
    ];
  }

  Color colorOf(String id) =>
      byId(id)?.color ?? remoteColors[id] ?? kGuestColor;

  int _freeColor() {
    final used = players.map((p) => p.colorIndex).toSet();
    for (var i = 0; i < kPlayerColors.length; i++) {
      if (!used.contains(i)) return i;
    }
    return players.length % kPlayerColors.length;
  }

  Future<PlayerProfile> _remember(Map<String, dynamic> acc) async {
    final id = (acc['id'] as num).toInt();
    var p = byId('$id');
    if (p == null) {
      p = PlayerProfile(
        id: id,
        name: acc['pseudo'] as String,
        token: acc['token'] as String,
        colorIndex: (acc['color'] as num?)?.toInt() ?? 0,
      );
      players.add(p);
    } else {
      p
        ..name = acc['pseudo'] as String
        ..token = acc['token'] as String
        ..colorIndex = (acc['color'] as num?)?.toInt() ?? p.colorIndex
        ..expired = false;
    }
    await _save();
    refreshProfile(p);
    flush();
    return p;
  }

  /// Création de compte (lève ApiError).
  Future<PlayerProfile> register(String pseudo, String pin) async =>
      _remember(await GbServer.register(pseudo.trim(), pin, _freeColor()));

  /// Connexion d'un compte existant (lève ApiError).
  Future<PlayerProfile> login(String pseudo, String pin) async =>
      _remember(await GbServer.login(pseudo.trim(), pin));

  /// Retire le compte de ce téléphone (le compte reste sur le serveur).
  Future<void> forget(PlayerProfile p) async {
    players.remove(p);
    await _save();
    try {
      await GbServer.logout(p.token);
    } catch (_) {}
  }

  Future<void> setColor(PlayerProfile p, int color) async {
    p.colorIndex = color;
    await _save();
    try {
      await GbServer.setColor(p.token, color);
    } catch (_) {}
  }

  Future<void> refreshProfile(PlayerProfile p) async {
    try {
      p.profile = await GbServer.profile(p.id);
      await _save();
    } catch (_) {}
  }

  /// Au démarrage : vérifie les sessions, envoie les parties en attente,
  /// met à jour les profils. Silencieux hors ligne.
  Future<void> sync() async {
    if (players.isEmpty && pending.isEmpty) return;
    try {
      final valid = await GbServer.check([for (final p in players) p.token]);
      final ok = {for (final a in valid) (a['id'] as num).toInt()};
      for (final p in players) {
        p.expired = !ok.contains(p.id);
      }
      await _save();
    } on ApiError {
      return; // hors ligne : on réessaiera
    }
    await flush();
    MediaStore.instance.ensure(players.map((p) => p.key));
    for (final p in players) {
      await refreshProfile(p);
    }
  }

  /// Envoie les parties en attente. Renvoie true si tout est parti.
  Future<bool> flush() async {
    if (syncing) return pending.isEmpty;
    syncing = true;
    try {
      while (pending.isNotEmpty) {
        final g = pending.first;
        final send = <Map<String, dynamic>>[];
        for (final pl in (g['players'] as List)) {
          final m = Map<String, dynamic>.from(pl as Map);
          final acc = byId('${m.remove('pid')}');
          if (acc == null || acc.expired) continue;
          send.add({...m, 'token': acc.token});
        }
        if (send.isEmpty) {
          // Joueurs oubliés ou à reconnecter : on garde si reconnexion possible
          final waiting = (g['players'] as List)
              .any((pl) => byId('${(pl as Map)['pid']}')?.expired == true);
          if (waiting) return false;
          pending.removeAt(0);
          await _save();
          continue;
        }
        try {
          await GbServer.submit({...g, 'players': send});
          pending.removeAt(0);
          await _save();
        } on ApiError catch (e) {
          if (e.offline) return false;
          if (e.code == 'session') {
            await sync();
            return false;
          }
          // Partie refusée (valeurs, doublon) : on la retire
          pending.removeAt(0);
          await _save();
        }
      }
      return true;
    } finally {
      syncing = false;
    }
  }

  /// Enregistre une partie X01 terminée (envoi immédiat ou plus tard).
  /// Renvoie true si elle est déjà sur le serveur.
  Future<bool> recordX01(X01Game g) async {
    final ps = <Map<String, dynamic>>[];
    for (var i = 0; i < g.players.length; i++) {
      final p = g.players[i];
      if (isGuestId(p.id)) continue;
      final s = g.stateOf(i);
      ps.add({
        'pid': p.id,
        if (g.settings.freeze) 'team': p.team,
        'won': g.winners.contains(i),
        'darts': s.darts,
        'points': s.points,
        'highest': s.highestTurn,
        'n100': s.count100,
        'n180': s.count180,
        if (s.checkout != null) 'checkout': s.checkout,
        'remaining': s.remaining,
      });
    }
    if (ps.isEmpty) return true; // que des invités
    pending.add({
      'cid': '${DateTime.now().microsecondsSinceEpoch}-${ps.first['pid']}',
      'kind': 'x01',
      'mode': g.settings.name,
      'start': g.settings.startScore,
      'freeze': g.settings.freeze,
      'in': g.settings.inRule.name,
      'out': g.settings.outRule.name,
      if (g.settings.roundLimit != null) 'rounds': g.settings.roundLimit,
      'n': g.players.length,
      'players': ps,
    });
    await _save();
    final sent = await flush();
    for (final p in ps) {
      final acc = byId('${p['pid']}');
      if (acc != null) await refreshProfile(acc);
    }
    return sent;
  }

  /// Partie de Cricket terminée (invités exclus).
  Future<bool> recordCricket(CricketGame g) async {
    final ps = <Map<String, dynamic>>[];
    for (var i = 0; i < g.players.length; i++) {
      final p = g.players[i];
      if (isGuestId(p.id)) continue;
      final s = g.statsOf(i);
      ps.add({
        'pid': p.id,
        if (g.settings.teams) 'team': p.team,
        'won': g.winners.contains(i),
        'darts': s.darts,
        'points': s.points,
        'marks': s.marks,
        'highest': s.bestTurn,
        'remaining': 0,
      });
    }
    if (ps.isEmpty) return true;
    pending.add({
      'cid': '${DateTime.now().microsecondsSinceEpoch}-${ps.first['pid']}',
      'kind': 'cricket',
      'mode': g.settings.name,
      'variant': g.settings.variant.name,
      'start': 0,
      'freeze': g.settings.teams,
      if (g.settings.roundLimit != null) 'rounds': g.settings.roundLimit,
      'n': g.players.length,
      'players': ps,
    });
    await _save();
    final sent = await flush();
    for (final p in ps) {
      final acc = byId('${p['pid']}');
      if (acc != null) await refreshProfile(acc);
    }
    return sent;
  }

  /// Match terminé : chaque leg est enregistré comme une partie de son jeu.
  Future<bool> recordMatch(MatchGame m) async {
    var ok = true;
    for (final l in m.legs) {
      if (!l.finished) continue;
      final r = switch (l) {
        X01Game g => await recordX01(g),
        CricketGame g => await recordCricket(g),
        _ => true,
      };
      ok = ok && r;
    }
    return ok;
  }

  /// Partie d'entraînement terminée (invités exclus) : le score sert aux
  /// classements « meilleur score » de chaque jeu.
  Future<bool> recordPractice(PracticeGame g) async {
    final ps = <Map<String, dynamic>>[];
    for (var i = 0; i < g.players.length; i++) {
      final p = g.players[i];
      if (isGuestId(p.id)) continue;
      final s = g.stateOf(i);
      ps.add({
        'pid': p.id,
        'won': g.winners.contains(i) && g.players.length > 1,
        'darts': s.darts,
        'points': s.score,
        'marks': s.good,
        'highest': 0,
        'remaining': 0,
      });
    }
    if (ps.isEmpty) return true;
    pending.add({
      'cid': '${DateTime.now().microsecondsSinceEpoch}-${ps.first['pid']}',
      'kind': 'practice',
      'mode': g.settings.name,
      'variant': g.settings.kind.name,
      'start': 0,
      'freeze': false,
      'n': g.players.length,
      'players': ps,
    });
    await _save();
    final sent = await flush();
    for (final p in ps) {
      final acc = byId('${p['pid']}');
      if (acc != null) await refreshProfile(acc);
    }
    return sent;
  }
}
