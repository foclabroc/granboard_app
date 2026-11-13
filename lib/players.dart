import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game/cricket.dart';
import 'game/match.dart';
import 'game/practice.dart';
import 'game/x01.dart';
import 'media.dart';
import 'server.dart';
import 'rank.dart';

const kPlayerColors = [
  Color(0xFFE53935),
  Color(0xFF1E88E5),
  Color(0xFF43A047),
  Color(0xFFFDD835),
  Color(0xFF8E24AA),
  Color(0xFFFB8C00),
  Color(0xFF00ACC1),
  Color(0xFFD81B60),
  // Depuis la 0.6.3 (les versions d'avant affichent une des 8 premières)
  Color(0xFFECEFF1), // blanc
  Color(0xFFC6FF00), // citron vert
  Color(0xFF1DE9B6), // menthe
  Color(0xFF5C6BC0), // indigo
  Color(0xFF8D6E63), // marron
  Color(0xFFB388FF), // lavande
  Color(0xFFFF8A80), // corail
  kRainbow,
];

/// Couleur « arc-en-ciel » : valeur repère, dessinée en dégradé par
/// [playerFill] (avatars, pastilles) ; ailleurs elle reste ce rose.
const kRainbow = Color(0xFFFF5FD2);

const kRainbowColors = [
  Color(0xFFFF1744),
  Color(0xFFFF9100),
  Color(0xFFFFEA00),
  Color(0xFF00E676),
  Color(0xFF00B0FF),
  Color(0xFFD500F9),
  Color(0xFFFF1744),
];

bool isRainbow(Color c) => c.toARGB32() == kRainbow.toARGB32();

/// Dégradé de la couleur arc-en-ciel, sinon rien (couleur unie).
Gradient? playerFill(Color c) =>
    isRainbow(c) ? const SweepGradient(colors: kRainbowColors) : null;

const kGuestColor = Color(0xFF8D8D9C);

/// Rang (C … GM) d'après la note sur 20 (voir `rank.dart`).
String ratingClass(double r) => rankOf(r).label;

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

  /// Notes sur 20 des joueurs qui ne sont pas sur ce téléphone (adversaire en
  /// ligne, joueurs vus par l'écran TV), lues sur le serveur.
  final Map<String, double?> remoteRatings = {};

  /// Note sur 20 d'un joueur (null : invité, pas encore de partie, inconnu).
  double? ratingOf(String id) {
    final p = byId(id);
    return p != null ? p.rating : remoteRatings[id];
  }

  /// Va chercher la note des joueurs qui ne sont pas sur ce téléphone.
  Future<void> ensureRatings(Iterable<String> ids) async {
    final todo = [
      for (final id in ids)
        if (!isGuestId(id) &&
            byId(id) == null &&
            !remoteRatings.containsKey(id) &&
            int.tryParse(id) != null)
          id
    ];
    if (todo.isEmpty) return;
    for (final id in todo) {
      remoteRatings[id] = null; // une seule demande par joueur
    }
    var changed = false;
    for (final id in todo) {
      try {
        final prof = await GbServer.profile(int.parse(id));
        final r = ((prof['stats'] as Map?)?['rating'] as num?)?.toDouble();
        if (r != null) {
          remoteRatings[id] = r;
          changed = true;
        }
      } catch (_) {
        remoteRatings.remove(id); // on retentera plus tard
      }
    }
    if (changed) notifyListeners();
  }

  /// Couleurs de joueurs toutes différentes pour une partie : la couleur du
  /// compte, sauf invité ou couleur déjà prise (on prend une couleur libre).
  List<Color> distinctColors(List<String> ids) {
    final used = <int>{};
    final out = <Color?>[];
    for (final id in ids) {
      final c = isGuestId(id) ? null : byId(id)?.color ?? remoteColors[id];
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

  /// Couleurs de la partie en cours (toutes différentes, voir
  /// [setGameColors]) : prioritaires sur celles des comptes.
  final Map<String, Color> gameColors = {};

  /// Début d'une partie : couleur du compte si elle est libre, sinon une
  /// couleur libre (15 couleurs, l'arc-en-ciel seulement s'il est choisi) ;
  /// invités et bots ont chacun la leur. La couleur du compte ne change pas.
  void setGameColors(List<String> ids) {
    gameColors.clear();
    final cs = distinctColors(ids);
    for (var i = 0; i < ids.length; i++) {
      gameColors[ids[i]] = cs[i];
    }
  }

  Color colorOf(String id) =>
      gameColors[id] ?? byId(id)?.color ?? remoteColors[id] ?? kGuestColor;

  int _freeColor() {
    final used = players.map((p) => p.colorIndex).toSet();
    // L'arc-en-ciel (dernier) ne se donne pas tout seul
    for (var i = 0; i < kPlayerColors.length - 1; i++) {
      if (!used.contains(i)) return i;
    }
    return players.length % (kPlayerColors.length - 1);
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

  // ─── Hors ligne : renvoi automatique au retour du réseau ───

  Timer? _auto;
  bool _wasReachable = true;

  /// Toutes les 30 s : renvoie les parties en attente, ou vérifie si le
  /// serveur est revenu ; dès qu'il revient, tout est resynchronisé.
  void startAutoSync() {
    if (_auto != null) return;
    _auto = Timer.periodic(const Duration(seconds: 30), (_) => _autoTick());
    GbServer.reachable.addListener(_onReachable);
  }

  void _onReachable() {
    final r = GbServer.reachable.value;
    if (r && !_wasReachable) sync();
    _wasReachable = r;
  }

  Future<void> _autoTick() async {
    if (pending.isNotEmpty) {
      await flush();
    } else if (!GbServer.reachable.value) {
      try {
        await GbServer.check(const []);
      } catch (_) {}
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
      notifyListeners(); // nombre de parties en attente
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
        if (g.settings.teamPlay) 'team': p.team,
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
