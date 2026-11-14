import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'voice.dart';

enum Sfx { hit, double, triple, bull, bust, next, ton, crowd, win }

/// Effets sonores, musique de menu et annonceur (voix enregistrée de
/// `assets/voice/` ; synthèse vocale du téléphone pour les pseudos).
/// Tout est désactivable dans les réglages ; aucune erreur audio ne doit
/// gêner la partie, donc tout est protégé.
class AudioService extends ChangeNotifier {
  AudioService._();
  static final instance = AudioService._();

  static const _prefKey = 'audio_v1';

  bool voice = true;

  /// L'annonceur dit chaque fléchette (« triple 20 », « double 16 »…).
  bool dartCalls = true;

  /// Chambrage : petite phrase moqueuse sur un tour raté (moins de 20 en
  /// 01, aucune marque en Cricket) ou un bust.
  bool teasing = true;

  /// Écran TV (posé par main.dart avant init) : bruitages en lecteur
  /// classique, plus fiable que le mode faible latence sur ces appareils.
  bool tvDevice = false;

  /// Coupé quand une TV est reliée (le son passe sur la TV).
  bool _muted = false;
  bool get muted => _muted;
  set muted(bool v) {
    if (_muted == v) return;
    _muted = v;
    if (v) {
      _music?.stop().catchError((_) {});
      _stopVoice();
    } else if (_musicWanted) {
      startMusic();
    }
    notifyListeners();
  }

  bool effects = true;
  bool music = true;
  double musicVolume = 0.35;

  // Volumes relatifs (le buzzer est fort par nature)
  static const _volumes = {
    Sfx.hit: 0.8,
    Sfx.double: 0.9,
    Sfx.triple: 0.9,
    Sfx.bull: 0.9,
    Sfx.bust: 0.55,
    Sfx.next: 0.6,
    Sfx.ton: 0.8,
    Sfx.crowd: 0.9,
    Sfx.win: 0.9,
  };

  final _pool = <AudioPlayer>[];
  int _poolIndex = 0;
  AudioPlayer? _music;
  AudioPlayer? _cue; // son du tour du joueur
  int _cueId = 0;
  FlutterTts? _tts;
  AudioPlayer? _speaker; // voix enregistrée
  VoiceBank? _bank;
  int _sayId = 0;

  /// Pseudos des joueurs : lus par la synthèse vocale (pas d'enregistrement).
  Iterable<String> names = const [];

  /// Prononciation choisie pour un pseudo (clé : pseudo en minuscules),
  /// pref `pron_v1` ; envoyée aux écrans TV.
  final Map<String, String> pronunciations = {};
  static const _prefPron = 'pron_v1';

  /// Ce que la synthèse vocale lit pour un pseudo : la prononciation
  /// choisie, sinon le pseudo avec une seule majuscule (« CED » ou « ced »
  /// → « Ced », moins souvent épelé lettre par lettre).
  String spokenName(String name) {
    final p = pronunciations[name.trim().toLowerCase()];
    if (p != null && p.trim().isNotEmpty) return p.trim();
    return name.replaceAllMapped(RegExp(r'[A-Za-zÀ-ÿ]+'), (m) {
      final w = m[0]!;
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    });
  }

  Future<void> setPronunciation(String name, String spoken) async {
    final k = name.trim().toLowerCase();
    if (spoken.trim().isEmpty) {
      pronunciations.remove(k);
    } else {
      pronunciations[k] = spoken.trim();
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefPron, jsonEncode(pronunciations));
    } catch (_) {}
  }

  /// Fait lire un texte par la synthèse vocale seule (essai d'une
  /// prononciation).
  void speakTts(String text) {
    final tts = _tts;
    if (tts == null || _muted) return;
    tts.stop().then((_) => tts.speak(text)).catchError((_) => 0);
  }

  bool _musicWanted = false;

  /// Musique des menus : les morceaux s'enchaînent, dans un ordre tiré au
  /// hasard à chaque lancement.
  static const kMenuTracks = ['menu1.ogg', 'menu2.ogg', 'menu3.ogg'];
  final _order = [...kMenuTracks]..shuffle(Random());
  int _track = 0;

  /// Morceau des menus en cours (ou le prochain) : envoyé aux écrans pour
  /// qu'ils jouent le même.
  String get menuTrack => _order[_track % _order.length];

  /// +1 à chaque morceau lancé ici : les écrans le relancent avec nous.
  final musicStarts = ValueNotifier<int>(0);

  String? _followed;

  /// Écran TV : joue le morceau du téléphone [track] (et le reprend au début
  /// quand le téléphone le relance : [n] change).
  void followMusic(String track, int n) {
    final key = '$track#$n';
    if (key == _followed) return;
    final i = _order.indexOf(track);
    if (i < 0) return;
    final first = _followed == null;
    _followed = key;
    final same = i == _track % _order.length;
    _track = i;
    final m = _music;
    if (m == null || !_musicWanted || _muted || !music) return;
    // 1re fois : le morceau déjà en cours continue s'il est le bon
    if (first && same && m.state == PlayerState.playing) return;
    _playTrack();
  }

  /// Lit les réglages (rapide), puis prépare les lecteurs et la voix en
  /// arrière-plan : sur une Android TV, la synthèse vocale met plusieurs
  /// secondes à démarrer et ne doit pas retarder le premier écran.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getStringList(_prefKey);
      if (v != null && v.length >= 4) {
        voice = v[0] == '1';
        effects = v[1] == '1';
        music = v[2] == '1';
        musicVolume = double.tryParse(v[3]) ?? musicVolume;
        if (v.length >= 5) dartCalls = v[4] == '1';
        if (v.length >= 6) teasing = v[5] == '1';
      }
      final pr = prefs.getString(_prefPron);
      if (pr != null) {
        pronunciations
          ..clear()
          ..addAll((jsonDecode(pr) as Map).cast<String, String>());
      }
    } catch (_) {}
    unawaited(_initEngines());
  }

  Future<void> _initEngines() async {
    try {
      // Les effets se mélangent à la musique au lieu de la couper
      await AudioPlayer.global.setAudioContext(
          AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers)
              .build());
      final m = AudioPlayer();
      await m.setReleaseMode(ReleaseMode.stop);
      // Morceau fini : le suivant de la liste
      m.onPlayerComplete.listen((_) {
        _track++;
        if (_musicWanted && !_muted && music) _playTrack();
      });
      _music = m;
      // La musique demandée pendant le démarrage commence maintenant
      if (_musicWanted) startMusic();
      for (var i = 0; i < 4; i++) {
        final p = AudioPlayer();
        // Mode « faible latence » (SoundPool) : parfois muet sur les TV
        // Android (son rechargé à chaque fois) → lecteur classique sur TV
        if (!tvDevice) await p.setPlayerMode(PlayerMode.lowLatency);
        await p.setReleaseMode(ReleaseMode.stop);
        _pool.add(p);
      }
      final c = AudioPlayer();
      await c.setReleaseMode(ReleaseMode.stop);
      _cue = c;
      final sp = AudioPlayer();
      await sp.setReleaseMode(ReleaseMode.stop);
      _speaker = sp;
    } catch (_) {}

    try {
      final index =
          jsonDecode(await rootBundle.loadString('assets/voice/index.json'))
              as Map;
      _bank = VoiceBank(index.cast<String, String>());
    } catch (_) {}

    try {
      final tts = FlutterTts();
      await tts.setLanguage('fr-FR');
      await tts.setSpeechRate(0.5);
      await tts.setPitch(0.95);
      await tts.awaitSpeakCompletion(true);
      _tts = tts;
    } catch (_) {}
  }

  Future<void> _save() async {
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefKey, [
        voice ? '1' : '0',
        effects ? '1' : '0',
        music ? '1' : '0',
        musicVolume.toStringAsFixed(2),
        dartCalls ? '1' : '0',
        teasing ? '1' : '0',
      ]);
    } catch (_) {}
  }

  void setDartCalls(bool v) {
    dartCalls = v;
    _save();
  }

  void setTeasing(bool v) {
    teasing = v;
    _save();
  }

  void setVoice(bool v) {
    voice = v;
    if (!v) _stopVoice();
    _save();
  }

  void setEffects(bool v) {
    effects = v;
    _save();
  }

  void setMusic(bool v) {
    music = v;
    _save();
    if (v && _musicWanted) {
      startMusic();
    } else if (!v) {
      _music?.stop().catchError((_) {});
    }
  }

  void setMusicVolume(double v) {
    musicVolume = v;
    _music?.setVolume(v).catchError((_) {});
    _save();
  }

  /// Effet sonore (plusieurs peuvent se superposer).
  void play(Sfx s) {
    if (_muted || !effects || _pool.isEmpty) return;
    final p = _pool[_poolIndex];
    _poolIndex = (_poolIndex + 1) % _pool.length;
    () async {
      try {
        await p.stop();
        await p.play(AssetSource('sounds/${s.name}.ogg'),
            volume: _volumes[s] ?? 0.8);
      } catch (_) {}
    }();
  }

  /// Son du tour d'un joueur (son fourni ou voix enregistrée), puis
  /// l'annonce une fois le son fini. Sans son perso : « suivant » + annonce.
  void turnCue(String text,
      {String sound = '', Uint8List? voice, int ms = 250, bool next = true}) {
    final c = _cue;
    final custom = sound.isNotEmpty && (sound != 'voice' || voice != null);
    if (_muted || !effects || c == null || !custom) {
      if (next) play(Sfx.next);
      sayLater(text, ms);
      return;
    }
    final id = ++_cueId;
    () async {
      try {
        await c.stop();
        final done = c.onPlayerComplete.first;
        await c.play(
            sound == 'voice'
                ? BytesSource(voice!, mimeType: 'audio/mp4')
                : AssetSource('sounds/turn/$sound.ogg'),
            volume: 1.0);
        await done.timeout(const Duration(seconds: 4));
      } catch (_) {}
      if (id == _cueId) say(text);
    }();
  }

  /// Écoute d'un son du tour (réglages du joueur).
  void preview(String sound, {Uint8List? voice}) {
    final c = _cue;
    if (c == null || sound.isEmpty) return;
    () async {
      try {
        await c.stop();
        await c.play(
            sound == 'voice'
                ? BytesSource(voice!, mimeType: 'audio/mp4')
                : AssetSource('sounds/turn/$sound.ogg'),
            volume: 1.0);
      } catch (_) {}
    }();
  }

  void _stopVoice() {
    _sayId++;
    _speaker?.stop().catchError((_) {});
    _tts?.stop().catchError((_) => 0);
  }

  /// Annonce vocale (coupe l'annonce précédente) : voix enregistrée pour
  /// tout ce qu'elle connaît, synthèse vocale pour le reste (pseudos).
  /// Dernières annonces (tests).
  @visibleForTesting
  final said = <String>[];

  void say(String text) {
    if (_muted || !voice) return;
    said.add(text);
    if (said.length > 50) said.removeAt(0);
    final tts = _tts;
    final sp = _speaker;
    final parts = sp == null ? null : _bank?.plan(text, names);
    final id = ++_sayId;
    () async {
      try {
        await sp?.stop();
        await tts?.stop();
      } catch (_) {}
      for (final p in parts ?? [VoicePart.tts(text)]) {
        if (id != _sayId || _muted || !voice) return;
        try {
          if (p.clip != null) {
            final done = sp!.onPlayerComplete.first;
            await sp.play(AssetSource('voice/${p.clip}'), volume: 1.0);
            await done.timeout(const Duration(seconds: 6));
          } else if (tts != null) {
            await tts
                .speak(_isName(p.text!) ? spokenName(p.text!) : p.text!)
                .timeout(const Duration(seconds: 8));
          }
        } catch (_) {}
      }
    }();
  }

  bool _isName(String t) =>
      names.any((n) => n.trim().toLowerCase() == t.trim().toLowerCase());

  /// Annonce après un court délai (laisse le bruitage se jouer).
  void sayLater(String text, [int ms = 350]) =>
      Timer(Duration(milliseconds: ms), () => say(text));

  void startMusic() {
    _musicWanted = true;
    final m = _music;
    if (_muted || !music || m == null) return;
    if (m.state == PlayerState.playing) return;
    if (m.state == PlayerState.paused) {
      m.resume().catchError((_) {});
      return;
    }
    _playTrack();
  }

  void _playTrack() {
    final m = _music;
    if (m == null) return;
    final name = _order[_track % _order.length];
    musicStarts.value++;
    () async {
      try {
        // position 0 obligatoire : sur Android, relancer le morceau déjà
        // chargé ne le reprend pas au début (même fichier = ignoré)
        await m.play(AssetSource('music/$name'),
            volume: musicVolume, position: Duration.zero);
      } catch (_) {}
    }();
  }

  /// Coupe la musique (début de partie) : au retour au menu, on passe au
  /// morceau suivant.
  void stopMusic() {
    if (_musicWanted && _music?.state == PlayerState.playing) _track++;
    _musicWanted = false;
    _music?.stop().catchError((_) {});
  }
}
