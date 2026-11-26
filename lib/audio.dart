import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'voice.dart';

enum Sfx { hit, double, triple, bull, bust, next, ton, crowd, win, intro }

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

  /// L'annonceur dit le joueur dont c'est le tour (« Ana, à toi »). Coupé :
  /// seulement le son du joueur et ce qu'il lui reste.
  bool turnNames = true;

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
      _loop?.stop().catchError((_) {});
      _stopVoice();
    } else {
      if (_musicWanted) startMusic();
      _playLoop();
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
    Sfx.intro: 0.85,
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
  Iterable<String> _names = const [];

  /// Pseudos de la partie : lus par la synthèse vocale. Enregistrés une fois
  /// dans un fichier (prepareNames) puis rejoués comme la voix enregistrée :
  /// plus d'attente de la synthèse vocale (lente sur Android TV).
  Iterable<String> get names => _names;
  set names(Iterable<String> v) {
    _names = v;
    prepareNames(v);
  }

  // ─── Préchargement (écran de démarrage) ───

  /// Copie des annonces enregistrées hors de l'APK (lues comme fichiers) ;
  /// null = lues depuis l'APK (recopiées à chaque 1re lecture par le
  /// lecteur audio).
  String? _voiceDir;

  /// Pseudo dit (prononciation comprise) → fichier .wav enregistré.
  final _nameFiles = <String, String>{};
  bool _synthBusy = false;
  Future<void> _synthQueue = Future.value();

  static int _fnv(String s) {
    var h = 0x811c9dc5;
    for (final c in utf8.encode(s)) {
      h = ((h ^ c) * 0x01000193) & 0xffffffff;
    }
    return h;
  }

  /// Annonces enregistrées copiées une fois dans les fichiers de l'appli
  /// (refaites seulement quand elles changent : empreinte de l'index).
  /// [progress] de 0 à 1.
  Future<void> prepareVoiceFiles(void Function(double) progress) async {
    try {
      final index = await rootBundle.loadString('assets/voice/index.json');
      final files =
          (jsonDecode(index) as Map).values.map((v) => '$v').toSet().toList();
      final base = await getApplicationSupportDirectory();
      final dir = Directory('${base.path}/voice');
      final mark = File('${dir.path}/.ok');
      final want = '${_fnv(index)}:${files.length}';
      if (mark.existsSync() && mark.readAsStringSync() == want) {
        _voiceDir = dir.path;
        progress(1);
        return;
      }
      dir.createSync(recursive: true);
      var done = 0;
      const batch = 24;
      for (var i = 0; i < files.length; i += batch) {
        await Future.wait([
          for (final f in files.skip(i).take(batch))
            () async {
              final data = await rootBundle.load('assets/voice/$f');
              await File('${dir.path}/$f').writeAsBytes(
                  data.buffer
                      .asUint8List(data.offsetInBytes, data.lengthInBytes),
                  flush: false);
            }(),
        ]);
        done = min(files.length, i + batch);
        progress(done / files.length);
      }
      mark.writeAsStringSync(want);
      _voiceDir = dir.path;
    } catch (_) {
      // lues depuis l'APK comme avant
    }
  }

  /// Bruitages, sons du tour : copiés d'avance par le lecteur audio (sinon
  /// à leur 1re lecture, pendant la partie).
  Future<void> prepareSounds() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final list = [
        for (final a in manifest.listAssets())
          if (a.startsWith('assets/sounds/')) a.substring('assets/'.length)
      ];
      await AudioCache.instance.loadAll(list);
    } catch (_) {}
  }

  /// Enregistre chaque pseudo une fois (fichier gardé d'un lancement à
  /// l'autre) ; les suivants attendent leur tour.
  void prepareNames(Iterable<String> names) {
    if (_tts == null) return;
    final todo =
        names.map(spokenName).where((n) => n.trim().isNotEmpty).toList();
    _synthQueue = _synthQueue.then((_) async {
      for (final n in todo) {
        if (_nameFiles.containsKey(n)) continue;
        try {
          final base = await getApplicationSupportDirectory();
          final dir = Directory('${base.path}/names')
            ..createSync(recursive: true);
          final f = File('${dir.path}/${_fnv(n).toRadixString(16)}.wav');
          if (!f.existsSync() || f.lengthSync() < 2000) {
            final tts = _tts!;
            _synthBusy = true;
            await tts.awaitSynthCompletion(true);
            // fichier provisoire renommé seulement si l'enregistrement va
            // au bout (jamais de pseudo coupé gardé)
            final tmp = File('${f.path}.tmp');
            if (tmp.existsSync()) tmp.deleteSync();
            await tts
                .synthesizeToFile(n, tmp.path, true)
                .timeout(const Duration(seconds: 6));
            if (tmp.existsSync() && tmp.lengthSync() >= 2000) {
              tmp.renameSync(f.path);
            }
          }
          if (f.existsSync() && f.lengthSync() >= 2000) _nameFiles[n] = f.path;
        } catch (_) {
        } finally {
          _synthBusy = false;
        }
      }
    });
  }

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
  static const kMenuTracks = [
    'menu1.ogg',
    'menu2.ogg',
    'menu3.ogg',
    'menu4.ogg',
    'menu5.ogg',
  ];
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
    await _readSettings();
    unawaited(_initEngines());
  }

  /// Réglages relus (sauvegarde du compte reprise) : la musique suit.
  Future<void> reloadSettings() async {
    await _readSettings();
    final m = _music;
    if (music && _musicWanted) {
      m?.setVolume(musicVolume).catchError((_) {});
      if (m?.state != PlayerState.playing) startMusic();
    } else if (!music) {
      m?.stop().catchError((_) {});
    }
  }

  Future<void> _readSettings() async {
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
        if (v.length >= 7) turnNames = v[6] == '1';
      }
      final pr = prefs.getString(_prefPron);
      if (pr != null) {
        pronunciations
          ..clear()
          ..addAll((jsonDecode(pr) as Map).cast<String, String>());
      }
    } catch (_) {}
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
      // pseudos déjà connus (partie lancée pendant le démarrage)
      prepareNames(_names);
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
        turnNames ? '1' : '0',
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

  void setTurnNames(bool v) {
    turnNames = v;
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
    if (v && _musicWanted) startMusic();
    if (v) _playLoop();
    if (!v) {
      _music?.stop().catchError((_) {});
      _loop?.stop().catchError((_) {});
    }
  }

  void setMusicVolume(double v) {
    musicVolume = v;
    _music?.setVolume(v).catchError((_) {});
    _loop?.setVolume((v * _loopVolume).clamp(0.0, 1.0)).catchError((_) {});
    _save();
  }

  /// Effet sonore (plusieurs peuvent se superposer).
  void play(Sfx s) =>
      playFile('sounds/${s.name}.ogg', volume: _volumes[s] ?? 0.8);

  /// Bruitages joués (tests).
  final playedFiles = <String>[];

  /// Bruitage d'un jeu ([asset] relatif à `assets/`, ex.
  /// `sounds/zombies/zb_pain.ogg`), même file de lecteurs que [play].
  void playFile(String asset, {double volume = 0.8}) {
    if (_muted || _background || !effects) return;
    playedFiles.add(asset);
    if (playedFiles.length > 50) playedFiles.removeAt(0);
    if (_pool.isEmpty) return;
    final p = _pool[_poolIndex];
    _poolIndex = (_poolIndex + 1) % _pool.length;
    () async {
      try {
        await p.stop();
        await p.play(AssetSource(asset), volume: volume);
      } catch (_) {}
    }();
  }

  /// Ambiance en boucle d'un jeu (Zombies) : suit le réglage de la musique
  /// et son volume, coupée avec le son ou en arrière-plan.
  AudioPlayer? _loop;
  String? _loopAsset;
  String? get loopAsset => _loopAsset;
  double _loopVolume = 1;

  void startLoop(String asset, {double volume = 1}) {
    _loopAsset = asset;
    _loopVolume = volume;
    _playLoop();
  }

  void stopLoop() {
    _loopAsset = null;
    _loop?.stop().catchError((_) {});
  }

  /// Faux en test (pas de lecteur audio).
  static bool loopPlayer = true;

  void _playLoop() {
    final a = _loopAsset;
    if (!loopPlayer || a == null || _muted || _background || !music) return;
    () async {
      try {
        final p = _loop ??= AudioPlayer();
        await p.setReleaseMode(ReleaseMode.loop);
        await p.play(AssetSource(a),
            volume: (musicVolume * _loopVolume).clamp(0.0, 1.0),
            position: Duration.zero);
      } catch (_) {}
    }();
  }

  /// Son du tour d'un joueur (son fourni ou voix enregistrée), puis
  /// l'annonce une fois le son fini. Sans son perso : « suivant » + annonce.
  ///
  /// Attend d'abord que l'annonce en cours soit finie (4 s au plus) : le
  /// « il reste … » de la 3e fléchette n'est plus coupé quand « suivant »
  /// arrive vite (joueur virtuel, bouton de la cible).
  ///
  /// [interrupt] (joueur suivant demandé) : les annonces en cours ou en
  /// attente sont coupées, le son du joueur part tout de suite. Sinon on
  /// attend la fin de l'annonce en cours (2,5 s au plus).
  /// [onStart] : appelé au moment où le son du joueur part (bandeau du tour
  /// synchronisé avec le son).
  void turnCue(String text,
      {String sound = '',
      Uint8List? voice,
      int ms = 250,
      bool next = true,
      bool interrupt = false,
      VoidCallback? onStart}) {
    final id = ++_cueId;
    if (interrupt) {
      _laterGen++;
      _stopVoice();
    }
    () async {
      for (var i = 0; !interrupt && talking && i < 25; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (id != _cueId) return;
      }
      if (id != _cueId) return;
      onStart?.call();
      final c = _cue;
      final custom = sound.isNotEmpty && (sound != 'voice' || voice != null);
      if (_muted || !effects || c == null || !custom) {
        if (next) play(Sfx.next);
        sayLater(text, ms);
        return;
      }
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

  /// Annonce du tour pas encore jouée annulée (le joueur a déjà lancé).
  void cancelCue() => _cueId++;

  /// Une annonce est en cours ou va partir (`sayLater`).
  bool get talking => _later > 0 || _speakingId != 0;
  int _later = 0;
  int _speakingId = 0;

  /// Partie quittée : plus rien de ce qui attendait (annonce du tour,
  /// `sayLater`, son du joueur) et l'annonce en cours coupée.
  void hush() {
    _cueId++;
    _laterGen++;
    _stopVoice();
    _cue?.stop().catchError((_) {});
  }

  int _laterGen = 0;

  void _stopVoice() {
    _speakingId = 0;
    _sayId++;
    _speaker?.stop().catchError((_) {});
    if (!_synthBusy) _tts?.stop().catchError((_) => 0);
  }

  /// Annonce vocale (coupe l'annonce précédente) : voix enregistrée pour
  /// tout ce qu'elle connaît, synthèse vocale pour le reste (pseudos).
  /// Dernières annonces (tests).
  @visibleForTesting
  final said = <String>[];

  void say(String text) {
    if (_muted || _background || !voice || text.trim().isEmpty) return;
    said.add(text);
    if (said.length > 50) said.removeAt(0);
    final tts = _tts;
    final sp = _speaker;
    final parts = sp == null ? null : _bank?.plan(text, names);
    final id = ++_sayId;
    _speakingId = id;
    () async {
      try {
        try {
          await sp?.stop();
          // (pas pendant l'enregistrement d'un pseudo : il serait coupé)
          if (!_synthBusy) await tts?.stop();
        } catch (_) {}
        for (final p in parts ?? [VoicePart.tts(text)]) {
          if (id != _sayId || _muted || !voice) return;
          try {
            final name = p.clip == null && _isName(p.text!)
                ? _nameFiles[spokenName(p.text!)]
                : null;
            if (p.clip != null || (name != null && sp != null)) {
              final done = sp!.onPlayerComplete.first;
              final dir = _voiceDir;
              await sp.play(
                  name != null
                      ? DeviceFileSource(name)
                      : dir != null
                          ? DeviceFileSource('$dir/${p.clip}')
                          : AssetSource('voice/${p.clip}'),
                  volume: 1.0);
              await done.timeout(const Duration(seconds: 6));
            } else if (tts != null) {
              await tts
                  .speak(_isName(p.text!) ? spokenName(p.text!) : p.text!)
                  .timeout(const Duration(seconds: 8));
            }
          } catch (_) {}
        }
      } finally {
        if (_speakingId == id) _speakingId = 0;
      }
    }();
  }

  bool _isName(String t) =>
      names.any((n) => n.trim().toLowerCase() == t.trim().toLowerCase());

  /// Annonce après un court délai (laisse le bruitage se jouer).
  void sayLater(String text, [int ms = 350]) {
    _later++;
    final gen = _laterGen;
    Timer(Duration(milliseconds: ms), () {
      _later--;
      if (gen != _laterGen) return;
      say(text);
    });
  }

  /// Appli passée en arrière-plan (bouton Accueil) : plus aucun son ;
  /// la musique reprend au retour.
  bool _background = false;
  bool get background => _background;
  set background(bool v) {
    if (_background == v) return;
    _background = v;
    if (v) {
      _music?.pause().catchError((_) {});
      _loop?.pause().catchError((_) {});
      _stopVoice();
    } else {
      if (_musicWanted) startMusic();
      if (_loopAsset != null) _loop?.resume().catchError((_) {});
    }
  }

  void startMusic() {
    _musicWanted = true;
    final m = _music;
    if (_muted || _background || !music || m == null) return;
    if (m.state == PlayerState.playing) return;
    if (m.state == PlayerState.paused) {
      m.resume().catchError((_) {});
      return;
    }
    _playTrack();
  }

  void _playTrack() {
    final m = _music;
    if (m == null || _background) return;
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
