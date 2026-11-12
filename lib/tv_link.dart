import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'audio.dart';
import 'game/darts_game.dart';
import 'players.dart';
import 'server.dart';
import 'ui/theme.dart';
import 'ui/cricket_view.dart' show CricketStyle;
import 'ui/dartboard.dart' show BoardSkin;

/// Un écran relié (TV, tablette…), un salon par écran sur le serveur.
class TvScreen {
  final String code;
  final String hostKey;
  final String name;
  TvScreen(this.code, this.hostKey, this.name);

  String get label => '$name $code';

  Map<String, dynamic> toJson() => {'code': code, 'key': hostKey, 'name': name};
  factory TvScreen.fromJson(Map<String, dynamic> j) =>
      TvScreen('${j['code']}', '${j['key']}', '${j['name'] ?? 'Écran'}');
}

/// Côté téléphone : liaison avec un ou plusieurs écrans. Le téléphone pilote
/// tout et envoie l'état à chaque écran ; le son sort sur un ou plusieurs
/// appareils (téléphone et/ou écrans).
class TvLink extends ChangeNotifier {
  TvLink._();
  static final instance = TvLink._();

  static const _prefKey = 'tv_link_v2';
  static const _prefOld = 'tv_link_v1';
  static const phone = 'phone';

  final List<TvScreen> screens = [];

  /// Appareils qui jouent le son : [phone] et/ou des codes d'écran
  /// (jamais vide).
  final Set<String> soundOn = {phone};

  bool soundsOn(String target) => soundOn.contains(target);

  void _setSound(Iterable<String> targets) {
    final t = targets.toList();
    soundOn
      ..clear()
      ..addAll(t);
  }

  String? error;

  bool get linked => screens.isNotEmpty;

  Map<String, dynamic>? _last; // dernier état envoyé (renvoyé si le son change)
  final _pending = <String, Map<String, dynamic>>{};
  final _sending = <String>{};

  Future<void> load() async {
    screens.clear();
    _setSound([phone]);
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw != null) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        for (final s in (j['screens'] as List? ?? const [])) {
          screens.add(TvScreen.fromJson(Map<String, dynamic>.from(s as Map)));
        }
        // Avant la 0.6.3 : un seul appareil (texte)
        final snd = j['sound'];
        _setSound(
            snd is List ? snd.map((e) => '$e') : [snd is String ? snd : phone]);
      } else {
        // Ancienne liaison (un seul écran)
        final old = prefs.getString(_prefOld);
        if (old != null) {
          final j = jsonDecode(old) as Map<String, dynamic>;
          screens.add(TvScreen('${j['code']}', '${j['key']}', 'TV'));
          _setSound(['${j['code']}']);
          await prefs.remove(_prefOld);
        }
      }
    } catch (_) {}
    _fixSound();
    _applyMute();
    notifyListeners();
  }

  Future<void> _save() async {
    _fixSound();
    _applyMute();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _prefKey,
        jsonEncode({
          'screens': [for (final s in screens) s.toJson()],
          'sound': soundOn.toList(),
        }));
  }

  /// Les écrans retirés ne jouent plus le son ; s'il ne reste personne, le
  /// son revient au téléphone.
  void _fixSound() {
    soundOn.removeWhere((t) => t != phone && !screens.any((s) => s.code == t));
    if (soundOn.isEmpty) soundOn.add(phone);
  }

  void _applyMute() => AudioService.instance.muted = !soundOn.contains(phone);

  String get _hostName {
    final ps = PlayerStore.instance.players;
    return ps.isEmpty ? 'Téléphone' : ps.first.name;
  }

  /// Noms des appareils qui jouent le son.
  String get soundLabel => [
        if (soundOn.contains(phone)) 'Téléphone',
        for (final s in screens)
          if (soundOn.contains(s.code)) s.name,
      ].join(' + ');

  /// Relie l'écran qui affiche [tvCode] (lève ApiError). Une TV reliée
  /// prend le son si le son était sur le téléphone.
  Future<TvScreen> link(String tvCode) async {
    final r = await GbServer.rpc('gb_tv_link',
        {'p_code': tvCode.trim().toUpperCase(), 'p_name': _hostName});
    final m = Map<String, dynamic>.from(r as Map);
    final s =
        TvScreen('${m['code']}', '${m['host_key']}', '${m['name'] ?? 'Écran'}');
    screens.removeWhere((x) => x.code == s.code);
    screens.add(s);
    if (soundOn.length == 1 && soundOn.contains(phone) && s.name == 'TV') {
      _setSound([s.code]);
    }
    error = null;
    await _save();
    _resend();
    return s;
  }

  Future<void> unlink(String code) async {
    screens.removeWhere((s) => s.code == code);
    _pending.remove(code);
    await _save();
    _resend(); // le son a pu changer d'écran
  }

  Future<void> unlinkAll() async {
    screens.clear();
    _pending.clear();
    await _save();
  }

  /// Un seul appareil joue le son ([phone] ou code d'écran).
  Future<void> setSoundOn(String target) async {
    _setSound([target]);
    await _save();
    _resend();
  }

  /// Ajoute ou retire un appareil ; le dernier coché ne se retire pas.
  Future<void> toggleSound(String target) async {
    if (soundOn.contains(target)) {
      if (soundOn.length == 1) return;
      soundOn.remove(target);
    } else {
      soundOn.add(target);
    }
    await _save();
    _resend();
  }

  /// Écran d'attente (accueil, réglages).
  void pushLobby() => _push({'screen': 'lobby', 'host': _hostName});

  /// Partie en cours ([screen] = game) ou terminée ([screen] = results).
  void pushGame(DartsGame game, {String screen = 'game'}) {
    final store = PlayerStore.instance;
    _push({
      'screen': screen,
      'host': _hostName,
      'game': game.toJson(),
      'colors': {
        for (final p in game.players) p.id: store.colorOf(p.id).toARGB32(),
      },
    });
  }

  void _resend() {
    final last = _last;
    if (last != null) _push(last);
  }

  void _push(Map<String, dynamic> state) {
    _last = state;
    for (final s in screens) {
      // Chaque écran sait s'il doit jouer le son
      _pending[s.code] = {
        ...state,
        'sound': soundOn.contains(s.code),
        'skin': BoardSkin.current.value.id,
        'cricket': CricketStyle.current.value,
        'theme': Tv.skin.value.id,
      };
      if (!_sending.contains(s.code)) _flush(s);
    }
  }

  /// Envoi « le dernier gagne » par écran.
  Future<void> _flush(TvScreen s) async {
    _sending.add(s.code);
    try {
      while (_pending.containsKey(s.code) && screens.contains(s)) {
        final st = _pending.remove(s.code)!;
        try {
          await GbServer.rpc('gb_tv_push',
              {'p_code': s.code, 'p_host_key': s.hostKey, 'p_state': st});
          if (error != null) {
            error = null;
            notifyListeners();
          }
        } on ApiError catch (e) {
          if (e.code == 'tv_host' || e.code == 'tv_code') {
            // Écran éteint depuis 2 jours, ou un autre téléphone l'a pris
            error = '${s.label} n\'est plus relié à ce téléphone';
            await unlink(s.code);
            return;
          }
          error =
              e.message; // hors ligne : on retente avec l'état le plus récent
          _pending.putIfAbsent(s.code, () => st);
          notifyListeners();
          await Future<void>.delayed(const Duration(seconds: 2));
        }
      }
    } finally {
      _sending.remove(s.code);
    }
  }
}
