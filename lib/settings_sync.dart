import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import 'audio.dart';
import 'board_lights.dart';
import 'players.dart';
import 'server.dart';
import 'tv_link.dart';
import 'ui/cricket_view.dart' show CricketStyle;
import 'ui/dartboard.dart' show BoardSkin;
import 'ui/ring_anim.dart';
import 'ui/game_intro.dart';
import 'game/personas.dart';
import 'ui/game_page.dart' show AutoNext;
import 'ui/theme.dart';
import 'ui/wallpaper.dart';

/// Réglages du téléphone gardés sur le compte du profil principal (thème,
/// cible, sons, prononciations, favoris et derniers réglages des parties,
/// option AUTO, lumières, fond d'écran et ses photos) : `gb_settings_set` /
/// `gb_settings_get`.
///
/// Un téléphone est « lié » au compte après une sauvegarde, une
/// restauration, ou quand le compte n'avait encore rien : à partir de là
/// ses réglages sont envoyés tout seuls ([save], quand l'appli passe en
/// arrière-plan). Un téléphone pas encore lié n'écrase jamais la sauvegarde
/// du compte : l'accueil propose d'abord de la reprendre ([check]).
class SettingsSync extends ChangeNotifier {
  SettingsSync._();
  static final instance = SettingsSync._();

  /// Préférences sauvegardées (pas les comptes, la cible Bluetooth, les
  /// écrans reliés ni les parties en cours : propres à chaque téléphone).
  static const keys = [
    'app_skin',
    'board_skin',
    'ring_anim_v1',
    'game_intro_v1',
    'personas_v1',
    'cricket_layout',
    'audio_v1',
    'pron_v1',
    'setup_favs_v1',
    'x01_setup_v1',
    'ranking_mine_v1',
    'auto_next_v1',
    'board_lights_v1',
    'board_numbers_v1',
    'board_idle_v1',
    'board_numcolor_v1',
    'wallpaper_v1',
    'wallpaper_v1_files',
  ];

  static const _pref = 'settings_sync_v1';

  int? _id; // compte auquel ce téléphone est lié
  int v = 0;
  String _hash = '';
  List<String> _walls = const [];

  /// Dernière sauvegarde connue du compte.
  DateTime? savedAt;

  bool _busy = false;
  bool get busy => _busy;

  PlayerProfile? get _owner {
    final o = PlayerStore.instance.owner;
    return o == null || o.expired ? null : o;
  }

  bool get hasAccount => _owner != null;
  bool get linked => _owner != null && _id == _owner!.id;

  Future<void> load() async {
    _id = null;
    v = 0;
    _hash = '';
    _walls = const [];
    savedAt = null;
    try {
      final p = await SharedPreferences.getInstance();
      final s = p.getString(_pref);
      if (s == null) return;
      final m = jsonDecode(s) as Map<String, dynamic>;
      _id = m['id'] as int?;
      v = m['v'] as int? ?? 0;
      _hash = m['hash'] as String? ?? '';
      _walls = (m['walls'] as List? ?? const []).cast<String>();
      savedAt = DateTime.tryParse(m['at'] as String? ?? '');
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
          _pref,
          jsonEncode({
            'id': _id,
            'v': v,
            'hash': _hash,
            'walls': _walls,
            'at': savedAt?.toIso8601String(),
          }));
    } catch (_) {}
    notifyListeners();
  }

  /// Les réglages du téléphone (clé → valeur telle qu'elle est rangée).
  static Future<Map<String, dynamic>> snapshot() async {
    final p = await SharedPreferences.getInstance();
    return {
      for (final k in keys)
        if (p.get(k) != null) k: p.get(k),
    };
  }

  /// Photos du fond d'écran, réduites pour l'envoi (nom → JPEG base64).
  static Future<Map<String, String>> _wallFiles(List<String> names) async {
    final dir = await Wallpaper.instance.folder();
    final out = <String, String>{};
    if (dir == null) return out;
    for (final n in names.take(6)) {
      try {
        final bytes = await File('${dir.path}/$n').readAsBytes();
        final small = await compute(shrinkJpeg, bytes);
        if (small != null) out[n] = base64Encode(small);
      } catch (_) {}
    }
    return out;
  }

  /// JPEG de 1600 px au plus et de moins de 500 Ko (null si illisible).
  static Uint8List? shrinkJpeg(Uint8List source) {
    final src = img.decodeImage(source);
    if (src == null) return null;
    var im = img.bakeOrientation(src);
    final big = im.width > im.height ? im.width : im.height;
    if (big > 1600) {
      im = img.copyResize(im,
          width: im.width >= im.height ? 1600 : null,
          height: im.height > im.width ? 1600 : null,
          interpolation: img.Interpolation.average);
    }
    for (var q = 80; q >= 35; q -= 15) {
      final out = Uint8List.fromList(img.encodeJpg(im, quality: q));
      if (out.length < 500000) return out;
    }
    return null;
  }

  /// Envoie les réglages s'ils ont changé. Sans [force], seulement si ce
  /// téléphone est lié au compte, et les erreurs sont avalées.
  Future<bool> save({bool force = false}) async {
    final o = _owner;
    if (o == null || _busy) return false;
    if (!linked && !force) return false;
    _busy = true;
    notifyListeners();
    try {
      final data = await snapshot();
      final hash = jsonEncode(data);
      final names = [
        ...((data['wallpaper_v1_files'] as List?) ?? const []).cast<String>()
      ];
      final wallsChanged = !listEquals(names, _walls);
      if (!force && hash == _hash && !wallsChanged) return true;
      final walls = wallsChanged || force ? await _wallFiles(names) : null;
      final r = await GbServer.rpc('gb_settings_set',
          {'p_token': o.token, 'p_data': data, 'p_walls': walls});
      _id = o.id;
      v = (r as num).toInt();
      _hash = hash;
      if (walls != null) _walls = names;
      savedAt = DateTime.now();
      await _persist();
      return true;
    } catch (_) {
      if (force) rethrow;
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// À l'accueil : la sauvegarde du compte si ce téléphone n'y est pas
  /// encore lié et qu'il y en a une (à proposer : [apply] ou [decline]) ;
  /// sinon null (et le téléphone est lié si le compte n'avait rien).
  Future<Map<String, dynamic>?> check() async {
    final o = _owner;
    if (o == null || linked || _busy) return null;
    try {
      final r = Map<String, dynamic>.from(await GbServer.rpc(
          'gb_settings_get', {'p_token': o.token, 'p_known': -1}) as Map);
      if (((r['v'] as num?) ?? 0) > 0 && r['data'] is Map) return r;
      _id = o.id;
      v = 0;
      _hash = '';
      _walls = const [];
      await _persist();
    } catch (_) {}
    return null;
  }

  /// Sauvegarde du compte refusée : ce téléphone garde ses réglages (ils
  /// la remplaceront).
  Future<void> decline() async {
    final o = _owner;
    if (o == null) return;
    _id = o.id;
    _hash = '';
    _walls = const [];
    await _persist();
  }

  /// Reprend la sauvegarde du compte. Faux s'il n'y en a pas.
  Future<bool> restore() async {
    final o = _owner;
    if (o == null) return false;
    final r = Map<String, dynamic>.from(await GbServer.rpc(
        'gb_settings_get', {'p_token': o.token, 'p_known': -1}) as Map);
    if (((r['v'] as num?) ?? 0) == 0 || r['data'] is! Map) return false;
    await apply(r);
    return true;
  }

  /// Applique une réponse de `gb_settings_get` : photos, préférences, puis
  /// tout est relu (thème, cible, sons…).
  Future<void> apply(Map<String, dynamic> r) async {
    final o = _owner;
    if (o == null) return;
    _busy = true;
    notifyListeners();
    try {
      final data = Map<String, dynamic>.from(r['data'] as Map);
      final walls = Map<String, dynamic>.from(r['walls'] as Map? ?? const {});
      final dir = await Wallpaper.instance.folder();
      if (dir != null) {
        for (final e in walls.entries) {
          try {
            if (!RegExp(r'^[A-Za-z0-9_.-]{1,40}$').hasMatch(e.key)) continue;
            await File('${dir.path}/${e.key}')
                .writeAsBytes(base64Decode(e.value as String));
          } catch (_) {}
        }
      }
      final p = await SharedPreferences.getInstance();
      for (final k in keys) {
        final val = data[k];
        if (val is String) {
          await p.setString(k, val);
        } else if (val is bool) {
          await p.setBool(k, val);
        } else if (val is int) {
          await p.setInt(k, val);
        } else if (val is double) {
          await p.setDouble(k, val);
        } else if (val is List) {
          await p.setStringList(k, val.map((x) => '$x').toList());
        } else {
          await p.remove(k);
        }
      }
      await Wallpaper.instance.load();
      await Tv.load();
      await BoardSkin.load();
      await RingAnim.load();
      await GameIntro.load();
      await PersonaRecords.instance.load();
      await CricketStyle.load();
      await AudioService.instance.reloadSettings();
      await BoardLights.instance.load();
      await AutoNext.load();
      TvLink.instance.refresh();
      _id = o.id;
      v = (r['v'] as num).toInt();
      _hash = jsonEncode(await snapshot());
      _walls = [
        ...((data['wallpaper_v1_files'] as List?) ?? const []).cast<String>()
      ];
      savedAt = DateTime.tryParse('${r['at']}')?.toLocal() ?? DateTime.now();
      await _persist();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
