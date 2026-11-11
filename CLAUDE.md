# GranBoard App

Appli Flutter (Android) de fléchettes, connectée en Bluetooth LE à une cible électronique GranBoard. Projet perso de foclabroc.

## État actuel

- Prototype : scan BLE, connexion à la cible, décodage de chaque fléchette (affichage `T20 (60)`, `BULL (50)`, etc.) et log brut.
- Pas encore de mode de jeu.

## Structure

- `lib/granboard.dart` : décodeur des trames BLE (`GranBoardDecoder.decode`) → `HitEvent` / `ButtonEvent` / `UnknownEvent`. Base de tous les modes de jeu.
- `lib/main.dart` : écran de scan + écran de connexion/log.
- `test/granboard_test.dart` : tests du décodeur.
- `.github/workflows/apk.yml` : build de l'APK, lancé à la main (Actions → APK → Run workflow), APK en artefact. Signé avec la clé debug de foclabroc (secret GitHub `DEBUG_KEYSTORE`, base64), jamais commitée.

## Protocole GranBoard (relevé par calibration sur la cible de foclabroc)

- L'appli écoute toutes les characteristics en `notify`/`indicate` (pas d'UUID codé en dur).
- Chaque fléchette envoie du texte ASCII `ligne.colonne@` (position dans la matrice de contacts), ex. `3.4@` = T20.
- Le bouton de la cible envoie `BTN@`.
- 4 zones par numéro : simple intérieur, triple, simple extérieur, double. Bull 25 = `8.0@`, Bull 50 = `4.0@` (compte comme double pour le double-out).
- La table complète est dans `GranBoardDecoder._codes`. La cible n'accepte qu'une connexion BLE : fermer l'appli GranBoard officielle.

## Stack

- `flutter_blue_plus` (1.x, pas de paramètre `license` sur `connect`), `permission_handler`, `shared_preferences`.
- Android : permissions BLE dans `AndroidManifest.xml` ; `build.gradle.kts` = template Flutter/AGP 9 d'origine (ne pas réécrire avec `kotlinOptions`, refusé par AGP 9).
- Package Android : `com.example.granboard_proto`.

## Règles de travail

- Toujours montrer les changements à foclabroc et attendre son accord avant de pousser.
- Ne jamais commiter de clé de signature.
- Après chaque push réussi, mettre à jour ce CLAUDE.md.
- Échanges en français, concis.
