# GranBoard App

Appli Flutter (Android, **paysage**) de fléchettes, connectée en Bluetooth LE à une cible électronique GranBoard (Dash et 3s). Comptes joueurs et stats sur le serveur maison de foclabroc. Projet perso de foclabroc.

## État actuel

- v0.5.0 : **écran TV** (même APK) : sur Android TV l'appli démarre en mode écran, affiche un code ; le téléphone s'y relie et pilote tout ; la TV rejoue la partie et joue le son. Liaison par le serveur maison (relais temps réel de Pixel Trade), choisie pour préparer le jeu à distance (joueur chez lui).
- v0.4.0 : comptes joueurs sur le serveur maison (pseudo + PIN 4 chiffres, mémorisés sur le téléphone), stats en ligne, note de niveau + classe (D → MASTER), classements, invités ; toute l'appli en paysage ; grande cible animée en partie.
- v0.3.x : habillage « retransmission TV » (noir/or, Barlow Condensed), annonceur vocal français, bruitages + musique ; calibration par cible ; 3s reconnue (même table que la Dash + `OUT@`).
- v0.2.0 : X01 complet (301/501/701/901) + Freeze 01 en 2 équipes, In/Out Open/Double/Master, bull 25/50 ou 50/50, limite de manches.
- Mise à jour dans l'appli (comme Pixel Trade) : dernière release GitHub vérifiée au lancement + bouton dans l'accueil.
- À confirmer : la 3s de l'ami avec la table standard (sans calibration) depuis la v0.3.3.
- Prévu : jeu à distance (un joueur chez lui avec sa cible, même salon), d'autres jeux (Cricket…).

## Structure

- `lib/granboard.dart` : décodeur des trames BLE (`GranBoardDecoder.decode`) → `HitEvent` / `MissEvent` (bordure 3s) / `ButtonEvent` / `UnknownEvent`. `BoardTable` : tables calibrées.
- `lib/main.dart` : démarrage (paysage forcé + plein écran). `detectTv()` : canal `granboard/device` → `isTv` (Kotlin `MainActivity.kt`, `FEATURE_LEANBACK`) ou pref `tv_mode` ; TV → `TvHome`, sinon `HomePage` (cible, comptes, `TvLink.load`, `PlayerStore.sync()`). `GranBoardAppState.setTvMode` bascule téléphone ↔ écran.
- `lib/tv_link.dart` (téléphone) : `TvLink` — `link(code)` (`gb_tv_link`), `pushLobby()` (accueil), `pushGame(game, screen: game|results)` = `{screen, host, game: X01Game.toJson(), colors: {id: ARGB}}` via `gb_tv_push`, envoi « le dernier gagne ». Reliée → `AudioService.muted = true` (son sur la TV). `tv_host`/`tv_code` → déliée. Prefs `tv_link_v1`.
- `lib/tv/tv_client.dart` (TV) : `TvClient` — salon `gb_tv_open` (code + clé gardés en prefs `tv_room_v1`, même code après redémarrage), WebSocket Phoenix du relais (`wss://…/realtime/v1/websocket`, canal `realtime:<topic>`, heartbeat 25 s, reconnexion 5 s) : sur `broadcast` → `fetch()` (`gb_tv_get` depuis `seq`). Relecture de secours toutes les 1,5 s sans relais, 12 s avec. `debugSetState` pour les tests.
- `lib/tv/tv_home.dart` (TV) : écran code (4 cases, « Nouveau code », « Mode téléphone »), attente (« relié à … »), partie (`_TvGame` : rejoue le journal d'actions ; nouvelles actions appliquées une à une, effets seulement pour la dernière ; journal raccourci = annulation → reconstruit sans effet), résultats (`ResultsPage(tv: true)`, sans boutons). Musique hors partie. Couleurs des joueurs via `PlayerStore.remoteColors`.
- `lib/board_service.dart` : connexion BLE partagée (singleton), flux `events` (jeux) et `frames` (diagnostic, calibration), dernière cible mémorisée, table calibrée par cible, `injectFrame` pour les tests.
- `lib/game/x01.dart` : moteur X01/Freeze **pur Dart**. État recalculé en rejouant les actions : `undo()` retire la dernière. Journal sérialisable (`actionLog` : `n` suivant, `m` ratée, `d:<numéro>:<anneau>`), `toJson` / `X01Game.fromJson` / `applyLogEntry` (TV, jeu à distance). `suggestCheckout`.
- `lib/server.dart` : `GbServer` (RPC PostgREST `gb_*`, même URL et clé que Pixel Trade), `ApiError` (messages en français). Les erreurs renvoyées `{"error": …}` sont converties en `ApiError` (aussi via `debugRpc` des tests).
- `lib/players.dart` : `PlayerStore` = comptes mémorisés sur le téléphone (prefs `accounts_v1` : id, pseudo, couleur, **jeton de session**, dernier profil serveur en cache) + parties en attente (prefs `pending_games_v1`, joueurs désignés par `pid`, jeton ajouté à l'envoi). `recordX01` (invités exclus) → `flush()` ; hors ligne : gardé et renvoyé au prochain `sync()`/`flush()`. Session refusée → compte `expired` (« À RECONNECTER »), la partie attend la reconnexion. `ratingClass(note)`. `X01Player.id` = id serveur en texte, ou `guest-N` pour un invité (`isGuestId`).
- `lib/audio.dart` : `AudioService` (effets, musique de menu, annonceur `say`/`sayLater`). Toute erreur audio est avalée.
- `lib/ui/theme.dart` : palette `Tv`, `Tv.theme()`, `TvSection`, `TvBackground`.
- `lib/ui/dartboard.dart` : `Dartboard` (cible dessinée, surbrillance + badges) et **`AnimatedDartboard`** (partie : fléchettes plantées vues de face aux couleurs du joueur, `dartPoint` = point d'impact stable par zone, onde à l'impact, zones qui pulsent en continu, éclair rouge bust / or victoire).
- `lib/ui/game_fx.dart` : `GameFx` (sons, annonceur, vibrations, annonces animées après une fléchette / « suivant » / victoire) + `GameSplash` ; partagés téléphone / TV.
- `lib/ui/` : `home_page` (cible + titre à gauche, menu à droite : Nouvelle partie, Joueurs, Classements ; icône TV verte si reliée → `tv_sheet`), `account_page` (connexion / création, PIN sur pavé numérique à l'écran, création = code tapé 2 fois), `players_page` (+ `PlayerDetailPage`, `RatingBadge`), `ranking_page` (onglets note, victoires, moyenne, 180, meilleure fin, meilleure manche), `setup_page` (2 colonnes, comptes + invités + « Ajouter un joueur »), `game_page` (`GameLayout` partagé avec la TV : cible animée | joueur en cours + boutons | tableau des scores ; envoie l'état à la TV après chaque action), `results_page` (podium | stats ; envoi au serveur en arrière-plan + message), `calibration_page` (boutons fixes en bas), `connect_page`, `diagnostic_page`, `sound_settings`, `widgets` (`PlayerAvatar`, `BoardBanner` fin).
- `assets/` : sons et musique générés par `tools/make_sounds.py`, icône par `tools/make_icon.py`, police Barlow Condensed (OFL).
- `lib/update_check.dart` : mise à jour dans l'appli (version dans le nom `granboard.VX.Y.Z.apk`).
- `sql/` : fichiers SQL du serveur, relançables, `AAAA-MM-JJ_sujet.sql` (`2026-11-11_comptes_stats.sql`, puis `2026-11-11_salon_tv.sql`).
- `test/` : décodeur, règles X01/Freeze/checkout, comptes + file hors ligne (`players_test`, avec `fake_server.dart` qui imite les RPC `gb_*`), écrans en **paysage 785 × 392** (`ui_test` : débordements, partie, calibration, compte, classements), TV (`tv_test` : liaison/envoi/son coupé avec le faux serveur, écran TV 960 × 540 code → attente → partie → résultats).
- `.github/workflows/apk.yml` : à la main (Actions → APK Android → Run workflow, « publier » = release). Signé avec la clé debug de foclabroc (secret `DEBUG_KEYSTORE_B64`), jamais commitée.

## Serveur (comptes et stats)

- Serveur maison de Pixel Trade : PostgreSQL 17 + PostgREST derrière Caddy, `https://api.foclabroc.duckdns.org`, même clé publique `sb_publishable_…`. Tables et fonctions **préfixées `gb_`**, à côté de celles de Pixel Trade (`rc_`), sans y toucher.
- Fichier initial : `sql/2026-11-11_comptes_stats.sql` (tables `gb_players`, `gb_sessions`, `gb_games`, `gb_game_players`). Objets à `rc_owner`, aucun droit de table pour `anon`, fonctions internes `gb__*` fermées à l'API, RPC `gb_*` ouvertes à `anon`. Finir par `notify pgrst, 'reload schema';`.
- RPC : `gb_register(pseudo, pin, color)`, `gb_login(pseudo, pin)` (**renvoie** `{error: unknown|pin(+left)|locked(+minutes)}` au lieu de lever : une exception annulerait le compteur d'essais ; 5 erreurs → bloqué 15 min), `gb_check(tokens[])`, `gb_logout`, `gb_set_color`, `gb_set_pin`, `gb_submit(game)` (anti-doublon par `cid`, garde-fous sur les valeurs, invités jamais envoyés), `gb_profile(id)` (stats, note, rang, 20 dernières parties), `gb_top(kind)` (rating, wins, avg, n180, checkout, high ; note et moyenne à partir de 3 parties).
- Salon TV (`sql/2026-11-11_salon_tv.sql`, table `gb_tv`) : `gb_tv_open()` → {code 4 car., key, topic}, `gb_tv_link(code, nom)` → {host_key} (le dernier relié pilote, état remis à « lobby »), `gb_tv_push(code, host_key, state)` (128 Ko max, `tv_host` sinon) → seq + notification, `gb_tv_get(code, key, since)` → {seq[, state]} ou {error: tv_gone}. Notification via `rc__rt_safe(gb__tv_topic(code), 'gb', {seq})` (`'rc_' || 24 hex` de sha256('gbtv|'+code), format accepté par le relais `rc-realtime`). Salons inactifs 2 jours supprimés à l'ouverture d'un nouveau. Le relais traite ce canal comme « joueur » (rc__rt_here/gone) : sans effet, aucun joueur ne correspond.
- Note = moyenne aux 3 fléchettes des 20 dernières parties (`gb__rating`). Classe côté appli (`ratingClass`) : D < 25, C, B ≥ 35, A ≥ 45, AA ≥ 55, AAA ≥ 65, MASTER ≥ 80.
- Jetons de session : 24 octets aléatoires, seule l'empreinte sha256 est stockée (`gb_sessions`). PIN chiffré en bcrypt (`extensions.crypt`).
- Tester le SQL avant de le donner : PostgreSQL local dans le sandbox (`apt-get install postgresql`, rôles `anon`/`authenticated`/`rc_owner`, schéma `extensions` + pgcrypto), lancer le fichier deux fois, puis les RPC en `set role anon`.
- Les profils locaux des versions ≤ 0.3.3 (prefs `players_v1`) ne sont plus utilisés.

## Sortir une version

1. Changer `version:` du `pubspec.yaml` ET `kAppVersion` dans `lib/update_check.dart` (le workflow refuse s'ils diffèrent).
2. Ajouter la section `## vX.Y.Z` au `CHANGELOG.md`.
3. Pousser, puis lancer le workflow avec « publier » coché.

## Règles implémentées (X01)

- Bust (retour au score de début de manche) si : dépassement, reste 1 en Double/Master Out, fin sur une mauvaise fléchette, fin alors que l'équipe est gelée.
- Master = double, triple ou bull. Bull 50/50 : le 25 vaut 50 et compte comme un double.
- « Suivant » avant 3 fléchettes : fléchettes manquantes = ratées (moyenne). Fléchettes reçues après la fin de manche ignorées. Bordure 3s (`OUT@`) = ratée.
- Limite de manches : le plus petit reste gagne (total d'équipe en Freeze).
- Freeze 01 : 2 équipes de même taille, alternance A1, B1, A2, B2 ; équipe gelée si son total restant est strictement supérieur à celui de l'adversaire ; le joueur qui finit fait gagner son équipe.
- Stats envoyées seulement en ouvrant les résultats (pas si la partie est abandonnée).

## Protocole GranBoard

- L'appli écoute toutes les characteristics `notify`/`indicate`.
- Fléchette = texte ASCII `ligne.colonne@` (ex. `3.4@` = T20) ; bouton = `BTN@` ; bordure extérieure de la 3s = `OUT@`. `frameKey` ne garde que l'ASCII visible (la 3s ajoute probablement des octets invisibles).
- Table `GranBoardDecoder._codes` commune à la **Dash** et à la **3s** (vérifié par calibration le 11/11/2026). Bull 25 = `8.0@`, Bull 50 = `4.0@`.
- Calibration (autres modèles) : 82 zones à partir du 20 + étape bordure, table par cible (prefs `board_table_<remoteId>`), « Copier la table » pour l'intégrer ensuite. La cible n'accepte qu'une connexion BLE.

## Stack

- `flutter_blue_plus` (1.x), `permission_handler`, `shared_preferences`, `http`, `web_socket_channel`, `path_provider`, `url_launcher`, `open_filex`, `wakelock_plus`, `audioplayers`, `flutter_tts`.
- Vérifier avant de pousser : `flutter analyze` (0 problème) et `flutter test`. Flutter s'installe dans le sandbox (archive stable de storage.googleapis.com dans `/opt/flutter`). Pour relire le rendu : test temporaire de captures (Barlow + MaterialIcons via `FontLoader`, `RepaintBoundary.toImage`, `BoardService.injectFrame`, faux serveur), à ne pas commiter. En partie, ne pas utiliser `pumpAndSettle` (la cible pulse en continu).
- Android : permissions BLE + `INTERNET` + `REQUEST_INSTALL_PACKAGES` (+ query `TTS_SERVICE`), `screenOrientation="sensorLandscape"`, Android TV : `LEANBACK_LAUNCHER`, bannière `res/drawable/banner.png` (320 × 180), `uses-feature` leanback / touchscreen / bluetooth non obligatoires ; `build.gradle.kts` = template Flutter/AGP 9 (pas de `kotlinOptions`) + signature release via `android/key.properties` écrit par la CI.
- Package Android : `com.example.granboard_proto`.

## Règles de travail

- Toujours montrer les changements à foclabroc et attendre son accord (« pousse ») avant de pousser.
- **SQL avant le code** : donner le fichier SQL d'abord, foclabroc le lance sur le serveur (`psql -U postgres -d postgres -f fichier.sql`), puis il dit « pousse ».
- Ne jamais commiter de clé de signature.
- Après chaque push réussi, mettre à jour ce CLAUDE.md.
- Échanges en français, concis.
