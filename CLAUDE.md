# GranBoard App

Appli Flutter (Android) de fléchettes, connectée en Bluetooth LE à une cible électronique GranBoard. Projet perso de foclabroc.

## État actuel

- v0.2.0 : X01 complet (301/501/701/901) + Freeze 01 en 2 équipes, options In/Out (Open/Double/Master), bull 25/50 ou 50/50, limite de manches ; profils joueurs + stats ; reconnexion auto à la dernière cible ; diagnostic des trames.
- Mise à jour dans l'appli (comme Pixel Trade) : vérification de la dernière release GitHub au lancement + bouton dans l'accueil.
- v0.3.0 : habillage « retransmission TV » (noir/or, police Barlow Condensed), cible dessinée avec impacts de la manche, annonces animées, annonceur vocal français (flutter_tts), bruitages + musique de menu, podium.
- v0.3.1 : calibration par cible (la GranBoard 3s d'un ami n'envoie pas les mêmes codes que la Dash : seul `BTN@` est commun).
- Prévu : affichage TV plus tard (le moteur de jeu est déjà séparé de l'interface), d'autres jeux (Cricket…).

## Structure

- `lib/granboard.dart` : décodeur des trames BLE (`GranBoardDecoder.decode`) → `HitEvent` / `ButtonEvent` / `UnknownEvent`. Base de tous les modes de jeu.
- `lib/main.dart` : démarrage (charge la cible mémorisée et les joueurs).
- `lib/board_service.dart` : connexion BLE partagée (singleton), flux `events` pour les jeux et `frames` pour le diagnostic, mémorise la dernière cible.
- `lib/game/x01.dart` : moteur X01/Freeze **pur Dart** (aucune dépendance Flutter, réutilisable pour la TV). L'état est recalculé en rejouant la liste des actions (fléchette / suivant) : `undo()` retire la dernière. Contient aussi `suggestCheckout`.
- `lib/players.dart` : profils joueurs + stats cumulées + historique (50 dernières parties), en `shared_preferences` (clé `players_v1`).
- `lib/audio.dart` : `AudioService` (singleton) — effets (`Sfx`, pool audioplayers en lowLatency, contexte `mixWithOthers` pour ne pas couper la musique), musique de menu en boucle (coupée pendant une partie), annonceur `say`/`sayLater` (flutter_tts fr-FR). Réglages en prefs (clé `audio_v1`). Toute erreur audio est avalée : ne doit jamais gêner la partie.
- `lib/ui/theme.dart` : palette `Tv` (noir/or/rouge/vert), `Tv.theme()`, `TvSection`, `TvBackground`. `lib/ui/dartboard.dart` : cible en `CustomPainter` (ordre des numéros `kBoardOrder`, zones touchées en surbrillance avec badge 1/2/3).
- `lib/ui/` : `home_page` (accueil + carte cible), `connect_page` (recherche BLE), `diagnostic_page`, `setup_page` (réglages mémorisés, clé `x01_setup_v1`), `game_page`, `results_page`, `players_page`, `sound_settings`, `widgets`.
- `assets/` : `sounds/*.ogg` et `music/menu.ogg` générés par `tools/make_sounds.py` (synthèse numpy/scipy + ffmpeg, libres de droits) ; icône générée par `tools/make_icon.py` (mipmaps Android + `assets/images/icon.png`) ; police Barlow Condensed (OFL, `assets/fonts/OFL.txt`).
- Annonceur : texte des annonces dans `game_page.dart` (`_dart`, `_next`, `_onWin`).
- `lib/update_check.dart` : mise à jour dans l'appli (API GitHub releases/latest, version lue dans le nom `granboard.VX.Y.Z.apk`, téléchargement puis installateur Android via `open_filex`).
- `test/` : décodeur (`granboard_test`), règles X01/Freeze/checkout (`x01_test`), affichage des écrans à taille téléphone (`ui_test`, détecte les débordements).
- `.github/workflows/apk.yml` : lancé à la main (Actions → APK Android → Run workflow). Tests, build, vérification de la signature, APK `granboard.VX.Y.Z.apk` en artefact ; case « publier » = release `vX.Y.Z` (notes tirées du `CHANGELOG.md`). Signé avec la clé debug de foclabroc (secret `DEBUG_KEYSTORE_B64`, même valeur que Pixel Trade), jamais commitée.

## Sortir une version

1. Changer `version:` du `pubspec.yaml` ET `kAppVersion` dans `lib/update_check.dart` (le workflow refuse s'ils diffèrent).
2. Ajouter la section `## vX.Y.Z` au `CHANGELOG.md`.
3. Pousser, puis lancer le workflow avec « publier » coché : les appareils installés proposent la mise à jour au lancement.

## Règles implémentées (X01)

- Bust (retour au score de début de manche, points de la manche perdus) si : dépassement, reste 1 en Double/Master Out, fin sur une mauvaise fléchette, ou fin alors que l'équipe est gelée.
- Master = double, triple ou bull. Bull 50/50 : le 25 vaut 50 et compte comme un double.
- « Suivant » avant 3 fléchettes : les fléchettes manquantes comptent comme ratées (moyenne). Fléchettes reçues après la fin de manche ignorées.
- Limite de manches : le plus petit reste gagne (total d'équipe en Freeze), égalités = plusieurs gagnants.
- Freeze 01 (règle GranBoard) : 2 équipes de même taille, lancer en alternance A1, B1, A2, B2 ; une équipe est gelée si son total restant est strictement supérieur à celui de l'adversaire (évalué avant chaque fléchette) ; le joueur qui finit fait gagner son équipe.
- Stats enregistrées seulement en ouvrant les résultats (pas si la partie est abandonnée).

## Protocole GranBoard (relevé par calibration sur la cible de foclabroc)

- L'appli écoute toutes les characteristics en `notify`/`indicate` (pas d'UUID codé en dur).
- Chaque fléchette envoie du texte ASCII `ligne.colonne@` (position dans la matrice de contacts), ex. `3.4@` = T20.
- Le bouton de la cible envoie `BTN@`.
- 4 zones par numéro : simple intérieur, triple, simple extérieur, double. Bull 25 = `8.0@`, Bull 50 = `4.0@` (compte comme double pour le double-out).
- La table complète (GranBoard **Dash** de foclabroc) est dans `GranBoardDecoder._codes`.
- Autres modèles (ex. **3s**) : codes différents. Calibration dans l'appli (`ui/calibration_page.dart`, 82 zones en tournant à partir du 20) → table brute « trame → zone » sauvegardée par cible (prefs `board_table_<remoteId>`, format `BoardTable` : `trame\tnuméro\tindex Ring` par ligne), appliquée par `BoardService.customTable` (`decode(bytes, custom:)` : avec table, seule la table compte, `BTN@` toujours reconnu). Bouton « Copier la table » pour me l'envoyer : à intégrer ensuite comme table intégrée du modèle (détection par nom BLE à prévoir). La cible n'accepte qu'une connexion BLE : fermer l'appli GranBoard officielle.

## Stack

- `flutter_blue_plus` (1.x, pas de paramètre `license` sur `connect`), `permission_handler`, `shared_preferences`, `path_provider`, `url_launcher`, `open_filex`, `wakelock_plus`, `audioplayers`, `flutter_tts`.
- Vérifier avant de pousser : `flutter analyze` (0 problème) et `flutter test`. Pour relire le rendu, un test temporaire peut capturer les écrans (charger Barlow + MaterialIcons avec `FontLoader`, `RepaintBoundary.toImage`, trames simulées via `BoardService.injectFrame`) ; ne pas le commiter.
- Android : permissions BLE + `INTERNET` + `REQUEST_INSTALL_PACKAGES` dans `AndroidManifest.xml` (+ query `TTS_SERVICE` pour l'annonceur) ; `build.gradle.kts` = template Flutter/AGP 9 d'origine (ne pas réécrire avec `kotlinOptions`, refusé par AGP 9) + signature release via `android/key.properties` (écrit par la CI, gitignoré) comme Pixel Trade, sinon clé debug du PC. Sans ça, la CI signe avec une clé debug générée et la vérification d'empreinte échoue.
- Package Android : `com.example.granboard_proto`.

## Règles de travail

- Toujours montrer les changements à foclabroc et attendre son accord avant de pousser.
- Ne jamais commiter de clé de signature.
- Après chaque push réussi, mettre à jour ce CLAUDE.md.
- Échanges en français, concis.
