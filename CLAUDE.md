# GranBoard App

Appli Flutter (Android) de fléchettes, connectée en Bluetooth LE à une cible électronique GranBoard. Projet perso de foclabroc.

## État actuel

- Prototype : scan BLE, connexion à la cible, décodage de chaque fléchette (affichage `T20 (60)`, `BULL (50)`, etc.) et log brut.
- Mise à jour dans l'appli (comme Pixel Trade) : vérification de la dernière release GitHub au lancement + bouton dans l'écran de scan.
- Pas encore de mode de jeu.

## Structure

- `lib/granboard.dart` : décodeur des trames BLE (`GranBoardDecoder.decode`) → `HitEvent` / `ButtonEvent` / `UnknownEvent`. Base de tous les modes de jeu.
- `lib/main.dart` : écran de scan + écran de connexion/log.
- `lib/update_check.dart` : mise à jour dans l'appli (API GitHub releases/latest, version lue dans le nom `granboard.VX.Y.Z.apk`, téléchargement puis installateur Android via `open_filex`).
- `test/granboard_test.dart` : tests du décodeur.
- `.github/workflows/apk.yml` : lancé à la main (Actions → APK Android → Run workflow). Tests, build, vérification de la signature, APK `granboard.VX.Y.Z.apk` en artefact ; case « publier » = release `vX.Y.Z` (notes tirées du `CHANGELOG.md`). Signé avec la clé debug de foclabroc (secret `DEBUG_KEYSTORE_B64`, même valeur que Pixel Trade), jamais commitée.

## Sortir une version

1. Changer `version:` du `pubspec.yaml` ET `kAppVersion` dans `lib/update_check.dart` (le workflow refuse s'ils diffèrent).
2. Ajouter la section `## vX.Y.Z` au `CHANGELOG.md`.
3. Pousser, puis lancer le workflow avec « publier » coché : les appareils installés proposent la mise à jour au lancement.

## Protocole GranBoard (relevé par calibration sur la cible de foclabroc)

- L'appli écoute toutes les characteristics en `notify`/`indicate` (pas d'UUID codé en dur).
- Chaque fléchette envoie du texte ASCII `ligne.colonne@` (position dans la matrice de contacts), ex. `3.4@` = T20.
- Le bouton de la cible envoie `BTN@`.
- 4 zones par numéro : simple intérieur, triple, simple extérieur, double. Bull 25 = `8.0@`, Bull 50 = `4.0@` (compte comme double pour le double-out).
- La table complète est dans `GranBoardDecoder._codes`. La cible n'accepte qu'une connexion BLE : fermer l'appli GranBoard officielle.

## Stack

- `flutter_blue_plus` (1.x, pas de paramètre `license` sur `connect`), `permission_handler`, `shared_preferences`, `path_provider`, `url_launcher`, `open_filex`.
- Android : permissions BLE + `INTERNET` + `REQUEST_INSTALL_PACKAGES` dans `AndroidManifest.xml` ; `build.gradle.kts` = template Flutter/AGP 9 d'origine (ne pas réécrire avec `kotlinOptions`, refusé par AGP 9).
- Package Android : `com.example.granboard_proto`.

## Règles de travail

- Toujours montrer les changements à foclabroc et attendre son accord avant de pousser.
- Ne jamais commiter de clé de signature.
- Après chaque push réussi, mettre à jour ce CLAUDE.md.
- Échanges en français, concis.
