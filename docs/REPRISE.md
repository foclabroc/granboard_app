# Reprise du travail — Foclaboard

Mis à jour le 27/11/2026 (v0.6.37). Pour l'historique détaillé et la structure complète : `CLAUDE.md`.

## Où on en est

- Dernière version poussée : **v0.6.37**. Builds : lancer GitHub Actions → « APK Android » → « publier » (la 0.6.35/0.6.36 ont pu être buildées, à vérifier dans Releases).
- Pas de SQL en attente sur le serveur.
- Derniers ajouts (v0.6.33 → v0.6.37) :
  - **Fonds illustrés partout** : un par jeu (`assets/themes/<x01|cricket|match|practice|party|bowling|golf|football|cat|paint|time|gp>.jpg`) et par menu (`home`, `tournament`, `online`, `options`, `menu`). Plus de choix de thème (toujours « Retransmission » noir et or).
  - **Accueil** : fond = grande salle de finale (`_HomeBackground` dans `home_page.dart`), tuiles transparentes.
  - **Mosaïques des jeux** (`game_picker_page.dart`) : tuiles illustrées (`assets/icons`), lignes réparties (jamais un jeu seul), Party 5 par ligne, Medley en tuiles 3 à 13 legs (2 lignes de 3), effets `TileFx` (reflet + enfoncement au toucher, `lib/ui/tile_fx.dart`).
  - **Bouton Menu principal** (`HomeButton`, `widgets.dart`) sur toutes les barres ; en partie il demande d'abandonner.
  - **01** : historique barré dans le panneau du joueur en cours (`_VisitHistory`, `game_page.dart`) : reste avant chaque tour barré + points du tour, et le tour en cours en blanc (285 − 17 → 268 − 2 → 266).
  - **Fight Club illustré** (`lib/ui/arcade/fight_scene.dart`) : ring + 4 boxeurs détourés (`assets/fight/`), coups, soins, K.O.
  - **Zombies illustré** (déjà là depuis la v0.6.30) avec ses sons.
  - **Joueur virtuel** : 3 s d'attente après son tour avant de passer au joueur suivant (`_scheduleBot`, `game_page.dart`).
  - Nombre de joueurs requis affiché dans les réglages (`_playersNeed`, `setup_page.dart`).

## Prochaines étapes prévues

1. **Scènes illustrées des autres jeux Party arcade**, sur le modèle Fight Club / Zombies : **Tir à la corde** (`tug_scene.dart`), puis **Puissance 4** (`connect4_scene.dart`), puis les autres (`lib/ui/arcade/*_scene.dart`). Principe : un fond 16:9 (1376 × 768) + des éléments détourés en webp, chargés par une classe `XxxArt.load()` ; sans images (tests) on garde le dessin actuel.
2. **Sons du Fight Club** (coups, cloche, foule) : sons Pixabay à fournir par foclabroc, à brancher comme ceux de Zombies (`AudioService.playFile`, `startLoop`).
3. **Casse-mur** : en attente de l'avis de foclabroc.
4. Idée gardée : **mode télécommande** (un 2e téléphone pilote la partie de la tablette reliée à la cible).
5. À confirmer sur appareil : lumières de la 3s (contour), vidéos sur la TV TCL, caméra tablette → TV, VDarts.

## Méthodes

### Images (Gemini)

- Style : illustrations « cartoon-réalistes », brillantes, contrastées, fond sombre, **sans aucun texte** (« Absolutely no text, no letters, no numbers, no logo »).
- Fonds : 16:9. Pour garder le style, travailler dans une conversation Gemini qui a déjà produit des images du même style (« Spooky Graveyard Game Background » pour les scènes arcade, « Darts Tournament Menu Background » pour les fonds de menus), ou joindre une image existante avec : « Use the attached image ONLY as a style reference: copy exactly its art style, rendering, lighting and color palette. Do not copy its content or composition. »
- Personnages / objets à détourer : « plain flat pure green background (#00FF00), no shadow, no floor, no text », plusieurs poses côte à côte dans la même image (même personnage).
- Détourage : vert dominant → transparent (alpha = 1 − (g − max(r, b) − 40) / 60), même haut de recadrage pour toutes les poses d'une image (même échelle), export webp ~420 px de haut.
- Fonds réduits à 1280 px de large, JPEG qualité ~82, dans `assets/themes/` (déclaré dans `pubspec.yaml`).
- Icônes des jeux : planches 3 × 3 découpées en 128 px (`assets/icons/`).

### Sons

- Fournis par foclabroc (Pixabay). Couper les silences, **pas de limiteur ni de loudnorm** sur les sons d'intro / vidéos (crête −2 dB) ; ogg vorbis.

### Vérifier le rendu sans téléphone

- Test temporaire de capture (à ne pas commiter) : charger les polices Barlow (`assets/fonts/BarlowCondensed-*.ttf`, famille `Barlow`) et MaterialIcons avec `FontLoader`, envelopper le `MaterialApp` dans `ListenableBuilder(listenable: Tv.changes, …)` (sinon le thème du jeu ne s'applique pas), `builder: Tv.appBuilder`, `RepaintBoundary.toImage`, précharger les images dans `runAsync`. Taille paysage téléphone : 937 × 421 ou 785 × 392.
