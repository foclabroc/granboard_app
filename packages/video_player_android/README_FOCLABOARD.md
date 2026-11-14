# video_player_android (copie locale pour Foclaboard)

Copie de `video_player_android` 2.12.2 (pub.dev, licence BSD, voir `LICENSE`), branchée par
`dependency_overrides` dans le `pubspec.yaml` de l'appli. Changements :

- `FocRenderers.java` : si un décodeur vidéo ne démarre pas, ExoPlayer passe au suivant
  (`setEnableDecoderFallback`) ; sur Android TV, décodeurs logiciels en premier (le décodeur
  matériel de la TCL 55P615 échoue sur les vidéos de l'appli).
- `TextureVideoPlayer` / `PlatformViewVideoPlayer` : `ExoPlayer.Builder(context, FocRenderers.create(context))`.
- `ExoPlayerEventListener.onPlayerError` : message avec les causes de l'erreur (nom du décodeur).

Exemples et tests du paquet retirés.
