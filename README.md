# GranBoard App

Appli Flutter (Android) de fléchettes pour cible électronique **GranBoard** (Dash, 3s), connectée en Bluetooth LE. Comptes, stats et classements sur le serveur maison. La même appli sert d'écran sur une Android TV.

## Utilisation

L'appli se joue en paysage, téléphone posé à côté de la cible.

1. Ferme l'appli GranBoard officielle (la cible n'accepte qu'une connexion BLE).
2. **Premier lancement** : crée ton profil principal (pseudo + code à 4 chiffres), ou « J'ai déjà un compte », ou « Plus tard ».
3. **Cible** (pastille en haut de l'accueil) → touche la GranBoard. Ensuite l'appli s'y reconnecte toute seule. Calibration et diagnostic dans le menu de la pastille.
4. **Joueurs** : ajoute d'autres comptes ; dans la fiche d'un joueur : photo de profil, son du tour (12 sons ou sa voix enregistrée), couleur, profil principal. Les invités jouent sans stats.
5. Choisis un jeu sur l'accueil, puis les joueurs et les règles.
6. Le bouton de la cible (ou « Suivant ») passe au joueur suivant ; « Raté » pour une fléchette hors cible ; « Annuler » revient en arrière.

## Jeux

- **01** : 301 / 501 / 701 / 901, Freeze en 2 équipes, In / Out Open / Double / Master, bull 25/50 ou 50/50, limite de manches ; fins possibles affichées.
- **Cricket** : Standard, Cut Throat, Caché, Cut Throat caché, Wildcard, No Score, Triple Only, Mickey Mouse, en individuel ou en équipes.
- **Match** : 3 à 13 legs, 01 ou Cricket à chaque leg.
- **Entraînement** (17) : Count Up, Target 20 / Bull / Hat / Horse, Choix de cible, Half It, Delta Shoot, Rotation, Shoot Force, Oniren, CR Count Up, CR Multiple, Bob's 27, Finition 121, Spider, Pirates.
- **Fête** (16) : Fun Mission, All Fives, Beyond Top, Kick Down, Two Line, Shanghai, Hyper Bull, Cache-cache, Killer, Treasure Hunt, Morpion, Baseball, Golf, Scram, Football, Patate chaude.
- **En ligne** : bientôt (un joueur chez lui avec sa cible).

Règles détaillées : `docs/regles_granboard.md`.

## Écran TV

Installe le même APK sur l'Android TV : elle démarre en mode écran et affiche un code. Sur le téléphone : icône TV › entre le code. La TV affiche la partie en grand et joue le son (au choix). Plusieurs écrans possibles.

## Personnalisation

- Style de la cible : Classique ou Pub en bois (menu ⋮ de l'accueil), aussi sur la TV.
- Sons, annonceur et musique réglables (icône haut-parleur).

## Sons et musique

Générés par `tools/make_sounds.py` (100 % synthèse). On peut les remplacer par un fichier du même nom (OGG conseillé).

| Fichier | Quand |
|---|---|
| `assets/sounds/hit.ogg` | Fléchette en simple |
| `assets/sounds/double.ogg` | Double |
| `assets/sounds/triple.ogg` | Triple |
| `assets/sounds/bull.ogg` | Bull |
| `assets/sounds/bust.ogg` | Bust, raté, mauvaise note |
| `assets/sounds/next.ogg` | Joueur suivant (sans son perso) |
| `assets/sounds/ton.ogg` | Manche de 100+, 5 marques et plus |
| `assets/sounds/crowd.ogg` | 180, White Horse, après la victoire |
| `assets/sounds/win.ogg` | Victoire, fin de leg |
| `assets/sounds/turn/*.ogg` | Sons du tour (fanfare, klaxon, laser, cloche, tambour, guitare, gong, sifflet, piano, arcade, sonar, coq) |
| `assets/music/menu.ogg` | Musique des menus (boucle) |

L'annonceur est la synthèse vocale française du téléphone.

## Serveur

Stats, note, classements, photos et sons des joueurs sont sur le serveur maison. Fichiers SQL dans `sql/`, à lancer dans l'ordre (tous relançables) :

1. `2026-11-11_comptes_stats.sql`
2. `2026-11-11_salon_tv.sql`
3. `2026-11-11_cricket.sql`
4. `2026-11-11_entrainement.sql`
5. `2026-11-11_photo_son.sql`

`psql -U postgres -d postgres -f fichier.sql`

## Build

- En local : `flutter run`
- APK : onglet **Actions → APK Android → Run workflow** (« publier » coché = release GitHub, proposée en mise à jour dans l'appli).
