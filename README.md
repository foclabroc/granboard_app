# Foclaboard

**Foclaboard** : appli Flutter (Android) de fléchettes pour cible électronique **GranBoard** (Dash, 3s), connectée en Bluetooth LE. Comptes, stats, rangs et classements sur le serveur maison. La même appli sert d'écran sur une Android TV ou une tablette.

## Utilisation

L'appli se joue en paysage, téléphone posé à côté de la cible.

1. Ferme l'appli GranBoard officielle (la cible n'accepte qu'une connexion BLE).
2. **Premier lancement** : crée ton profil principal (pseudo + code à 4 chiffres), ou « J'ai déjà un compte », ou « Plus tard ».
3. **Cible** (pastille en haut de l'accueil) → touche la GranBoard. Ensuite l'appli s'y reconnecte toute seule.
4. **Options** (tuile de l'accueil) : joueurs du téléphone, thème, style de cible, son, écran TV, calibration, lumières de la 3s, partage de l'appli (QR code), mise à jour.
5. **Fiche d'un joueur** : photo ou avatar, son du tour (21 sons ou sa voix enregistrée), couleur, cible préférée, prononciation du pseudo, stats et rang. Les invités et les joueurs virtuels jouent sans stats.
6. Choisis un jeu sur l'accueil, puis les règles et les joueurs (★ FAVORI garde tes réglages préférés).
7. Le bouton de la cible (ou « Suivant ») passe au joueur suivant ; « Raté » pour une fléchette hors cible ; « Annuler » revient en arrière. Une partie coupée peut être reprise au lancement suivant.

## Jeux

Accueil : **01**, **Cricket**, **Party**, **Tournois** / **Medley**, **Entraînement**, **En ligne**, **Options**.

- **01** : 301 / 501 / 701 / 901, Freeze ou Double en 2 équipes, In / Out Open / Double / Master, bull 25/50 ou 50/50, limite de manches ; fins possibles affichées.
- **Cricket** : Standard, Cut Throat, Caché, Cut Throat caché, Wildcard, No Score, Triple Only, Mickey Mouse, en individuel ou en équipes, jusqu'à 10 joueurs ; vue classique ou en lignes.
- **Medley** : 3 à 13 legs, chaque leg au choix en 301, 501, 701, 901 ou Cricket.
- **Entraînement** (18) : Count Up, Target 20 / Bull / Hat / Horse, Choix de cible, Half It, Delta Shoot, Rotation, Shoot Force, Oniren, CR Count Up, CR Multiple, Bob's 27, Finition 121, Spider, Pirates, Contre la montre.
- **Party** (19) : Fun Mission, All Fives, Beyond Top, Kick Down, Two Line, Shanghai, Hyper Bull, Cache-cache, Killer, Treasure Hunt, Morpion, Baseball, Golf, Scram, Football, Patate chaude, Le Chat et la Souris, Paint, Bowling.
- **Tournois** : élimination directe, à la maison (2 à 16 joueurs) ou en ligne.
- **Joueur virtuel** : un bot qui se cale sur le niveau des joueurs humains.

Règles détaillées : bouton **Règles** dans l'appli, et `docs/regles_granboard.md`.

## Écran TV

Installe le même APK sur l'Android TV (ou une tablette en « mode écran ») : elle affiche un code. Sur le téléphone : bouton **TV** › entre le code. L'écran montre la partie en grand, les bandeaux, les vidéos des coups et des récompenses, et joue le son et la musique (au choix, sur un ou plusieurs appareils). Plusieurs écrans possibles, par le serveur et par le Wi-Fi local.

Dans la fenêtre TV du téléphone :
- **Le son sort sur** : téléphone et/ou écrans.
- **Animations complètes sur l'écran** : coupé par défaut (plus fluide sur une TV peu puissante).
- **Caméra sur un écran** : filmer la cible avec une tablette ou le téléphone et l'afficher sur la TV.

## Jeu en ligne

1 contre 1 ou 2 contre 2, chacun chez soi sur sa cible. Tuile **En ligne** : la liste des joueurs qui ont l'appli ouverte ; **Défier**, choisis le jeu, l'autre a 45 s pour accepter. La vidéo de l'adversaire est dans une vignette (déplaçable ; caméra, micro, caméra arrière). Il faut un profil sur chaque téléphone.

La vidéo passe en direct entre les 2 téléphones (WebRTC) ; le serveur ne fait que la mise en relation. Si elle ne s'établit pas sur certains réseaux (4G, certaines box), il faut ajouter un relais TURN dans `gb_config` (clé `ice`).

## Personnalisation

- **Thèmes** : Retransmission, Néon, Sakura, Braise, Glace, Pub, Synthwave, Abysses, Galaxie, Carbone, Fond d'écran (images fournies ou photos du téléphone).
- **Cibles** : 9 styles (Réaliste, Classique, Pub en bois…), un par joueur possible.
- **Annonceur** : voix enregistrée (fléchettes, ce qu'il reste, fins, 180 de la soirée…), chambrage, commentaires ; tout est réglable (icône haut-parleur).
- **Lumières de la 3s** : la cible s'allume selon le jeu (à confirmer sur une vraie 3s).

## Sons, musique et vidéos

| Fichier | Quand |
|---|---|
| `assets/sounds/*.ogg` | Bruitages (fléchette, double, triple, bull, bust, ton, 180, victoire) |
| `assets/sounds/turn/*.ogg` | Sons du tour des joueurs (21) |
| `assets/music/menu1.ogg` … `menu5.ogg` | Musique des menus (5 morceaux Pixabay enchaînés au hasard, même morceau sur le téléphone et la TV) |
| `assets/voice/` | Annonces enregistrées (`tools/make_voice.py`, voix Piper) |
| `assets/hits/` | Vidéos des coups T20 / Bull / Double Bull (`tools/make_hits.sh`) |
| `assets/awards/` | Vidéos des récompenses (Ton 80, Hat Trick, 3 in the Black…) |

## Serveur

Stats, rangs, classements, photos, sons, cibles des joueurs, écran TV, jeu en ligne et tournois sont sur le serveur maison. Fichiers SQL dans `sql/`, à lancer dans l'ordre (tous relançables) :

1. `2026-11-11_comptes_stats.sql`
2. `2026-11-11_salon_tv.sql`
3. `2026-11-11_cricket.sql`
4. `2026-11-11_entrainement.sql`
5. `2026-11-11_photo_son.sql`
6. `2026-11-12_en_ligne.sql`
7. `2026-11-12_rangs.sql`
8. `2026-11-12_tournois.sql`
9. `2026-11-13_double.sql`
10. `2026-11-13_cible.sql`
11. `2026-11-13_camera_ecran.sql`

`psql -U postgres -d postgres -f fichier.sql`

## Build

- En local : `flutter run`
- APK : onglet **Actions → APK Android → Run workflow** (« publier » coché = release GitHub, proposée en mise à jour dans l'appli).
