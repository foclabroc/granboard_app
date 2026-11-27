# Instructions pour Copilot — Foclaboard (dépôt granboard_app)

Appli Flutter (Android, **paysage**) de fléchettes pour cibles GranBoard (Dash, 3s) et VDarts, en Bluetooth LE. Comptes, stats et jeu en ligne sur le serveur maison de foclabroc (PostgreSQL + PostgREST, fonctions `gb_*`). Projet perso de foclabroc.

**Lire d'abord** :
- `docs/REPRISE.md` : où en est le projet, ce qui reste à faire, comment travailler (visuels, sons, captures).
- `CLAUDE.md` : la référence complète (historique de chaque version, structure fichier par fichier, serveur, règles des jeux). Très long : chercher le nom du fichier / de la classe dedans.

## Règles de travail (à respecter)

- Échanges **en français, concis**.
- **Montrer les changements et attendre « pousse »** de foclabroc avant tout `git push`.
- **SQL avant le code** : un changement serveur = un fichier `sql/AAAA-MM-JJ_sujet.sql` relançable (objets à `rc_owner`, fonctions internes `gb__*` fermées, RPC `gb_*` ouvertes à `anon`, finir par `notify pgrst, 'reload schema';`). foclabroc le lance (`psql -U postgres -d postgres -f fichier.sql`) puis dit « pousse ». Toute fonction qui appelle `gb__auth` doit être `volatile`.
- **Ne jamais commiter de clé** (signature, clé API Gemini, secret TURN).
- Après chaque push : mettre à jour `CLAUDE.md` (section « État actuel », une ligne par version) et `docs/REPRISE.md` si l'état change.
- Sortir une version : `version:` du `pubspec.yaml` **et** `kAppVersion` de `lib/update_check.dart` identiques, section `## vX.Y.Z` dans `CHANGELOG.md`, pousser, puis GitHub Actions → « APK Android » → Run workflow avec « publier » coché.

## Vérifier avant de pousser

- `flutter analyze` : 0 problème (seule l'info « package:flutter/material.dart is deprecated » de Flutter 3.50 est tolérée ; **ne pas** lancer `dart fix --apply` sans `--code`).
- `flutter test` : tout doit passer (~290 tests, 3 min). En partie, pas de `pumpAndSettle` (la cible pulse en continu).
- `dart format` seulement sur les fichiers modifiés.

## Repères rapides

- Moteurs de jeu purs Dart dans `lib/game/` (`x01.dart`, `cricket.dart`, `practice.dart` + `arcade_games.dart`, `match.dart`, `bot.dart`) ; interface commune `DartsGame` (`darts_game.dart`), état recalculé en rejouant le journal d'actions.
- Écrans dans `lib/ui/` ; scènes des jeux Party arcade dans `lib/ui/arcade/` ; écran TV dans `lib/tv/`.
- Thèmes : `lib/ui/theme.dart` (`Tv`, `AppSkin`, getters → pas de `const` autour de `Tv.gold`…), `lib/ui/game_theme.dart` (`GameSkins`, `GameThemeScope`).
- Tests : `test/` avec `fake_server.dart` (faux serveur `gb_*`) ; plusieurs effets coupés en test dans `test/flutter_test_config.dart`.
