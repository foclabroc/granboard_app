import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Serveur maison (même API que Pixel Trade : PostgREST derrière Caddy).
const kApiUrl = 'https://api.foclabroc.duckdns.org';
const kApiKey = 'sb_publishable_M1Rdee-lSEzCfq81zjYq5Q_NgJ0a35z';

class ApiError implements Exception {
  final String code;
  final bool offline;
  final Map<String, dynamic> data;
  const ApiError(this.code, {this.offline = false, this.data = const {}});

  /// Message à afficher.
  String get message {
    switch (code) {
      case 'taken':
        return 'Ce pseudo est déjà pris';
      case 'pseudo':
        return 'Le pseudo doit faire de 2 à 16 caractères';
      case 'pin_format':
        return 'Le code doit faire 4 chiffres';
      case 'unknown':
        return 'Pseudo inconnu';
      case 'pin':
        final left = data['left'];
        return left is num && left > 0
            ? 'Code faux ($left essai${left > 1 ? 's' : ''} avant blocage)'
            : 'Code faux';
      case 'locked':
        return 'Trop d\'essais : réessaie dans ${data['minutes'] ?? 15} min';
      case 'session':
        return 'Session expirée : reconnecte ce joueur';
      case 'values':
        return 'Partie refusée par le serveur';
      case 'photo':
        return 'Photo refusée (trop lourde ?)';
      case 'on_offline':
        return 'Ce joueur n\'est plus en ligne';
      case 'on_busy':
        return 'Ce joueur est déjà en partie ou a un défi en cours';
      case 'on_gone':
        return 'Ce défi n\'existe plus';
      case 'on_room':
        return 'Cette partie n\'existe plus';
      case 'voice':
      case 'sound':
        return 'Son refusé (enregistrement trop long ?)';
    }
    return offline ? 'Pas de connexion au serveur' : 'Erreur serveur ($code)';
  }

  @override
  String toString() => 'ApiError($code)';
}

class GbServer {
  /// Remplace l'appel réseau (tests).
  static Future<dynamic> Function(String fn, Map<String, dynamic> body)?
      debugRpc;

  static final _http = http.Client();

  static Future<dynamic> rpc(String fn, Map<String, dynamic> body) async {
    final fake = debugRpc;
    final r = fake != null ? await fake(fn, body) : await _post(fn, body);
    // Erreurs renvoyées (et non levées) par le serveur : {"error": …}
    if (r is Map && r['error'] is String) {
      throw ApiError(r['error'] as String, data: Map<String, dynamic>.from(r));
    }
    return r;
  }

  static Future<dynamic> _post(String fn, Map<String, dynamic> body) async {
    http.Response res;
    try {
      res = await _http
          .post(
            Uri.parse('$kApiUrl/rest/v1/rpc/$fn'),
            headers: {'apikey': kApiKey, 'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const ApiError('offline', offline: true);
    }
    if (res.statusCode == 502 ||
        res.statusCode == 503 ||
        res.statusCode == 504) {
      throw const ApiError('offline', offline: true);
    }
    final txt = utf8.decode(res.bodyBytes);
    if (res.statusCode >= 300) {
      var code = 'http ${res.statusCode}';
      try {
        final j = jsonDecode(txt);
        if (j is Map && j['message'] is String) code = j['message'] as String;
      } catch (_) {}
      throw ApiError(code);
    }
    return txt.isEmpty ? null : jsonDecode(txt);
  }

  static Map<String, dynamic> _map(dynamic r) =>
      r is Map ? Map<String, dynamic>.from(r) : <String, dynamic>{};

  static List<Map<String, dynamic>> _list(dynamic r) => r is List
      ? [
          for (final x in r)
            if (x is Map) Map<String, dynamic>.from(x)
        ]
      : [];

  /// {id, pseudo, color, token}
  static Future<Map<String, dynamic>> register(
          String pseudo, String pin, int color) async =>
      _map(await rpc(
          'gb_register', {'p_pseudo': pseudo, 'p_pin': pin, 'p_color': color}));

  /// {id, pseudo, color, token}
  static Future<Map<String, dynamic>> login(String pseudo, String pin) async =>
      _map(await rpc('gb_login', {'p_pseudo': pseudo, 'p_pin': pin}));

  /// Comptes encore valides parmi les jetons donnés.
  static Future<List<Map<String, dynamic>>> check(List<String> tokens) async =>
      _list(await rpc('gb_check', {'p_tokens': tokens}));

  static Future<void> logout(String token) =>
      rpc('gb_logout', {'p_token': token});

  static Future<void> setColor(String token, int color) =>
      rpc('gb_set_color', {'p_token': token, 'p_color': color});

  /// Photo de profil (JPEG en base64, null = retirer) → nouvelle version.
  static Future<int> setPhoto(String token, String? photo) async =>
      ((await rpc('gb_set_photo', {'p_token': token, 'p_photo': photo})) as num)
          .toInt();

  /// Son du tour ('' aucun, id d'un son fourni, 'voice') → nouvelle version.
  static Future<int> setSound(String token, String sound,
          {String? voice}) async =>
      ((await rpc('gb_set_sound',
              {'p_token': token, 'p_sound': sound, 'p_voice': voice})) as num)
          .toInt();

  /// Médias des joueurs dont la version diffère de `known`.
  static Future<Map<String, dynamic>> media(
          List<int> ids, Map<String, int> known) async =>
      _map(await rpc('gb_media', {'p_ids': ids, 'p_known': known}));

  static Future<void> setPin(String token, String oldPin, String newPin) =>
      rpc('gb_set_pin', {'p_token': token, 'p_old': oldPin, 'p_new': newPin});

  /// Identifiant de la partie enregistrée.
  static Future<int> submit(Map<String, dynamic> game) async {
    final r = await rpc('gb_submit', {'p_game': game});
    return r is num ? r.toInt() : 0;
  }

  static Future<Map<String, dynamic>> profile(int id) async =>
      _map(await rpc('gb_profile', {'p_id': id}));

  /// [kind] : rating, wins, avg, n180, checkout, high
  static Future<List<Map<String, dynamic>>> top(String kind,
          {int limit = 50}) async =>
      _list(await rpc('gb_top', {'p_kind': kind, 'p_limit': limit}));
}
