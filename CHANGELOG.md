# Changelog

## v0.6.27

- **11 nouveaux jeux Party**, chacun avec son écran animé à la place de la cible (la cible reste en petit à côté, avec le joueur en cours) :
  - **Tir à la corde** (2 joueurs ou 2 camps) : corde tressée qui vibre, nœud lumineux qui glisse vers le camp qui tire.
  - **Coffre-fort** : porte blindée, molette qui tourne, code à descendre à 0 pile ; la porte s'ouvre sur les lingots, ou l'alarme hurle.
  - **Fight Club** (2-4) : ring sous les projecteurs, cartes des combattants avec leur photo et leur barre de vie, coups, soins, onde de choc, K.O.
  - **Puissance 4** : grille percée, les pions tombent avec rebond, l'alignement gagnant brille.
  - **Serpents et échelles** : plateau 10 × 10, pions qui sautent case par case, échelles et serpents animés.
  - **Boules** : gazon tondu, les boules roulent jusqu'au cochonnet, les boules qui marquent brillent en fin de mène.
  - **Conquérant** (2-4) : la cible devient une carte de 20 régions et un hub, boucliers, régions à portée qui clignotent.
  - **Test Match** (le cricket, le sport) : terrain vu de dessus, tableau d'affichage, balle frappée, piquets qui volent.
  - **Snooker** : table et drap, 15 rouges numérotées, couleurs sur leurs mouches, billes qui filent dans les poches, fautes.
  - **8 Ball Pool** : table néon, 7 billes chacun, série qui continue tant qu'on empoche, la 8 au bull (option difficile).
  - **Zombies** (coopératif) : cimetière la nuit, zombies qui titubent vers la base avec leur cible (T17, D8…), giclées et morsures.
- Règles détaillées de chaque jeu (bouton ?), joueur virtuel, TV et écran allégé pris en charge.
- **Cibles VDarts** (H2, H2L, H3, H3L, H4, H4L, MINI) reconnues et décodées, avec leur ouverture propre à chaque modèle (protocole relevé dans l'appli DartMate) ; jamais essayé sur une vraie VDarts. Page Diagnostic : étapes de l'ouverture et octets reçus.
- Téléphones à encoche (caméra dans l'écran) : l'affichage est maintenant le même en paysage gauche et en paysage droite. Avant, tout l'écran était décalé du côté opposé à la caméra et changeait de côté quand on retournait le téléphone ; maintenant la même marge est laissée des deux côtés et chaque écran est centré.
- Configuration d'une partie, Options, Tournois et Salon : le bandeau du haut et la barre du bas vont jusqu'aux bords de l'écran, derrière la caméra ; seuls les textes et boutons restent dans la zone sûre.
- **Animation du contour de la cible** au choix (Options › Animation du contour) : 12 styles avec aperçu animé (Tranquille = l'ancienne, Rapide (par défaut), Turbo, Double comète, Chenillard, Accélération, Ping-pong, Respiration + éclair, Arc-en-ciel, Remplissage, Triple comète, Étincelles) ; s'applique sur le téléphone et l'écran TV, gardé sur le compte.
- **GranBoard 3s** : hors partie, les numéros de la cible jouent l'animation choisie (interrupteur « Animation d'attente » dans Lumières de la cible) ; nouveau réglage « Couleur des numéros » (valeur 1-30, chaque essai allume les 20 numéros 2 s) pour trouver les couleurs : la valeur 5 utilisée jusqu'ici donne du bleu / blanc, pas de l'orange.

## v0.6.26

- Fiche d'un joueur réorganisée en onglets : à gauche, la photo, le rang et 3 onglets fixes (plus besoin de défiler sous la photo) :
  - **STATS** : stats 01 et Cricket, meilleurs scores d'entraînement, bouton vers le rang détaillé ;
  - **PERSONNALISER** : couleur, son, cible, prononciation, profil principal et retirer, en grille avec leur valeur actuelle ;
  - **PARTIES** : dernières parties + bouton vers tout l'historique.
- Fenêtre « Ajouter des joueurs » : les joueurs déjà dans la partie sont affichés en haut (« DANS LA PARTIE · ORDRE DE JEU »), en pastilles compactes à leur couleur : numéro d'ordre, photo (petit symbole pour un invité), nom, croix pour le retirer ; 10 joueurs tiennent sur 2 lignes. Le bouton TERMINÉ passe en haut à droite, toujours visible.
- Tuiles en **bandes de couleur** : la couleur part de la gauche et se fond dans le panneau, la tuile choisie est remplie et entourée de blanc ; les couleurs suivent un dégradé du haut vers le bas de la liste (or → orange → rouge → cramoisi → violet → bleu). Partout où on choisit le jeu (01, Cricket, Medley, Entraînement, Party, tournois, défis en ligne ; Freeze en bleu glace), dans les Options et dans PERSONNALISER de la fiche joueur (RETIRER en rouge).

## v0.6.25

- **Regarder les parties à la maison en direct** : quand un joueur joue chez lui (seul ou avec d'autres, entraînement, Party, tournoi maison…), les autres joueurs le voient « EN PARTIE » dans l'onglet En ligne avec un bouton **REGARDER** : sa partie s'affiche comme sur l'écran TV (cible, scores, ses couleurs), mise à jour en direct. L'état final reste visible 20 s, puis la partie disparaît.
  - Il suffit qu'un compte du téléphone joue (les invités et les joueurs virtuels sont montrés avec lui) ; une partie avec seulement des invités n'est pas diffusée.
  - Tous les joueurs du serveur peuvent regarder (plus seulement les amis), aussi pour les parties en ligne ; un joueur bloqué (dans un sens ou l'autre) ne peut pas.
- Serveur : l'onglet En ligne montre de nouveau tous les comptes (avant, seulement ceux connectés), la liste d'amis, les réglages du compte et « Regarder » une partie en ligne remarchent (fonctions du serveur en erreur).

## v0.6.24

- Partager l'appli : bouton « Envoyer par SMS » sous le QR code (ouvre les SMS avec un message et le lien de téléchargement, il ne reste qu'à choisir le contact).
- Nouveau jeu de fête **Grand Prix** (2 à 6 joueurs, course en 9, 12 ou 15 cases) : chaque pilote tire au sort un numéro de la cible ; toucher son numéro fait avancer sa voiture (simple 1, double 2, triple 3), le bull donne un turbo (+2), toucher le numéro d'un adversaire le fait reculer d'une case (tête-à-queue). Le premier au drapeau à damier gagne (40 manches maxi).
  - Piste vue de dessus avec une ligne par joueur (numéro, nom, position), cases numérotées depuis le départ, voitures de F1 qui accélèrent (flammes, traînée) ou partent en tête-à-queue (fumée), badge P1 pour le leader ; même écran sur la TV.
  - Thème « Circuit » (asphalte, vibreurs rouge et blanc, traits de vitesse, damier).
  - Annonces enregistrées : « Turbo ! », « Tête-à-queue pour … », « … prend la tête ! », « Drapeau à damier ! ».

- Thème propre à chaque jeu (couleurs + fond animé), dans les réglages du jeu, pendant la partie, aux résultats et sur l'écran TV ; les menus gardent le thème choisi pour l'appli :
  - 01 « Arène » (rouge et or, anneaux d'une cible géante, projecteurs) ; Cricket « Ardoise » (tableau noir, marques à la craie) ; Medley « Duel » (deux camps bleu / violet) ; Entraînement « Mire » (viseur et radar turquoise) ; Party « Confettis » ;
  - jeux phares : Bowling (pistes en bois, quilles, boules qui roulent, néons), Golf « Green » (ciel, soleil, collines, drapeau, balle en vol), Football « Stade » (pelouse rayée, lignes, projecteurs, ballon qui roule), Le Chat et la Souris « Pattes » (le chat poursuit la souris, yeux qui brillent dans le noir), Paint « Atelier » (taches qui éclatent et coulent), Contre la montre « Chrono » (cadran lumineux, trotteuse avec traînée, damier).
  - fonds franchement colorés et animés (cible géante qui tourne et étincelles en 01, tableau de Cricket qui se remplit à la craie, éclair entre les 2 camps du Medley, radar et cibles qui clignotent en entraînement, faisceaux de boîte de nuit et serpentins en Party).
- Joueur suivant (bouton rouge de la cible ou bouton à l'écran) : les annonces en cours ou en attente (« il reste … », commentaires) sont coupées, le son du joueur suivant et son bandeau partent tout de suite.
- Bandeau « au tour de » synchronisé avec le son du joueur : il apparaît au moment où le son part (avant, il s'affichait tout de suite et le son pouvait arriver plusieurs secondes après).

## v0.6.23

- Démarrage : petite barre de chargement avant l'accueil, le temps de tout préparer pour que la partie ne cale pas :
  - annonces enregistrées recopiées une fois hors de l'appli (avant, chaque morceau était recopié à sa 1re lecture à chaque lancement, d'où des annonces en retard en début de soirée) ; refait seulement quand les voix changent ;
  - bruitages et sons des joueurs chargés d'avance ;
  - photos, avatars et fond d'écran décodés d'avance (et les photos des joueurs au début de chaque partie) ;
  - effets graphiques (cible animée, grand texte des coups) dessinés une fois derrière la barre.
- Pseudos : chaque pseudo est enregistré une fois par la voix de synthèse puis rejoué comme les autres annonces (plus d'attente de la voix de synthèse à chaque « X, à toi », surtout sur la TV).
- Écran TV : moteur de rendu Skia par défaut (bien plus fluide qu'Impeller sur la TV de test), aussi pour les TV qui se mettent à jour ; l'interrupteur de la fenêtre TV du téléphone devient « Moteur de rendu Skia » allumé d'office (le couper repasse en Impeller).
- Écran TV : si le décodeur de la TV n'arrive pas à lire une vidéo, la même vidéo repart aussitôt en décodage logiciel, sans message d'erreur (les suivantes restent en logiciel).
- Son : nouveau réglage « Annoncer le joueur » (« Ana, à toi » à chaque tour). Coupé : seulement le son du joueur, le bandeau et ce qu'il lui reste (« Il te reste 40, double 20 »). Suivi par les écrans TV.
- Partie abandonnée : la TV ne dit plus « X, à toi » après coup (annonces en attente, son du joueur et bandeau annulés). L'annonce du tour attend au plus 2,5 s la fin de l'annonce précédente (4 s avant).

## v0.6.22

- Écran TV 4K : l'appli passe l'écran en 1080p au démarrage (4 fois moins de pixels à dessiner, la TV agrandit l'image). Rien ne change sur les TV dont l'interface tourne déjà en 1080p (la plupart).
- Écran TV : vidéos lues par le décodeur de la TV (plus léger) ; si une vidéo ne se lit pas, l'écran repasse tout seul au décodeur logiciel et le garde. Réglage « Vidéos en décodage logiciel » dans la fenêtre TV du téléphone.
- Écran TV : réglage « Moteur de rendu Skia » dans la fenêtre TV du téléphone (au lieu d'Impeller, à essayer si l'écran saccade ; l'écran redémarre tout seul). Moteur, décodeur et mode d'affichage écrits en petit en bas de l'écran d'attente.
- Écran TV : moins de travail à chaque fléchette : l'écran de jeu n'est plus reconstruit quand l'état reçu ne change que la musique, le son ou la caméra ; bandeau du haut et écran de jeu dans des couches séparées ; « Ensuite » en 01 recalculé seulement au changement de joueur ; chrono de « Contre la montre » dans sa propre couche.

## v0.6.21

- Vérification complète, corrections : en salon, la cible de la maison qui remplace une maison partie ne compte plus de fléchettes pour l'absent ; au retour d'une partie de salon, on rejoint la nouvelle partie si l'hôte l'a déjà relancée (au lieu de rouvrir le salon et de bloquer cette partie) ; une seule partie ouverte à la fois par-dessus le salon ; plus de plantage possible si on ferme l'écran pendant le chargement des réglages, la liaison TV, l'enregistrement de la voix ou le réglage des lumières ; numéros des cases allumées mis en cache (effets plus légers sur la TV).

## v0.6.20

- Cible : message de connexion lisible (« Cible introuvable : allume-la et rapproche-toi »…) au lieu de l'erreur technique Flutter Blue Plus.
- Annonceur, nouveaux commentaires : compliment après un ton (« Belle volée ! », « Magnifique ! » à 140+), série (« Deuxième ton d'affilée ! »), « X prend la tête ! » (01 et Cricket à points), « Le double se refuse » quand une fin possible est ratée, « plus que double 16 » en cours de tour, « Tout est fermé ! » au Cricket, « Leg décisif ! » au Medley, « Neuf fléchettes en vue ! » en 501. Réglage « Commentaires et chambrage » (ex-« Chambrage »). 17 nouvelles annonces enregistrées (voix Piper).

## v0.6.19

- Mise à jour : « Ouvrir » après l'installation ne lance plus une 2e Foclaboard à côté de l'ancienne (une seule tâche pour l'appli).
- Cible : jeux de lumière rapides sur les cases des numéros — simple : la case flashe et une onde part ; double : 2 ondes font le tour ; triple : la case clignote en blanc puis grande onde ; bull : tout l'anneau tourbillonne ; joueur suivant : une comète à sa couleur fait le tour ; bust : rouge qui alterne une case sur deux ; victoire : arc-en-ciel qui court ; attente : petite comète plus vive. Aussi sur la TV (halo flou coupé en mode allégé).
- Cible : plus d'anneau de diodes autour ; les cases des numéros vont jusqu'au bord et ont exactement la largeur de leur segment.
- Cible : la case à viser (chemin de finish, numéros du Cricket, zones des entraînements) s'allume à la couleur du joueur en cours : voile qui pulse et bord lumineux sur la zone, case du numéro pleine avec le numéro en blanc bien lisible ; plus d'encadrement blanc.
- Écran TV : le chemin de finish du 01 (et des legs de 01 du Medley) est affiché 2 fois plus grand, cases plus marquées.
- Fluidité sur la TV : la cible qui flotte sur l'écran d'attente, le bandeau « au tour de », le grand texte des coups et les grandes marques du Cricket ne redessinent plus tout l'écran à chaque image ; ombres floues retirées en mode allégé ; vidéos des coups réencodées en 960 × 540 (2 fois plus légères à décoder, 54 → 27 Mo).
- En ligne : rubrique « SALONS OUVERTS (n) » toujours visible, avec un message quand aucun salon public n'est ouvert (les salons privés ne s'y affichent pas).
- Sous-menus des tuiles, colonne JOUEURS allégée : elle ne montre plus que les joueurs choisis (à glisser pour l'ordre), un bouton AJOUTER et la corbeille « Tout vider ». AJOUTER ouvre une fenêtre avec mes joueurs (un toucher les ajoute), Invité, Joueur virtuel et Nouveau joueur ; elle reste ouverte pour en ajouter plusieurs. L'étiquette VIRTUEL disparaît (l'avatar robot suffit).
- En ligne : le défi (1 contre 1 et double), le choix du jeu d'un salon et la création d'un tournoi en ligne passent au même affichage en tableau que les parties à la maison. Le bandeau indique « DÉFI · CONTRE SOPHIE », puis trois colonnes (choisir le jeu, règles, adversaire / joueurs du salon / tournoi) et une barre du bas avec le résumé et le bouton DÉFIER, CHOISIR ou CRÉER.

## v0.6.18

- Salons en ligne : de 2 à 4 maisons, chacune sur sa cible avec 1 à 4 joueurs (comptes du téléphone ou invités). Le salon est privé (sur invitation) ou public (visible dans la liste « Salons » de l'écran En ligne). L'hôte choisit le jeu, l'ordre (maisons en alternance ou au hasard) et lance la partie, qui s'ouvre chez tout le monde. On revient au salon après la partie.
- Vidéo à plusieurs : une vignette par autre maison, jusqu'à 3, image allégée à partir de 3 maisons.
- Si une maison quitte une partie de salon, la partie continue : ses joueurs passent leur tour. Elle s'arrête quand il ne reste qu'une maison.
- Relais TURN sur le serveur maison (`tools/turn`, identifiants temporaires donnés par le serveur) : la vidéo passe aussi en 4G et derrière les box strictes. SQL `2026-11-17_salons.sql`

## v0.6.17

- Sous-menus des tuiles : présentation en tableau, bandeau de configuration et nombre de joueurs, avec les couleurs du thème choisi.
- Inclut aussi les nouveautés de la 0.6.16, qui n'a pas été compilée :
  - Tournois : onglets maison et en ligne, création selon le mode choisi, cartes avec aperçu du tableau et prochain match personnel à la maison lorsqu'il est connu.
  - Historique des parties dans les statistiques, avec adversaires, gagnant et résultats ; les parties en ligne sont reliées entre les deux téléphones.
  - Photos des joueurs rafraîchies après une remise à zéro du serveur ; en Freeze, un nombre impair de joueurs affiche un message au lieu d'un écran blanc.
  - En ligne : liste des joueurs, demandes d'ami, recherche et filtres, spectateur, revanche, rendez-vous, « ne pas déranger », blocage, phrase de profil et titres.
  - Réglages du téléphone sauvegardés sur le compte principal et récupérables sur un nouvel appareil.

## v0.6.16

- Sous-menu Tournois : onglets maison et en ligne, création selon le mode choisi, cartes avec aperçu du tableau et prochain match personnel à la maison lorsqu'il est connu.
- Stats d'un joueur : HISTORIQUE DES PARTIES (toutes les parties enregistrées, les plus récentes d'abord, 30 par page avec VOIR PLUS : jeu, date, avec qui, qui a gagné, moyenne / MPR / score ; parties en ligne marquées EN LIGNE, avec l'adversaire : chaque téléphone relie sa partie à la salle, `gb_on_link`). SQL `2026-11-17_historique.sql`
- Photos des joueurs relues en entier à chaque lancement : après la remise à zéro du serveur, les nouveaux comptes ont repris les mêmes numéros que les anciens et le téléphone pouvait garder une ancienne photo (ou aucune) ; une partie en attente qui pose problème n'empêche plus la mise à jour des profils et des photos
- 01 : écran blanc en cochant Freeze avec un nombre impair de joueurs (équipes inégales) ; maintenant le message « Les 2 équipes doivent avoir autant de joueurs » s'affiche. Aussi : étiquettes VIRTUEL / INVITÉ qui débordaient dans la colonne des joueurs en équipes
- En ligne : tous les joueurs du serveur sont listés avec leur état (libre, en partie, hors ligne), filtres TOUS / EN LIGNE / AMIS et recherche ; demandes d'ami (+ AMI, ACCEPTER / refuser, étoile = ami, toucher pour retirer) ; la tuile En ligne de l'accueil annonce les demandes reçues. SQL `2026-11-15_amis.sql`
- En ligne, la suite (SQL `2026-11-15_social.sql`) : dernière connexion des absents (« vu il y a 2 h ») ; PRÉVENIR = dire à un joueur absent ou occupé qu'on veut jouer (il le voit à sa prochaine connexion) ; bilan contre chaque ami (3 V · 2 D, parties à la maison et en ligne) ; REGARDER la partie en ligne d'un ami ; REVANCHE à la fin d'une partie en ligne (1 contre 1, celui qui commençait joue en second) ; « Ne pas déranger » (visible, sans défi) ; bloquer un joueur ; rendez-vous proposés à un joueur (jour et heure, à accepter) ; phrase du profil et titre gagné par les exploits (Roi du 180, Grand finisseur…) ; filtre AMIS dans les classements
- Réglages gardés sur le compte du profil principal (Options › Mes réglages sur mon compte) : thème, style de cible, sons et annonceur, prononciations, favoris et derniers réglages des parties, vue du Cricket, option AUTO, lumières, fond d'écran et ses photos. Envoyés tout seuls quand on quitte l'appli ; sur un nouvel appareil où on se connecte, l'accueil propose de les reprendre. SQL `2026-11-15_reglages.sql`

## v0.6.15

- Option AUTO (bouton en haut de chaque partie, gardée sur le téléphone) : joueur suivant tout seul 5 s après les 3 fléchettes, avec un compte à rebours (le toucher coupe AUTO) ; attend la fin d'une vidéo de récompense
- Lumières de la 3s : les numéros à viser et le contour sont renvoyés après chaque fléchette (l'animation de la cible les effaçait), restent allumés après les 3 fléchettes jusqu'au joueur suivant, et en 01 sans fin possible le 20 est allumé
- Bouton Accueil : plus aucun son quand l'appli passe en arrière-plan (musique en pause, reprise au retour) ; sur Android TV l'appli se ferme au lieu de tourner cachée derrière l'accueil de la TV

## v0.6.14

- Fin de partie : les résultats s'ouvrent tout seuls (moins d'une seconde après la dernière fléchette), plus besoin de toucher « Résultats »

## v0.6.13

- Écran TV qui alterne entre la partie et l'écran d'attente (et cible de l'écran d'attente qui change sans arrêt) : un 2e appareil qui croyait encore piloter l'écran (tablette passée en mode écran, ancien téléphone) lui envoyait son écran d'attente par le Wi-Fi. L'écran n'écoute plus sur le Wi-Fi que l'appareil qui le pilote d'après le serveur (tous si le serveur ne répond pas), et une appli en mode écran n'envoie plus rien
- Écran TV qui « saute » comme une coupure : la vidéo d'un coup (T20, bull) ou d'une récompense posait un voile noir dès son départ, même quand le décodeur de la TV échouait juste après. Elle ne s'affiche plus que quand la lecture avance vraiment ; sinon rien ne change à l'écran (le son habituel est joué)

## v0.6.12

- Vidéos sur la TV : « format accepté mais décodeur en échec » sur la TCL. Sur Android TV, les vidéos passent maintenant par le décodeur logiciel (le matériel en secours), et si un décodeur ne démarre pas, le suivant est essayé au lieu d'abandonner (copie locale de `video_player_android` dans `packages/`)
- Message d'erreur vidéo plus précis (nom du décodeur et cause), si ça échoue encore
- L'annonce du joueur suivant attend la fin de « il reste … » (4 s au plus) au lieu de la couper (joueur virtuel, bouton « suivant » appuyé vite) ; elle saute si le joueur a déjà lancé
- Cricket : la vue (classique / lignes) change tout de suite sur la TV, sans attendre la fléchette suivante
- Choix des joueurs : bouton « Tout vider »
- Tablette en mode écran : bouton « Mode téléphone » aussi sur l'écran d'attente (une fois reliée, l'écran du code n'apparaissait plus)

## v0.6.11

- Musique des menus : quand le son est ajouté à un appareil, le morceau repart bien au début sur tous (l'écran continuait là où il en était : Android ignore la relance du même fichier)
- Vidéos (récompenses et coups) réencodées au format H.264 « Main » niveau 3.1, plus simple à lire pour les TV (erreur MediaCodecVideoRenderer sur la TCL)
- Écran TV : message d'erreur vidéo raccourci à l'essentiel (cause, caméra en cours), une seule fois par soirée pour la même erreur
- Nouvelles fléchettes sur la cible : vues de face, 4 ailettes fines à la couleur du joueur avec contour sombre, numéro 1/2/3 au centre (toutes les cibles, téléphone et TV)
- 6 nouveaux thèmes avec leur fond animé : Glace (neige), Pub (lumières de bar floues), Synthwave (soleil rayé + sol quadrillé), Abysses (bulles et rais de lumière), Galaxie (étoiles qui scintillent + étoile filante), Carbone (fibre de carbone + reflet)
- Accueil : tuiles dans un nouvel ordre (01, Cricket, Party, Tournois / Medley, Entraînement, En ligne, Options) ; Fête s'appelle Party et Match s'appelle Medley (accueil, réglages, titres, résultats, annonce de début « Medley en N legs » enregistrée)
- Medley : chaque leg a son propre jeu (301, 501, 701, 901 ou Cricket), par exemple 301 - Cricket - 501 ; les règles 01 (début, fin, bull) restent communes
- Cricket (vue classique) : en bas, une case par joueur à sa couleur au lieu d'une bande sur toute la largeur ; celle du joueur en cours plus vive, bordée de blanc et lumineuse
- Cricket (vue en lignes) : trait fin aussi entre le nom et le 20, et entre le bull et les points
- Écran TV plus fluide : animations allégées par défaut (fond du thème fixe, cible sans anneau de LED, reflet ni zones qui pulsent ; les fléchettes, bust, victoire, vidéos et bandeaux restent animés) ; interrupteur « Animations complètes sur l'écran » dans la fenêtre TV du téléphone
- 2 musiques des menus en plus (« Chill » d'AtlasAudio et « Upbeat Chill » de VelarioMusic, Pixabay, fournies par foclabroc) : 5 morceaux enchaînés au hasard
- Sons du joueur « Malcolm » et « Poupipou » (extraits fournis par foclabroc)
- Android TV : la bannière de l'appli affiche FOCLA BOARD (elle disait encore GRAN BOARD)

## v0.6.10

- Bandeau « AU TOUR DE » aussi pour le tout premier joueur de la partie (téléphone et écran TV)
- Partie abandonnée : l'écran TV quitte la partie tout de suite (avant : il y restait jusqu'au retour à l'accueil)
- Musique des menus : l'écran TV / la tablette joue le même morceau que le téléphone ; quand le son est ajouté au téléphone, le morceau repart au début sur les deux
- Vidéos des récompenses (Ton 80, Hat Trick…) plus nettes : refaites en 1280 × 720 depuis les originaux, moins compressées (16 → 44 Mo)
- Vidéos des coups (Triple 20, Bull, Double Bull) refaites en 1280 × 720 avec 4 nouveaux fonds (flammes, étincelles rouges, anneau bleu, explosion bleue), même son qu'avant
- Écran TV : manche et code collés à droite de la barre du haut, règles affichées en entier quand il y a la place

## v0.6.9

- Check-up avant soirée (tous les jeux passés en revue sur téléphone et écran TV, du début aux résultats, à 1, 2, 4, 8 et 10 joueurs) :
  - écran TV : la barre du haut ne déborde plus avec les noms de jeu longs (Cut Throat caché, Match, Contre la montre, Le Chat et la Souris) : le nom rétrécit
  - écran TV : les effets (son, vidéo, annonce) portent toujours sur la dernière fléchette, même quand le temps du tour (Contre la montre) ou un changement de cible arrive juste après
  - écran TV : un 2e téléphone dont l'horloge retarde n'est plus ignoré ; 2 envois dans la même milliseconde ne se perdent plus
  - écran TV : le nom du joueur suivant (« ENSUITE ») s'affiche en entier, même long (rétréci au besoin, plus coupé par « … »)

## v0.6.8

- **Écrans TV / tablette : bandeau du tour, vidéos et annonces de nouveau là** : chaque envoi du téléphone arrive 2 fois (serveur et Wi-Fi) avec les champs dans un ordre différent ; l'écran croyait à une nouvelle partie et la reconstruisait sans effets. Doublons ignorés, comparaison indépendante de l'ordre

## v0.6.7

- Son sur la TV plus fiable : si la vidéo d'un T20 / bull ne peut pas être lue, le bruitage et l'annonce de la fléchette reviennent (avant : silence) ; bruitages en lecteur classique sur la TV (le mode « faible latence » restait parfois muet)
- Vidéos sur la TV : rendu de l'appli en OpenGL ES (au lieu de Vulkan), qui affiche mieux les vidéos sur certaines TV Android ; si une vidéo ne peut pas être lue, l'écran TV l'écrit en bas (« VIDÉO IMPOSSIBLE SUR CET ÉCRAN : … »)
- Vidéos des coups (T20, bull, double bull) et des récompenses en plein écran sur les écrans plus allongés que le 16:9 (plus de bandes noires sur les côtés)

## v0.6.6

- **Paint** (fête) : chaque fléchette peint sa zone de la cible à la couleur du joueur, on prend les zones des autres, une zone touchée 2 fois est protégée ; le plus de zones gagne
- **Bowling** (fête) : 10 frames, quilles = points ÷ 6 (T20 = strike), strikes et spares comptés comme au bowling, 300 au maximum
- **Chambrage** de l'annonceur (réglage du son, activé par défaut) : petite phrase moqueuse sur un tour à moins de 20, un bust ou un tour de Cricket sans marque ; voix enregistrée (19 nouvelles annonces, dont « strike » et « spare »)
- Bandeau « AU TOUR DE … » affiché 3 s (1,5 s avant)
- **Caméra de la tablette sur la TV** : dans la fenêtre TV du téléphone, choisir l'écran qui filme et celui qui affiche, ALLUMER LA CAMÉRA ; caméra avant / arrière, position (4 coins ou plein écran) et taille ; l'image passe directement d'un écran à l'autre par le Wi-Fi (sans le son), l'écran qui filme montre un petit aperçu « EN DIRECT » ; l'appareil qui pilote (tablette fixe reliée à la cible, téléphone) peut aussi filmer lui-même pour la TV (« Cet appareil », aperçu en haut au milieu)
- **Le Chat et la Souris** (fête, 2 joueurs) : la souris part avec 3, 5 ou 7 cases d'avance sur le tour 1 → 20 → bull, le chat doit la rattraper (simple 1 case, double 2, triple 3) ; la souris gagne au bull ou après 20 manches
- **Contre la montre** (entraînement) : finir 301 / 501 / 701 (Double ou Single Out) le plus vite possible ; chrono de chaque joueur pendant ses tours (de « suivant » à sa dernière fléchette), fin conseillée allumée, meilleur temps gardé et classé
- **Cible de chaque joueur** : bouton CIBLE dans la fiche du joueur (« Par défaut » = style des options, ou l'un des 9 styles) ; pendant son tour, la cible affichée (téléphone et TV) est la sienne ; celle du profil principal s'affiche sur l'écran TV en attente ; gardée sur le serveur avec le compte : le joueur la retrouve chez un ami, sur la TV et en ligne
- **Cricket : petite cible** dans le panneau de droite (au-dessus des 3 fléchettes) : numéros fermés par le joueur allumés à sa couleur, numéros encore à fermer qui clignotent, fléchettes du tour plantées
- **Jeux de lumière sur les numéros** de la cible dessinée : le numéro d'une zone touchée s'allume à la couleur du joueur et reste allumé pendant le tour (flash à l'impact), les numéros à viser clignotent en blanc, une lumière fait le tour en attendant la 1re fléchette, tout l'anneau brille sur un bull, passe au rouge sur un bust et en arc-en-ciel à la victoire
- **Cibles réalistes** : les 9 styles (dont le nouveau « Réaliste » aux couleurs d'une cible électronique) passent au même rendu : cible électronique en plastique troué avec relief, séparateurs et reflet, anneau de LED animé à la couleur du joueur (rouge sur un bust, arc-en-ciel à la victoire), segment touché allumé, fléchettes en 3D (fût en métal, empennage à la couleur du joueur, ombre) qui arrivent et vibrent en se plantant
- **Écran TV « Ensuite »** : en haut de l'écran de partie, le joueur qui lancera après celui en cours (photo, nom) et ce qu'il lui reste en 01 (ou son score)
- **Double en ligne (2 contre 2)** : DÉFIER propose 1 CONTRE 1 ou 2 CONTRE 2 ; chaque équipe joue chez elle sur sa cible (un appareil par maison), l'équipier est un compte du téléphone ou un invité, l'adversaire choisit le sien en acceptant ; 01 en **double** (score commun à l'équipe) ou Team Cricket ; SQL `2026-11-13_double.sql`
- **Barre du haut de l'accueil allégée** : la cible à gauche (pastille plus étroite), puis des boutons encadrés : joueurs (icône + nombre), STATS, TV, SON et PROFIL (photo + rang), avec leur nom sous l'icône ; le reste est dans la tuile OPTIONS
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
