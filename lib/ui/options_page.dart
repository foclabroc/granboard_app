import 'package:flutter/material.dart';

import '../audio.dart';
import '../board_service.dart';
import '../players.dart';
import '../server.dart';
import '../settings_sync.dart';
import '../tv_link.dart';
import '../update_check.dart';
import 'account_page.dart';
import 'calibration_page.dart';
import 'connect_page.dart';
import 'dartboard.dart';
import 'ring_anim.dart';
import 'game_intro.dart';
import 'diagnostic_page.dart';
import 'lights_sheet.dart';
import 'players_page.dart';
import 'share_sheet.dart';
import 'setup_widgets.dart';
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
    return const Scaffold(
      body: SafeArea(
        left: false,
        right: false,
        child: Column(
          children: [
            SetupBand(title: 'Options', sub: 'Configuration'),
            Expanded(
                child: SidePad(
              child: Padding(
                padding: EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 5, child: _PlayersPanel()),
                    SizedBox(width: 12),
                    Expanded(flex: 6, child: _OptionsPanel()),
                  ],
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? action;
  const _Panel({required this.title, required this.child, this.action});

  @override
  Widget build(BuildContext context) => TableauPanel(
        title: title,
        action: action,
        child: Material(type: MaterialType.transparency, child: child),
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
        action: TextButton.icon(
          key: const ValueKey('opt-add-player'),
          style: TextButton.styleFrom(foregroundColor: Tv.gold),
          onPressed: () => showAccountPage(context),
          icon: const Icon(Icons.person_add, size: 20),
          label: Text('AJOUTER', style: Tv.title(15, color: Tv.gold)),
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
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                      children: [
                        for (final p in store.players)
                          _PlayerCard(
                            key: ValueKey('opt-player-${p.id}'),
                            player: p,
                            owner: store.isOwner(p),
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

/// Ligne d'un joueur : photo, nom et rang.
class _PlayerCard extends StatelessWidget {
  final PlayerProfile player;
  final bool owner;
  final VoidCallback onTap;
  const _PlayerCard(
      {super.key,
      required this.player,
      required this.owner,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = player;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Tv.panel2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: owner ? Tv.gold : Tv.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          leading: PlayerAvatar.of(p, size: 34),
          title: Text(p.name.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Tv.title(16)),
          subtitle: owner
              ? Text('PROFIL PRINCIPAL', style: Tv.label(10, color: Tv.gold))
              : null,
          trailing: p.expired
              ? Text('À RECONNECTER', style: Tv.label(10, color: Tv.red))
              : RankChip(p.key, size: 11),
          onTap: onTap,
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
      child: ListenableBuilder(
        listenable: Listenable.merge([
          board,
          TvLink.instance,
          Tv.skin,
          BoardSkin.current,
          RingAnim.current,
          GameIntro.on,
          SettingsSync.instance
        ]),
        builder: (context, _) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                    children: _ramp([
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
                  _Item(
                    id: 'ring',
                    icon: Icons.motion_photos_on,
                    title: 'Animation du contour',
                    value: RingAnim.current.value.name,
                    onTap: () => showRingAnimSheet(context),
                  ),
                  _Item(
                    id: 'intro',
                    icon: Icons.live_tv,
                    title: 'Intro des parties',
                    value: GameIntro.on.value ? 'OUI' : 'NON',
                    onTap: () => GameIntro.set(!GameIntro.on.value)
                        .then((_) => TvLink.instance.refresh()),
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
                    icon:
                        TvLink.instance.linked ? Icons.connected_tv : Icons.tv,
                    title: 'Écran TV / tablette',
                    value: TvLink.instance.linked
                        ? TvLink.instance.screens.map((s) => s.label).join(', ')
                        : 'Pas relié',
                    onTap: () => showTvSheet(context),
                  ),
                ])),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                    children: _ramp([
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
                      value:
                          board.hasCustomTable ? 'Calibrée' : 'Table standard',
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const CalibrationPage())),
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
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const DiagnosticPage())),
                  ),
                  const _Group('APPLI'),
                  _Item(
                    id: 'settings',
                    icon: Icons.cloud_sync,
                    title: 'Mes réglages sur mon compte',
                    value: settingsSyncLabel(),
                    onTap: () => showSettingsSyncSheet(context),
                  ),
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
                ])),
              ),
            ],
          ),
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
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 2),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(text, style: Tv.label(12, color: Tv.gold)),
        ),
      );
}

class _Item extends StatelessWidget {
  final String id;
  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback onTap;

  /// Couleur de la bande (posée par `_ramp`).
  final Color tint;
  const _Item(
      {required this.id,
      required this.icon,
      required this.title,
      required this.onTap,
      this.value,
      this.tint = Band.ice});

  _Item tinted(Color c) => _Item(
      id: id, icon: icon, title: title, onTap: onTap, value: value, tint: c);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: Band.deco(tint),
            child: InkWell(
              key: ValueKey('opt-$id'),
              borderRadius: BorderRadius.circular(9),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                child: Row(
                  children: [
                    Icon(icon, size: 20, color: Colors.white),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Band.text(Tv.title(15))),
                          if (value != null)
                            Text(value!.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Band.text(Tv.label(11))
                                    .copyWith(color: Colors.white70)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        size: 18, color: Colors.white70),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

/// Donne aux `_Item` d'une colonne les couleurs du dégradé, de haut en bas.
List<Widget> _ramp(List<Widget> ws) {
  final n = ws.whereType<_Item>().length;
  var i = 0;
  return [for (final w in ws) w is _Item ? w.tinted(Band.at(i++, n)) : w];
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

/// Choix de l'animation du contour de la cible (fenêtre du bas) : un
/// aperçu animé par style, à la couleur du profil principal.
Future<void> showRingAnimSheet(BuildContext context) => showAppSheet(
      context,
      builder: (ctx) => ValueListenableBuilder<RingAnim>(
        valueListenable: RingAnim.current,
        builder: (ctx, cur, _) {
          final color = PlayerStore.instance.owner?.color ?? Tv.gold;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TvSection('Animation du contour',
                    padding: EdgeInsets.only(bottom: 10)),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final a in RingAnim.all)
                      InkWell(
                        key: ValueKey('ring-${a.id}'),
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          RingAnim.choose(a);
                          TvLink.instance.refresh();
                        },
                        child: Container(
                          width: 150,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: cur == a ? Tv.gold : Tv.line,
                                width: cur == a ? 2.5 : 1),
                          ),
                          child: Column(
                            children: [
                              AnimatedDartboard(
                                  size: 104,
                                  hits: const [],
                                  dartColor: color,
                                  ring: a),
                              const SizedBox(height: 6),
                              Text(a.name.toUpperCase(),
                                  textAlign: TextAlign.center,
                                  style: Tv.title(16,
                                      color:
                                          cur == a ? Tv.goldLight : Tv.text)),
                              Text(a.help,
                                  textAlign: TextAlign.center,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: Tv.label(11)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                    'Quand aucune fléchette n\'est plantée. S\'applique '
                    'partout, écran TV compris (sur la TV allégée, '
                    'l\'animation est figée).',
                    style: Tv.label(12)),
              ],
            ),
          );
        },
      ),
    );

/// État de la sauvegarde des réglages (ligne des options).
String settingsSyncLabel() {
  final sync = SettingsSync.instance;
  if (!sync.hasAccount) return 'Pas de profil';
  final at = sync.savedAt;
  if (at == null) return sync.linked ? 'Pas encore envoyés' : 'Pas reliés';
  String two(int n) => n.toString().padLeft(2, '0');
  return 'Sauvegardés le ${two(at.day)}/${two(at.month)} à '
      '${two(at.hour)}:${two(at.minute)}';
}

/// Réglages gardés sur le compte du profil principal : sauvegarder
/// maintenant, ou reprendre ceux du compte.
Future<void> showSettingsSyncSheet(BuildContext context) => showAppSheet(
      context,
      builder: (_) => const _SettingsSyncSheet(),
    );

class _SettingsSyncSheet extends StatefulWidget {
  const _SettingsSyncSheet();

  @override
  State<_SettingsSyncSheet> createState() => _SettingsSyncSheetState();
}

class _SettingsSyncSheetState extends State<_SettingsSyncSheet> {
  final sync = SettingsSync.instance;
  String? _msg;
  bool _error = false;

  Future<void> _run(Future<String> Function() job) async {
    setState(() {
      _msg = null;
      _error = false;
    });
    try {
      final m = await job();
      if (mounted) setState(() => _msg = m);
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          _msg = e.offline
              ? 'Serveur injoignable : réessaie plus tard'
              : e.message;
          _error = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _msg = 'Ça n\'a pas marché';
          _error = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final owner = PlayerStore.instance.owner;
    return ListenableBuilder(
      listenable: sync,
      builder: (context, _) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('MES RÉGLAGES SUR MON COMPTE', style: Tv.title(22)),
            const SizedBox(height: 6),
            Text(
              !sync.hasAccount
                  ? 'Il faut un profil principal (connecté) pour garder '
                      'tes réglages.'
                  : 'Thème, style de cible, sons, prononciations, favoris, '
                      'réglages des parties, option AUTO, lumières et fond '
                      'd\'écran (avec tes photos) sont gardés sur le compte '
                      'de ${owner?.name ?? ''} : envoyés tout seuls quand tu '
                      'quittes l\'appli, et proposés sur un nouvel appareil '
                      'où tu te connectes.',
              style: TextStyle(color: Tv.muted, height: 1.3),
            ),
            const SizedBox(height: 10),
            if (sync.hasAccount)
              Text(settingsSyncLabel().toUpperCase(),
                  key: const ValueKey('settings-state'),
                  style: Tv.label(13, color: Tv.gold)),
            if (_msg != null) ...[
              const SizedBox(height: 6),
              Text(_msg!,
                  key: const ValueKey('settings-msg'),
                  style: TextStyle(color: _error ? Tv.red : Tv.green)),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('settings-restore'),
                    onPressed: !sync.hasAccount || sync.busy
                        ? null
                        : () => _run(() async => await sync.restore()
                            ? 'Réglages du compte repris'
                            : 'Aucune sauvegarde sur ce compte'),
                    icon: const Icon(Icons.cloud_download),
                    label: const Text('REPRENDRE CEUX DU COMPTE'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    key: const ValueKey('settings-save'),
                    onPressed: !sync.hasAccount || sync.busy
                        ? null
                        : () => _run(() async {
                              await sync.save(force: true);
                              return 'Réglages sauvegardés';
                            }),
                    icon: sync.busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.cloud_upload),
                    label: const Text('SAUVEGARDER MAINTENANT'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
