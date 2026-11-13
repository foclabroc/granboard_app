import 'package:flutter/material.dart';

import '../audio.dart';
import '../board_service.dart';
import '../players.dart';
import '../tv_link.dart';
import '../update_check.dart';
import 'account_page.dart';
import 'calibration_page.dart';
import 'connect_page.dart';
import 'dartboard.dart';
import 'diagnostic_page.dart';
import 'lights_sheet.dart';
import 'players_page.dart';
import 'share_sheet.dart';
import 'sound_settings.dart';
import 'theme.dart';
import 'tv_sheet.dart';
import 'wallpaper.dart';
import 'wallpaper_picker.dart';
import 'widgets.dart';

/// Page « Options · Joueurs » (tuile de l'accueil) : les comptes du
/// téléphone à gauche, tous les réglages de l'appli à droite.
class OptionsPage extends StatelessWidget {
  const OptionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OPTIONS · JOUEURS')),
      body: const SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 5, child: _PlayersPanel()),
              SizedBox(width: 12),
              Expanded(flex: 6, child: _OptionsPanel()),
            ],
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? action;
  const _Panel(
      {required this.title,
      required this.icon,
      required this.child,
      this.action});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Tv.panel.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Tv.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 44,
              padding: const EdgeInsets.only(left: 14, right: 6),
              decoration: BoxDecoration(gradient: Tv.goldGradient),
              child: Row(
                children: [
                  Icon(icon, color: Colors.black, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(title,
                          style: Tv.title(20, color: Colors.black))),
                  if (action != null) action!,
                ],
              ),
            ),
            Expanded(
                child: Material(type: MaterialType.transparency, child: child)),
          ],
        ),
      );
}

// ─── Joueurs ───

class _PlayersPanel extends StatelessWidget {
  const _PlayersPanel();

  @override
  Widget build(BuildContext context) {
    final store = PlayerStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => _Panel(
        title: 'JOUEURS (${store.players.length})',
        icon: Icons.groups,
        action: TextButton.icon(
          key: const ValueKey('opt-add-player'),
          style: TextButton.styleFrom(foregroundColor: Colors.black),
          onPressed: () => showAccountPage(context),
          icon: const Icon(Icons.person_add, size: 20),
          label: Text('AJOUTER', style: Tv.title(15, color: Colors.black)),
        ),
        child: store.players.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                      'Aucun joueur sur ce téléphone.\nAjoute ton profil pour '
                      'garder tes stats et ton rang.',
                      textAlign: TextAlign.center,
                      style: Tv.label(14, color: Tv.text)),
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      children: [
                        for (final p in store.players)
                          ListTile(
                            key: ValueKey('opt-player-${p.id}'),
                            dense: true,
                            leading: PlayerAvatar.of(p, size: 34),
                            title: Row(
                              children: [
                                Flexible(
                                  child: Text(p.name.toUpperCase(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Tv.title(18)),
                                ),
                                if (store.isOwner(p)) ...[
                                  const SizedBox(width: 6),
                                  Icon(Icons.star, size: 16, color: Tv.gold),
                                ],
                              ],
                            ),
                            subtitle: p.expired
                                ? Text('À RECONNECTER',
                                    style: Tv.label(11, color: Tv.red))
                                : RankChip(p.key),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        PlayerDetailPage(player: p))),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    child: OutlinedButton.icon(
                      key: const ValueKey('opt-players'),
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const PlayersPage())),
                      icon: const Icon(Icons.manage_accounts),
                      label: const Text('GÉRER LES JOUEURS'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ─── Options ───

class _OptionsPanel extends StatelessWidget {
  const _OptionsPanel();

  @override
  Widget build(BuildContext context) {
    final board = BoardService.instance;
    return _Panel(
      title: 'OPTIONS',
      icon: Icons.tune,
      child: ListenableBuilder(
        listenable: Listenable.merge(
            [board, TvLink.instance, Tv.skin, BoardSkin.current]),
        builder: (context, _) => ListView(
          padding: const EdgeInsets.symmetric(vertical: 4),
          children: [
            const _Group('AFFICHAGE'),
            _Item(
              id: 'theme',
              icon: Icons.palette,
              title: 'Thème de l\'appli',
              value: Tv.skin.value.name,
              onTap: () => showThemeSheet(context),
            ),
            _Item(
              id: 'skin',
              icon: Icons.track_changes,
              title: 'Style de la cible',
              value: BoardSkin.current.value.name,
              onTap: () => showBoardSkinSheet(context),
            ),
            const _Group('SON'),
            _Item(
              id: 'sound',
              icon: Icons.volume_up,
              title: 'Sons, musique et annonceur',
              value: AudioService.instance.muted ? 'Coupé ici' : null,
              onTap: () => showSoundSettings(context),
            ),
            const _Group('ÉCRANS'),
            _Item(
              id: 'tv',
              icon: TvLink.instance.linked ? Icons.connected_tv : Icons.tv,
              title: 'Écran TV / tablette',
              value: TvLink.instance.linked
                  ? TvLink.instance.screens.map((s) => s.label).join(', ')
                  : 'Pas relié',
              onTap: () => showTvSheet(context),
            ),
            const _Group('CIBLE'),
            _Item(
              id: 'board',
              icon: Icons.bluetooth,
              title: 'Cible Bluetooth',
              value: board.isConnected
                  ? (board.deviceName ?? 'GranBoard')
                  : 'Pas de cible',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ConnectPage())),
            ),
            if (board.isConnected)
              _Item(
                id: 'calibrate',
                icon: Icons.tune,
                title: 'Calibrer la cible',
                value: board.hasCustomTable ? 'Calibrée' : 'Table standard',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const CalibrationPage())),
              ),
            _Item(
              id: 'lights',
              icon: Icons.lightbulb,
              title: 'Lumières de la cible (3s)',
              onTap: () => showLightsSheet(context),
            ),
            _Item(
              id: 'diag',
              icon: Icons.bug_report,
              title: 'Diagnostic',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const DiagnosticPage())),
            ),
            const _Group('APPLI'),
            _Item(
              id: 'share',
              icon: Icons.qr_code_2,
              title: 'Partager l\'appli (QR code)',
              onTap: () => showShareSheet(context),
            ),
            _Item(
              id: 'update',
              icon: Icons.system_update,
              title: 'Mises à jour',
              value: 'v$kAppVersion',
              onTap: () => checkForUpdate(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final String text;
  const _Group(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
        child: Text(text, style: Tv.label(12, color: Tv.gold)),
      );
}

class _Item extends StatelessWidget {
  final String id;
  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback onTap;
  const _Item(
      {required this.id,
      required this.icon,
      required this.title,
      required this.onTap,
      this.value});

  @override
  Widget build(BuildContext context) => ListTile(
        key: ValueKey('opt-$id'),
        dense: true,
        leading: Icon(icon, color: Tv.goldLight),
        title: Text(title, style: Tv.title(17)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (value != null)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(value!.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Tv.label(12, color: Tv.text)),
              ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: onTap,
      );
}

/// Vérifie s'il y a une nouvelle version (message si rien à faire).
Future<void> checkForUpdate(BuildContext context) async {
  final r = await updateGateKey.currentState?.check(manual: true);
  if (!context.mounted || r == 1) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          r == 2 ? 'Impossible de joindre GitHub' : 'À jour (v$kAppVersion)')));
}

// ─── Fenêtres de choix (aussi ouvertes depuis le menu ⋮ de l'accueil) ───

/// Choix du thème de l'appli (fenêtre du bas).
Future<void> showThemeSheet(BuildContext context) => showAppSheet(
      context,
      builder: (ctx) => ValueListenableBuilder<AppSkin>(
        valueListenable: Tv.skin,
        builder: (ctx, cur, _) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TvSection('Thème de l\'appli',
                  padding: EdgeInsets.only(bottom: 10)),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final sk in AppSkin.all)
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        Tv.choose(sk);
                        TvLink.instance.pushLobby();
                      },
                      child: Container(
                        width: 150,
                        height: 84,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          image: sk.fx == SkinFx.wallpaper
                              ? DecorationImage(
                                  image: Wallpaper.instance.imageOf(
                                          Wallpaper.instance.shown,
                                          thumb: true) ??
                                      AssetImage(Wallpaper.thumbPath(1)),
                                  fit: BoxFit.cover,
                                  colorFilter: const ColorFilter.mode(
                                      Color(0x66000000), BlendMode.darken))
                              : null,
                          gradient: RadialGradient(
                            center: const Alignment(-0.6, -1),
                            radius: 1.6,
                            colors: [
                              Color.lerp(sk.accent, sk.bg, 0.55)!,
                              sk.bg,
                              Color.lerp(sk.glow, sk.bg, 0.6)!,
                            ],
                          ),
                          border: Border.all(
                              color: cur == sk ? sk.accent : sk.line,
                              width: cur == sk ? 3 : 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                for (final c in [sk.accent, sk.glow, sk.panel2])
                                  Container(
                                    width: 16,
                                    height: 16,
                                    margin: const EdgeInsets.only(right: 5),
                                    decoration: BoxDecoration(
                                        color: c, shape: BoxShape.circle),
                                  ),
                                const Spacer(),
                                if (cur == sk)
                                  Icon(Icons.check_circle,
                                      color: sk.accent, size: 20),
                              ],
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(sk.name.toUpperCase(),
                                  maxLines: 1,
                                  style: Tv.title(20, color: sk.accentLight)),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              if (cur.fx == SkinFx.wallpaper) const WallpaperPicker(),
            ],
          ),
        ),
      ),
    );

/// Choix du style de la cible (fenêtre du bas).
Future<void> showBoardSkinSheet(BuildContext context) => showAppSheet(
      context,
      builder: (ctx) => ValueListenableBuilder<BoardSkin>(
        valueListenable: BoardSkin.current,
        builder: (ctx, cur, _) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TvSection('Style de la cible',
                  padding: EdgeInsets.only(bottom: 10)),
              Wrap(
                spacing: 16,
                runSpacing: 12,
                children: [
                  for (final sk in BoardSkin.all)
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        BoardSkin.choose(sk);
                        TvLink.instance.pushLobby();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: cur == sk ? Tv.gold : Tv.line,
                              width: cur == sk ? 2.5 : 1),
                        ),
                        child: Column(
                          children: [
                            DartboardPreview(skin: sk, size: 104),
                            const SizedBox(height: 6),
                            Text(sk.name.toUpperCase(),
                                style: Tv.title(18,
                                    color: cur == sk ? Tv.goldLight : Tv.text)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text('S\'applique partout, écran TV compris.',
                  style: Tv.label(12)),
            ],
          ),
        ),
      ),
    );
