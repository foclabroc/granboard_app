# GranBoard App

Appli Flutter (Android) de fléchettes pour cible électronique **GranBoard**, connectée en Bluetooth LE.

## Utilisation

L'appli se joue en paysage, téléphone posé à côté de la cible.

1. Ferme l'appli GranBoard officielle (la cible n'accepte qu'une connexion BLE).
2. **Choisir une cible** → touche la GranBoard (en vert). Ensuite, l'appli s'y reconnecte toute seule.
3. **Joueurs** : crée un compte (pseudo + code à 4 chiffres) ou connecte-toi ; le joueur reste mémorisé sur le téléphone. Les invités jouent sans stats.
4. **Nouvelle partie** : 301 / 501 / 701 / 901 ou Freeze en équipes, règles In / Out / Bull, limite de manches, joueurs.
5. Le bouton de la cible (ou « Suivant ») passe au joueur suivant ; « Raté » pour une fléchette hors cible ; « Annuler » revient en arrière.

Stats, note et **classements** sont sur le serveur maison (fichiers SQL dans `sql/`).

## Build

- En local : `flutter run`
- APK : onglet **Actions → APK → Run workflow**, l'APK est dans les artefacts du run.
