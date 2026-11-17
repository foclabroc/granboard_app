// Écran Android TV : moteur de rendu (Impeller ou Skia) et décodeur des
// vidéos (matériel ou logiciel), choisis depuis le téléphone (fenêtre TV) et
// gardés par l'écran. Côté Android : MainActivity.kt (canal granboard/device)
// et FocVideoMode (copie locale de video_player_android).

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TvGfx {
  TvGfx._();

  static const _ch = MethodChannel('granboard/device');

  /// Clés lues aussi par MainActivity.kt (préfixe « flutter. »).
  /// Moteur gardé : impeller | skia (absent = skia, défaut depuis la
  /// 0.6.23 ; l'ancienne clé tv_engine n'est plus lue).
  static const kEngine = 'tv_render';
  static const kVideo = 'tv_video';
  static const kHwFail = 'tv_video_hwfail';

  /// Vrai sur une Android TV (posé par main.dart) ; rien ne se passe sinon.
  static bool enabled = false;

  /// Moteur qui tourne : impeller | skia.
  static String engine = 'skia';

  /// Mode d'affichage choisi au démarrage (« 1080p (au lieu de …) ») ou ''.
  static String display = '';

  /// Taille de l'écran en pixels, telle que l'appli la dessine.
  static String size = '';

  /// Choix du téléphone : auto (matériel, logiciel après un échec) | sw.
  static String video = 'auto';

  /// Une vidéo a échoué avec le décodeur matériel (mode auto).
  static bool hwFailed = false;

  static bool get softwareVideo => video == 'sw' || hwFailed;

  static bool _restarting = false;

  /// Au démarrage de l'écran TV : état gardé, décodeur posé avant toute
  /// vidéo.
  static Future<void> load() async {
    if (!enabled) return;
    try {
      final info = await _ch.invokeMapMethod<String, dynamic>('gfxInfo');
      engine = '${info?['engine'] ?? 'skia'}';
      display = '${info?['display'] ?? ''}';
      size = '${info?['size'] ?? ''}';
      final p = await SharedPreferences.getInstance();
      video = p.getString(kVideo) ?? 'auto';
      hwFailed = p.getBool(kHwFail) ?? false;
    } catch (_) {}
    await _pushVideo();
  }

  static Future<void> _pushVideo() async {
    if (!enabled) return;
    try {
      await _ch.invokeMethod('videoSoftware', softwareVideo);
    } catch (_) {}
  }

  /// Réglages envoyés par le téléphone dans l'état ({render, video} ;
  /// `engine` des téléphones en 0.6.22 ignoré : il valait impeller
  /// sans que personne l'ait choisi).
  /// Moteur différent : gardé puis l'appli redémarre (le moteur se choisit
  /// au lancement).
  static Future<void> apply(Object? gfx) async {
    if (!enabled || gfx is! Map) return;
    final p = await SharedPreferences.getInstance();
    final v = gfx['video'] == 'sw' ? 'sw' : 'auto';
    if (v != video) {
      video = v;
      // Revenir sur « auto » = réessayer le décodeur matériel
      hwFailed = false;
      await p.setString(kVideo, v);
      await p.setBool(kHwFail, false);
      await _pushVideo();
    }
    final r = gfx['render'];
    if (r is! String) return;
    final e = r == 'impeller' ? 'impeller' : 'skia';
    if (e != engine && !_restarting) {
      _restarting = true;
      await p.setString(kEngine, e);
      try {
        await _ch.invokeMethod('restart');
      } catch (_) {
        _restarting = false;
      }
    }
  }

  /// Une vidéo n'a pas pu être lue : en mode auto, retour au décodeur
  /// logiciel (gardé jusqu'à ce que le téléphone change de choix).
  static Future<void> videoFailed() async {
    if (!enabled || softwareVideo) return;
    hwFailed = true;
    await _pushVideo();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(kHwFail, true);
    } catch (_) {}
  }

  /// Résumé affiché dans un coin de l'écran d'attente.
  static String get label => enabled
      ? [
          engine == 'skia' ? 'SKIA' : 'IMPELLER',
          softwareVideo ? 'VIDÉO LOGICIELLE' : 'VIDÉO MATÉRIELLE',
          if (display.isNotEmpty) display.toUpperCase() else if (size.isNotEmpty) size,
        ].join(' · ')
      : '';
}
