# Relais TURN de Foclaboard

Petit serveur TURN (pion/turn) pour la vidéo du jeu en ligne : quand deux
téléphones ne peuvent pas se joindre directement (4G, box stricte), l'image
passe par ce relais, sur le mini PC.

## Compiler

    GOOS=windows GOARCH=amd64 go build -ldflags "-s -w -H windowsgui" -o foclaboard-turn.exe

## Installer (mini PC Windows)

1. Mettre `foclaboard-turn.exe`, `turn.json`, `install.bat` et
   `desinstaller.bat` dans un dossier fixe (ex. `C:\foclaboard-turn`).
2. Clic droit sur `install.bat` › Exécuter en tant qu'administrateur : pare-feu
   ouvert, tâche « Foclaboard TURN » lancée au démarrage (compte SYSTEM),
   relais lancé et testé (« OK : le relais répond… »).
3. Sur la box, rediriger vers le mini PC : **UDP 3478**, **TCP 3478** et
   **UDP 49152 à 49251**.
4. Poser la même clé (`secret` de turn.json) sur le serveur Foclaboard :

       insert into gb_config (key, value) values ('turn',
         '{"urls":["turn:foclabroc.duckdns.org:3478?transport=udp","turn:foclabroc.duckdns.org:3478?transport=tcp"],"secret":"CLE","ttl":86400}')
       on conflict (key) do update set value = excluded.value;

`turn.json` (créé avec un secret au hasard s'il manque) : `host` (nom duckdns,
sert à trouver l'adresse publique, relue toutes les 5 min), `public_ip` (pour
la forcer), `port`, `relay_min`/`relay_max`, `realm`, `secret`,
`max_allocations`. Journal : `turn.log` à côté de l'exe.

Sécurité : il faut un identifiant signé par le serveur Foclaboard (valable 24 h, donné seulement aux joueurs d'une partie en ligne), et le relais refuse d'aller vers le réseau de la maison (192.168.x, 10.x, 127.0.0.1…) : seules des adresses publiques.

`foclaboard-turn.exe -test` : ouvre un relais de test sur le mini PC avec la clé.
