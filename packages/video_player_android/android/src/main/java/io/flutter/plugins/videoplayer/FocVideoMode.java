// Foclaboard : copie locale de video_player_android (voir README du dossier).
package io.flutter.plugins.videoplayer;

/**
 * Choix du décodeur vidéo sur Android TV, posé par l'appli (MainActivity, canal
 * « granboard/device ») : logiciel d'abord (sûr, défaut) ou matériel d'abord
 * (plus léger pour le processeur ; l'appli revient au logiciel si une vidéo
 * échoue). Sans annotation de media3 : utilisable depuis l'appli.
 */
public final class FocVideoMode {
  private FocVideoMode() {}

  public static volatile boolean softwareFirst = true;
}
