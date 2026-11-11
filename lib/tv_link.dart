import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'audio.dart';
import 'game/x01.dart';
import 'players.dart';
import 'server.dart';

/// Côté téléphone : liaison avec un écran TV (salon sur le serveur maison).
/// Le téléphone pilote tout et envoie l'état ; la TV affiche et joue le son.
class TvLink extends ChangeNotifier {
  TvLink._();
  static final instance = TvLink._();

  static const _prefKey = 'tv_link_v1';

  String? code;
  String? _hostKey;
  String? error;

  bool get linked => code != null && _hostKey != null;

  Map<String, dynamic>? _pending;
  bool _sending = false;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw != null) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        code = j['code'] as String?;
        _hostKey = j['key'] as String?;
      }
    } catch (_) {}
    AudioService.instance.muted = linked;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    if (linked) {
      await prefs.setString(
          _prefKey, jsonEncode({'code': code, 'key': _hostKey}));
    } else {
      await prefs.remove(_prefKey);
    }
    AudioService.instance.muted = linked;
    notifyListeners();
  }

  String get _hostName {
    final ps = PlayerStore.instance.players;
    return ps.isEmpty ? 'Téléphone' : ps.first.name;
  }

  /// Relie la TV qui affiche [tvCode] (lève ApiError).
  Future<void> link(String tvCode) async {
    final r = await GbServer.rpc('gb_tv_link',
        {'p_code': tvCode.trim().toUpperCase(), 'p_name': _hostName});
    final m = Map<String, dynamic>.from(r as Map);
    code = m['code'] as String;
    _hostKey = m['host_key'] as String;
    error = null;
    await _save();
  }

  Future<void> unlink() async {
    code = null;
    _hostKey = null;
    _pending = null;
    await _save();
  }

  /// Écran d'attente (accueil, réglages).
  void pushLobby() => _send({'screen': 'lobby', 'host': _hostName});

  /// Partie en cours ([screen] = game) ou terminée ([screen] = results).
  void pushGame(X01Game game, {String screen = 'game'}) {
    final store = PlayerStore.instance;
    _send({
      'screen': screen,
      'host': _hostName,
      'game': game.toJson(),
      'colors': {
        for (final p in game.players) p.id: store.colorOf(p.id).toARGB32(),
      },
    });
  }

  /// Envoi « le dernier gagne » : pendant un envoi, seul le plus récent attend.
  void _send(Map<String, dynamic> state) {
    if (!linked) return;
    _pending = state;
    if (!_sending) _flush();
  }

  Future<void> _flush() async {
    _sending = true;
    try {
      while (_pending != null && linked) {
        final s = _pending!;
        _pending = null;
        try {
          await GbServer.rpc('gb_tv_push',
              {'p_code': code, 'p_host_key': _hostKey, 'p_state': s});
          if (error != null) {
            error = null;
            notifyListeners();
          }
        } on ApiError catch (e) {
          if (e.code == 'tv_host' || e.code == 'tv_code') {
            // TV éteinte depuis 2 jours, ou un autre téléphone a pris la main
            error = 'La TV n\'est plus reliée à ce téléphone';
            await unlink();
            return;
          }
          error =
              e.message; // hors ligne : on garde l'état pour le prochain envoi
          _pending ??= s;
          notifyListeners();
          await Future<void>.delayed(const Duration(seconds: 2));
        }
      }
    } finally {
      _sending = false;
    }
  }
}
