import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'players.dart';
import 'server.dart';

/// Sons du tour fournis (assets/sounds/turn/<id>.ogg), dans l'ordre affiché.
const kTurnSounds = {
  'fanfare': 'Fanfare',
  'klaxon': 'Klaxon',
  'laser': 'Laser',
  'cloche': 'Cloche',
  'tambour': 'Tambour',
  'guitare': 'Guitare',
  'gong': 'Gong',
  'sifflet': 'Sifflet',
  'piano': 'Piano',
  'arcade': 'Arcade',
  'sonar': 'Sonar',
  'coq': 'Coq',
};

/// Son « voix enregistrée ».
const kVoiceSound = 'voice';

/// Durée max d'un enregistrement de voix.
const kVoiceMax = Duration(seconds: 3);

/// Photo et son du tour d'un joueur (copie locale de ce qu'il y a sur le serveur).
class PlayerMedia {
  int v;
  Uint8List? photo;
  String sound;
  Uint8List? voice;
  ImageProvider? _image;

  PlayerMedia({this.v = 0, this.photo, this.sound = '', this.voice});

  ImageProvider? get image =>
      photo == null ? null : (_image ??= MemoryImage(photo!));
}

/// Médias des joueurs : cache disque + prefs, mis à jour depuis le serveur
/// (`gb_media` ne renvoie que ce qui a changé). Partagé téléphone / TV.
class MediaStore extends ChangeNotifier {
  MediaStore._();
  static final instance = MediaStore._();

  static const _prefKey = 'media_v1';

  final Map<String, PlayerMedia> _media = {};
  Directory? _dir;

  PlayerMedia? of(String id) => _media[id];
  ImageProvider? imageOf(String id) => _media[id]?.image;

  /// Son du tour du joueur : '' (aucun), id d'un son fourni ou 'voice'.
  String soundOf(String id) => _media[id]?.sound ?? '';
  Uint8List? voiceOf(String id) => _media[id]?.voice;

  Future<void> load() async {
    try {
      _dir =
          Directory('${(await getApplicationSupportDirectory()).path}/media');
      await _dir!.create(recursive: true);
    } catch (_) {
      _dir = null; // tests : mémoire seulement
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final j = jsonDecode(prefs.getString(_prefKey) ?? '{}') as Map;
      for (final e in j.entries) {
        final m = Map<String, dynamic>.from(e.value as Map);
        final id = '${e.key}';
        _media[id] = PlayerMedia(
          v: (m['v'] as num?)?.toInt() ?? 0,
          sound: '${m['sound'] ?? ''}',
          photo: m['photo'] == true ? _read('$id.jpg') : null,
          voice: m['voice'] == true ? _read('$id.m4a') : null,
        );
      }
    } catch (_) {}
    notifyListeners();
  }

  Uint8List? _read(String name) {
    try {
      final f = File('${_dir!.path}/$name');
      return f.existsSync() ? f.readAsBytesSync() : null;
    } catch (_) {
      return null;
    }
  }

  void _write(String name, Uint8List? bytes) {
    final d = _dir;
    if (d == null) return;
    try {
      final f = File('${d.path}/$name');
      if (bytes == null) {
        if (f.existsSync()) f.deleteSync();
      } else {
        f.writeAsBytesSync(bytes);
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _prefKey,
          jsonEncode({
            for (final e in _media.entries)
              e.key: {
                'v': e.value.v,
                'sound': e.value.sound,
                'photo': e.value.photo != null,
                'voice': e.value.voice != null,
              }
          }));
    } catch (_) {}
  }

  void _set(String id, PlayerMedia m) {
    _media[id] = m;
    _write('$id.jpg', m.photo);
    _write('$id.m4a', m.voice);
  }

  /// Met à jour les médias de ces joueurs (invités ignorés). Silencieux
  /// hors ligne : on garde le cache.
  Future<void> ensure(Iterable<String> ids) async {
    final nums = <int>{
      for (final id in ids)
        if (!isGuestId(id) && int.tryParse(id) != null) int.parse(id)
    }.toList();
    if (nums.isEmpty) return;
    try {
      final r = await GbServer.media(nums, {
        for (final n in nums)
          if (_media['$n'] != null) '$n': _media['$n']!.v
      });
      var changed = false;
      for (final e in r.entries) {
        final m = Map<String, dynamic>.from(e.value as Map);
        final v = (m['v'] as num?)?.toInt() ?? 0;
        if (!m.containsKey('sound')) continue; // version inchangée
        if (_media[e.key]?.v == v && v != 0) continue;
        _set(
            e.key,
            PlayerMedia(
              v: v,
              photo: _b64(m['photo']),
              sound: '${m['sound'] ?? ''}',
              voice: _b64(m['voice']),
            ));
        changed = true;
      }
      if (changed) await _save();
    } catch (_) {}
  }

  static Uint8List? _b64(dynamic s) {
    if (s is! String || s.isEmpty) return null;
    try {
      return base64Decode(s);
    } catch (_) {
      return null;
    }
  }

  /// Recadre au carré, réduit en 256 × 256 et compresse en JPEG.
  static Uint8List squareJpeg(Uint8List source, {int size = 256}) {
    final src = img.decodeImage(source);
    if (src == null) throw const ApiError('photo');
    final oriented = img.bakeOrientation(src);
    final side =
        oriented.width < oriented.height ? oriented.width : oriented.height;
    final crop = img.copyCrop(oriented,
        x: (oriented.width - side) ~/ 2,
        y: (oriented.height - side) ~/ 2,
        width: side,
        height: side);
    final small = img.copyResize(crop,
        width: size, height: size, interpolation: img.Interpolation.average);
    for (var q = 82; q >= 40; q -= 14) {
      final out = Uint8List.fromList(img.encodeJpg(small, quality: q));
      if (out.length < 55000) return out;
    }
    return Uint8List.fromList(img.encodeJpg(small, quality: 35));
  }

  /// Nouvelle photo du compte (null = retirer). Lève ApiError.
  Future<void> setPhoto(PlayerProfile p, Uint8List? jpeg) async {
    final v = await GbServer.setPhoto(
        p.token, jpeg == null ? null : base64Encode(jpeg));
    final old = _media[p.key];
    _set(
        p.key,
        PlayerMedia(
            v: v, photo: jpeg, sound: old?.sound ?? '', voice: old?.voice));
    await _save();
  }

  /// Nouveau son du tour (voix = nouvel enregistrement, sinon on garde
  /// l'ancien). Lève ApiError.
  Future<void> setSound(PlayerProfile p, String sound,
      {Uint8List? voice}) async {
    final v = await GbServer.setSound(p.token, sound,
        voice: voice == null ? null : base64Encode(voice));
    final old = _media[p.key];
    _set(
        p.key,
        PlayerMedia(
            v: v, photo: old?.photo, sound: sound, voice: voice ?? old?.voice));
    await _save();
  }

  /// Tests : vide le cache.
  @visibleForTesting
  void debugClear() => _media.clear();
}
