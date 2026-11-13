# Changelog

## v0.6.6

- **Barre du haut de l'accueil allégée** : seulement la cible (pastille plus étroite), stats et classements, TV, sons et le profil (photo + rang) ; le reste est dans la tuile OPTIONS
- **Tuile OPTIONS** dans l'accueil (4 + 4 tuiles) : une page avec les joueurs du téléphone à gauche (fiche, ajout, gestion) et tous les réglages à droite (thème, style de la cible, sons, écran TV, cible Bluetooth, calibration, lumières, diagnostic, partage, mises à jour)
- **Annonceur** : après les 3 fléchettes du 01, il dit ce qu'il reste à faire (« triple 20, il reste 341 ») au lieu du total ; pareil en Finition 121, Spider et Kick Down (901 nouvelles annonces enregistrées)
- **Règles détaillées pour tous les jeux** (01, Cricket et ses variantes, Match, 17 entraînements, 16 jeux de fête), adaptées aux réglages choisis, dans une fenêtre qui défile avec des intertitres
- **Reprise d'une partie coupée** : la partie est gardée sur le téléphone après chaque fléchette ; si l'appli se ferme (batterie, Android, plantage), elle est proposée au lancement suivant (REPRENDRE / ABANDONNER), aussi pour un match de tournoi à la maison
- **Hors ligne** : pastille rouge dans l'accueil quand le serveur ne répond pas (avec le nombre de parties en attente), renvoi automatique dès le retour du réseau, message clair dans les classements
- **Écran TV sans internet** : le téléphone retrouve la TV ou la tablette sur le Wi-Fi de la maison et lui envoie la partie directement ; sans internet au démarrage, l'écran fait son propre code
- « Bot » devient « Joueur virtuel »
- **Écran TV en attente** : la cible ne tourne plus, elle flotte doucement ; à gauche les classements du serveur qui défilent (rang, moyenne 01, MPR, 180, meilleures fins), à droite les dernières parties des joueurs du téléphone
- **Nouvel écran de réglages** façon retransmission TV (toutes les tuiles et le tournoi à la maison) : bandeau doré, 3 colonnes Jeu / Règles / Joueurs avec une petite icône par variante, bandeau du bas avec le résumé de la partie et LANCER ; s'adapte au thème choisi
- **Favoris** : bouton FAVORI pour garder le jeu et ses règles (sans les joueurs), à part pour chaque tuile ; un toucher sur un favori le remet, appui long pour le retirer (8 par tuile)
- **Prononciation des pseudos** : un pseudo court ou en majuscules (« ced », « CED ») est lu « Ced » au lieu d'être épelé ; bouton **PRONONCIATION** dans la fiche du joueur pour écrire comment le dire (« Sède »), avec ÉCOUTER ; suivi par la TV
- **Annonceur** : il dit chaque fléchette (« triple 20 », « double 16 », « 25 », « bull », « raté » ; pas pour le triple 20 et les bulls, qui ont déjà leur animation avec son ; réglable dans Sons › Annoncer chaque fléchette), la fin conseillée au début du tour (« il te reste 40, double 20 »), « match point », le nombre de 180 de la soirée (« troisième 180 de la soirée »), les fins à 100 et plus (« fin à 121, plus haute fin de la soirée ») et, au Cricket, les derniers numéros à fermer (« plus que 15 et bull »)
- **Partager l'appli** (⋮ › Partager l'appli) : QR code à faire scanner, qui télécharge directement la dernière version (la release contient aussi l'APK sous le nom fixe `Foclaboard.apk`)
- Couleurs toutes différentes dans **tous** les jeux (01, Match, résultats, bandeau, TV, lumières de la cible) : le premier garde la couleur de son compte, les suivants qui ont la même, les invités et les bots reçoivent chacun une couleur libre (15 couleurs) ; la couleur du compte ne change pas

## v0.6.5

- Nouvelle tuile **TOURNOIS** : tournois en ligne à élimination directe (4, 8 ou 16 places). On crée le tournoi (nom, places, règles des matchs : 01, Cricket ou Match), les autres s'inscrivent, le créateur le lance (tirage au sort, exempts au 1er tour s'il manque des joueurs)
- Tableau du tournoi (quarts, demi-finales, finale) ; bouton **JOUER** pour ton match : ton adversaire reçoit le défi en ligne, le vainqueur passe tout seul au tour suivant ; le créateur peut déclarer un vainqueur (forfait)
- **Tournoi à la maison** (bouton « À LA MAISON ») : jusqu'à 16 joueurs du téléphone + invités, tirage au sort, les matchs se jouent l'un après l'autre sur la cible (« PROCHAIN MATCH … JOUER »), le vainqueur avance tout seul, forfait possible ; les stats des comptes sont enregistrées comme une partie normale
- **Tournoi sur la TV** (maison et en ligne) : la partie en cours pendant un match, le tableau avec le prochain match entre deux parties
- Pendant un match de tournoi, « PROCHAIN MATCH : X contre Y » (ou « vainqueur de ce match contre … ») en haut de l'écran, sur le téléphone et la TV
- **Lumières de la GranBoard 3s** (⋮ › Lumières de la cible) : contour à la couleur du joueur en cours, clignotement en face du numéro touché (1 à 3 fois selon simple / double / triple), vague sur un 180 ou une victoire, contour rouge sur un bust, numéros à viser allumés en orange (Cricket, fin en 01, entraînement) ; bouton ESSAYER ; protocole non officiel, à confirmer sur la cible
- **Bot** (bouton « Bot » à côté de « Invité », dans tous les jeux à la maison et les tournois à la maison) : il lance tout seul, son niveau part du rang de ses adversaires puis se cale sur ce qu'ils lancent vraiment pendant la partie, avec un léger rattrapage si l'écart devient trop grand ; « Annuler » revient à ta dernière action
- Nouveau thème **Fond d'écran** (⋮ › Thème de l'appli) : 9 images fournies, « Au hasard » (nouvelle image à chaque lancement) ou tes propres images du téléphone (MES IMAGES, appui long pour retirer) ; image assombrie qui zoome lentement, aussi sur la TV (sauf tes photos : image au hasard)
- Accueil : 4 tuiles en haut, 3 en bas

## v0.6.4

- **Rangs et stats façon GranBoard** : note sur 20 et rang (C, CC, B, BB, A, AA, S, SS, M, GM) en 01 (PPR), en Cricket (MPR) et général, calculés sur les 30 dernières parties (80 % meilleures ou 100 %), points requis pour le rang suivant, courbe des 30 dernières parties, analyse de l'entraînement (moyenne et meilleur score par jeu), tableau des rangs
- Touche un joueur dans les classements ou dans « En ligne » pour voir sa page de stats ; bouton **STATS ET RANG** dans la fiche de tes joueurs
- Le classement « NOTE » devient « RANG » (note sur 20)
- En partie (tous les jeux, TV comprise) : le rang et la note de chaque joueur s'affichent à côté de son nom, dans le tableau des scores, le panneau du joueur en cours et le bandeau « Au tour de »
- Corrigé : une partie terminée puis quittée avec le bouton retour (sans ouvrir les résultats) n'était pas enregistrée dans les stats
- Petits téléphones : barre de l'accueil qui ne déborde plus (pastille de la cible visible), noms des joueurs lisibles dans les tableaux des scores (réduits au lieu d'être coupés), tous les joueurs visibles en Freeze, historique du Cricket qui tient, réglages plus serrés
- Les fenêtres qui montent du bas (sons, TV, couleur, avatar, thème, style de la cible, son du tour) ont une petite croix pour fermer et s'ouvrent en grand
- Le profil principal est coché d'office quand aucun joueur n'est choisi
- Nombres à virgule (6,00 · 47,0) et « 1 manche » au singulier

## v0.6.3

- Son sur plusieurs appareils à la fois : téléphone, TV, tablette… on coche ceux qu'on veut (écran TV ou réglage des sons)
- 16 avatars sur le thème des fléchettes (cible, 180, couronne, trophée, pinte…) pour l'image de profil (la photo perso reste possible)
- 7 nouvelles couleurs de joueur + arc-en-ciel, choisies dans une grille
- Cricket : nouvelle vue **en lignes** (numéros en haut, une ligne par joueur, celle du joueur en cours en surbrillance et plus grande) ; bouton **VUE** en partie pour passer d'une vue à l'autre, choix gardé et envoyé à la TV
- Cricket : jusqu'à **10 joueurs**

## v0.6.2

- Nouveau son de victoire (« winner ») et 7 nouveaux sons du tour : Let's go, Yeah boy, Come on man, Come here, Victoire, Démon, Non !
- Nouveaux sons des vidéos triple 20, bull et d-bull
- Écran TV : les vidéos (triple 20, bull, d-bull, ton 80, hat trick…) s'affichent enfin aussi sur la TV
- L'annonceur dit « <pseudo>, à toi » à chaque tour (suivi du reste, de « spoiler » ou de la cible)
- Après une partie : boutons **MENU PRINCIPAL** et **REJOUER**
- Partie abandonnée : la musique des menus revient tout de suite
- Le téléphone ne se met plus en veille tant que l'appli est ouverte
- Nouvelle musique des menus : 3 morceaux qui s'enchaînent dans un ordre au hasard (morceau suivant à chaque retour au menu)
- Classements : bouton **TOUS / MES JOUEURS** (seulement les comptes enregistrés sur ce téléphone), choix mémorisé

## v0.6.1

- **Nouvelle voix de l'annonceur** : une voix française naturelle, enregistrée dans l'appli (scores, bust, restes, marques, victoires, noms des jeux, cibles…), identique sur le téléphone et la TV ; seuls les pseudos restent lus par la voix du téléphone
- Bandeau animé « AU TOUR DE … » avec la photo et la couleur du joueur suivant, après chaque « Suivant » (téléphone et TV, pas en solo) ; il ne bloque pas l'écran et s'efface dès la première fléchette
- Animations courtes (1,5 s, avec son) à chaque **TRIPLE 20**, **BULL** et **D-BULL**, sur le téléphone et la TV : deux fonds au hasard (flammes, onde de feu) ; la fléchette suivante ou un toucher l'arrête
- Cible : doubles, triples et bull plus larges (comme une cible électronique, plus les anneaux fins d'une cible anglaise) ; 6 styles de cible en plus (Électro, Néon, Or noir, Glace, Sakura, Braise), soit 8 au choix
- **Thèmes de l'appli** (accueil › ⋮ › Thème de l'appli) : Retransmission (noir et or), Néon, Sakura, Braise. Chacun a ses couleurs et son fond animé (projecteurs, grille, pétales, braises), visible derrière toutes les pages ; le thème est mémorisé et envoyé aux écrans TV reliés
- Accueil : tuiles en couleurs vives avec bordure lumineuse et illustration animée par jeu ; pages enchaînées en fondu
- **Animations des coups réussis** en plein écran, avec leur son, sur le téléphone et la TV : LOW TON (100 à 150), HIGH TON (151 à 179), TON 80 (180), HAT TRICK (3 bulls), 3 IN THE BLACK (3 bulls au centre), 3 IN A BED (3 fois le même double ou triple), WHITE HORSE (Cricket). Un style au hasard à chaque fois (glitch, néon, rose) ; on la passe en touchant l'écran ou en jouant la suite
- Démarrage : plus d'écran blanc (fond noir avec l'icône dès le lancement) et premier écran affiché sans attendre la voix et les sons, qui se préparent en arrière-plan (plusieurs secondes sur une Android TV)
- Réglages d'une partie : en venant d'une tuile de l'accueil, on ne voit plus que ce jeu (plus de choix 01 / Cricket / Match…), la colonne des joueurs est plus étroite et les réglages plus larges ; « Règles » passe en haut à droite

## v0.6.0

- **Jeu en ligne** (tuile « En ligne ») : 1 contre 1, chacun chez soi sur sa cible. Liste des joueurs en ligne (libre / en partie), bouton « Défier » puis choix du jeu (01, Cricket, Match, Entraînement, Fête à 2) et de celui qui commence ; l'adversaire reçoit le défi par-dessus n'importe quel écran et a 45 s pour accepter
- En ligne : la partie avance sur les 2 téléphones (et sur la TV de chacun), « À TOI » / « AU TOUR DE … » en haut, on ne peut jouer et annuler que ses propres actions, bandeau si l'adversaire ne répond plus ou quitte, « Reprendre la partie » si l'appli a été fermée, stats comptées comme une partie normale
- En ligne : **vidéo** de l'adversaire dans une vignette qu'on déplace au doigt ; en la touchant : couper la caméra, couper le micro, caméra selfie / arrière (pour montrer la cible), agrandir. Image et son passent en direct entre les 2 téléphones
- Bouton « Règles » pour chaque jeu : dans les réglages (à côté de « Jeu ») et en partie (icône ? en haut), avec les règles du jeu et des options choisies
- Nom de l'appli : Foclaboard
- Cricket : Standard, Cut Throat, Caché, Cut Throat caché, Wildcard, No Score, Triple Only, en individuel ou en équipes (Team Cricket, marques et points communs), limite de manches réglable (20 par défaut)
- Écran Cricket façon GranBoard : numéros au centre, une colonne par joueur (ou équipe) de chaque côté à sa couleur, numéros fermés par tous barrés, manches du joueur à gauche, MPR et fléchettes à droite, scores et joueurs en bas, grandes marques animées après la 3e fléchette ; cibles cachées « ? » découvertes en les touchant, numéros Wildcard qui changent à chaque manche, SPOILER en Cut Throat
- Annonces Cricket : marques de la manche, 5 marques et plus, White Horse
- MATCH : 3 à 13 legs, jeu de chaque leg au choix (01 ou Cricket), le joueur qui commence change à chaque leg, résultats aux legs avec moyenne et MPR
- Stats en ligne du Cricket : MPR (marques par manche), victoires, meilleure manche ; classements « Cricket MPR » et « Victoires Cricket » ; la note et la moyenne restent calculées sur le 01
- Entraînement : Count Up (et défi 99 fléchettes), Target 20, Target Bull, Choix de cible, Target Hat, Target Horse, Half It, Delta Shoot, Rotation, Shoot Force, Oniren, CR Count Up, CR Multiple, Bob's 27, Finition 121, Spider, Pirates ; zones à viser en surbrillance sur la cible, annonces (÷ 2, hat trick, araignée abattue, navire coulé…)
- Fête : Fun Mission, All Fives, Beyond Top, Kick Down, Two Line, Shanghai, Hyper Bull, Cache-cache, Killer, Treasure Hunt, Morpion, Baseball (grilles à l'écran pour Two Line, Morpion et Cache-cache)
- Meilleurs scores d'entraînement et de fête en ligne : classement par jeu (onglet « Entraînement ») et meilleurs scores sur le profil
- Nouveaux jeux : Cricket Mickey Mouse (20 à 12, Doubles, Triples, Bull), Golf (9 ou 18 trous), Scram (2 joueurs : l'un ferme, l'autre marque, puis on échange), Football (le bull prend le ballon, les doubles sont des buts), Patate chaude (toucher le numéro passe la bombe avant que la mèche s'éteigne)
- Nouvel accueil en grille de jeux : 6 tuiles de même taille (01, Cricket, Match, Entraînement, Fête, En ligne « bientôt ») ; en haut : état de la cible, bouton « Joueurs » (ajouter, gérer les comptes), TV, classements, sons et joueur
- Style de la cible au choix : Classique ou Pub en bois (menu ⋮ de l'accueil), aussi sur l'écran TV
- Premier lancement : création du profil principal du téléphone (ou « J'ai déjà un compte », ou plus tard) ; il s'affiche en haut de l'accueil, et un autre compte peut devenir profil principal depuis sa fiche
- Joueurs invités en couleurs différentes
- Photo de profil (appareil photo ou galerie, recadrée au carré) : affichée en partie, dans les résultats, les classements et sur l'écran TV
- Son du tour : chaque joueur choisit un son (fanfare, klaxon, laser, gong, coq… 12 au choix) ou enregistre sa voix (3 s) ; il est joué quand c'est son tour, puis l'annonceur dit son nom (aussi sur la TV)
- Tout s'affiche aussi sur l'écran TV

## v0.5.1

- Fins possibles : dès qu'on peut finir avec les fléchettes qui restent, la combinaison conseillée s'affiche en cases vertes (tableau classique des joueurs en Double Out), avec 2 autres possibilités en dessous
- La zone à viser pour la prochaine fléchette clignote sur la cible
- Aussi sur l'écran TV

## v0.5.0

- Écran TV : la même appli, installée sur une Android TV, démarre en mode écran. Elle affiche un code ; sur le téléphone, Accueil › icône TV › entre le code
- Le téléphone pilote tout, la TV affiche la partie en grand (cible animée, scores, annonces) puis les résultats
- Plusieurs écrans en même temps (ex. TV + tablette) : tous affichent la partie
- Choix de l'appareil qui joue le son (annonceur, bruitages, musique) : téléphone ou l'un des écrans, dans la fenêtre Écrans ou les réglages du son. Une TV reliée prend le son par défaut
- Liaison par le serveur maison, en temps réel (prépare le jeu à distance)
- Un téléphone ou une tablette peut aussi servir d'écran (icône TV › « Cet appareil devient un écran »)

## v0.4.0

- Comptes joueurs sur le serveur maison : pseudo + code à 4 chiffres, mémorisés sur le téléphone, utilisables sur n'importe quel téléphone
- Statistiques en ligne, note de niveau (moyenne des 20 dernières parties) avec classe D à MASTER, rang
- Classements de tous les joueurs : note, victoires, moyenne, 180, meilleure fin, meilleure manche
- Joueurs invités (sans stats)
- Parties envoyées au serveur, ou plus tard si hors ligne
- Toute l'appli en paysage
- Grande cible animée en partie : fléchettes plantées, onde d'impact, zones touchées qui pulsent, éclair sur un bust ou une victoire
- Calibration : boutons toujours visibles

## v0.3.3

- GranBoard 3s reconnue sans calibration : mêmes codes que la Dash, la bordure extérieure compte comme fléchette ratée
- Les caractères invisibles envoyés par certaines cibles sont ignorés

## v0.3.2

- Calibration : étape « bordure extérieure » à la fin (GranBoard 3s). Une fléchette dans la bordure compte automatiquement comme ratée (0 point).

## v0.3.1

- Calibration des cibles : Accueil › ⋮ › « Calibrer cette cible » (pour les GranBoard autres que la Dash, ex. 3s). La table est mémorisée pour chaque cible, et peut être copiée pour être intégrée à l'appli.
- Message en partie quand une zone n'est pas reconnue

## v0.3.0

- Nouveau look façon retransmission TV : noir et or, police sport, nouvelle icône
- Cible dessinée qui montre où sont tombées les fléchettes de la manche
- Annonces animées : 180, scores à 100+, BUST, VICTOIRE
- Annonceur en français : score de la manche, « Cent quatre-vingts ! », bust, joueur suivant et ce qu'il lui reste, victoire
- Bruitages (impact, double, triple, bull, bust, public, fanfare) et musique dans les menus
- Réglages des sons : annonceur, effets, musique, volume
- Résultats avec podium

## v0.2.0

- Parties X01 : 301, 501, 701, 901
- Freeze 01 en 2 équipes (une équipe en retard est gelée ❄ et ne peut pas finir)
- Options : Open / Double / Master In, Open / Double / Master Out, bull 25/50 ou 50/50, limite de manches
- Bust, bouton Raté, Annuler, joueur suivant par le bouton de la cible
- Suggestion de fin (checkout)
- Profils de joueurs avec statistiques : moyenne, meilleure fin, meilleure manche, 100+, 180, historique
- Reconnexion automatique à la dernière cible, écran de diagnostic
- L'écran reste allumé pendant une partie

## v0.1.0

- Connexion Bluetooth à la cible GranBoard
- Affichage de chaque fléchette (zone et score)
- Mise à jour dans l'appli : vérification au lancement + bouton dans l'écran de scan
