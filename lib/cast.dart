import 'package:flutter/services.dart';

/// Bouton CAST : ouvre le menu « Diffuser l'écran » d'Android (recopie du
/// téléphone vers un Chromecast, une Android TV ou un écran Miracast).
/// Côté Android : `MainActivity.openCast` (réglage standard, puis Samsung
/// Smart View, Xiaomi, puis réglages d'affichage). Faux si rien n'a pu
/// s'ouvrir (ou hors Android).
Future<bool> openCast() async {
  try {
    return await const MethodChannel('granboard/device')
            .invokeMethod<bool>('openCast') ??
        false;
  } catch (_) {
    return false;
  }
}
