import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'audio.dart';
import 'board_lights.dart';
import 'board_service.dart';
import 'media.dart';
import 'online/online.dart';
import 'players.dart';
import 'tv/screen_cam.dart';
import 'tv/tv_home.dart';
import 'tv_link.dart';
import 'ui/award.dart' show AwardPlayer;
import 'ui/cricket_view.dart' show CricketStyle;
import 'ui/dartboard.dart' show BoardSkin;
import 'ui/home_page.dart';
import 'ui/theme.dart';
import 'ui/wallpaper.dart';
import 'update_check.dart';

const kPrefTvMode = 'tv_mode';

/// Vrai sur une Android TV.
Future<bool> isAndroidTv() async {
  try {
    return await const MethodChannel('granboard/device')
            .invokeMethod<bool>('isTv') ??
        false;
  } catch (_) {
    return false;
  }
}

/// Mode écran : Android TV, ou appareil choisi comme écran (tablette…).
Future<bool> detectTv() async {
  if (await isAndroidTv()) return true;
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kPrefTvMode) == true;
  } catch (_) {
    return false;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(
      [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  final androidTv = await isAndroidTv();
  final tv = androidTv || await detectTv();
  AudioService.instance.tvDevice = tv;
  // Écran TV (souvent peu puissant) : animations continues coupées
  Perf.lite = tv;
  await Future.wait([
    AudioService.instance.init(),
    BoardSkin.load(),
    CricketStyle.load(),
    Tv.load(),
    Wallpaper.instance.load(),
    MediaStore.instance.load(),
    if (!tv) BoardService.instance.init(),
    if (!tv) BoardLights.instance.load(),
    if (!tv) PlayerStore.instance.load(),
  ]);
  TvLink.enabled = !tv;
  if (!tv) await TvLink.instance.load();
  // Jamais de mise en veille de l'écran tant que l'appli est ouverte
  WakelockPlus.enable().catchError((_) {});
  runApp(GranBoardApp(tv: tv, androidTv: androidTv));
  // Comptes : vérifie les sessions, envoie les parties en attente
  if (!tv) {
    PlayerStore.instance.sync();
    // Hors ligne : renvoi automatique dès que le réseau revient
    PlayerStore.instance.startAutoSync();
    // Jeu en ligne : présence et défis tant que l'appli est ouverte
    OnlineService.instance.start();
  }
}

class GranBoardApp extends StatefulWidget {
  final bool tv;
  final bool androidTv;
  const GranBoardApp({super.key, this.tv = false, this.androidTv = false});

  @override
  State<GranBoardApp> createState() => GranBoardAppState();
}

class GranBoardAppState extends State<GranBoardApp> {
  late bool tv = widget.tv;

  /// Bouton Accueil : plus de son en arrière-plan ; sur Android TV l'appli
  /// se ferme (elle ne tourne pas cachée derrière l'accueil de la TV).
  late final AppLifecycleListener _life = AppLifecycleListener(
    onStateChange: (state) {
      if (state == AppLifecycleState.paused) {
        AudioService.instance.background = true;
        AwardPlayer.stop();
        if (widget.androidTv) SystemNavigator.pop();
      } else if (state == AppLifecycleState.resumed) {
        AudioService.instance.background = false;
      }
    },
  );

  @override
  void initState() {
    super.initState();
    _life; // écoute dès le départ
  }

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  /// Bascule téléphone ↔ écran TV (mémorisé).
  Future<void> setTvMode(bool on) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kPrefTvMode, on);
    TvLink.enabled = !on;
    if (!on) {
      await Future.wait([
        BoardService.instance.init(),
        PlayerStore.instance.load(),
        TvLink.instance.load(),
      ]);
    }
    on ? OnlineService.instance.stop() : OnlineService.instance.start();
    setState(() => tv = on);
  }

  @override
  Widget build(BuildContext context) {
    // Tout se redessine quand le thème change
    return ValueListenableBuilder<AppSkin>(
      valueListenable: Tv.skin,
      builder: (context, skin, _) => _app(),
    );
  }

  Widget _app() {
    return MaterialApp(
      title: 'Foclaboard',
      debugShowCheckedModeBanner: false,
      theme: Tv.theme(),
      builder: (context, child) => Tv.appBuilder(
          context,
          // caméra de cet appareil envoyée à la TV : petit aperçu par-dessus
          Stack(fit: StackFit.expand, children: [
            child ?? const SizedBox.shrink(),
            ListenableBuilder(
              listenable: TvLink.instance,
              builder: (context, _) => TvLink.instance.hostCam == null
                  ? const SizedBox.shrink()
                  : ScreenCamLayer(cam: TvLink.instance.hostCam!, host: true),
            ),
          ])),
      home: UpdateGate(
        key: updateGateKey,
        child: tv
            ? TvHome(
                key: const ValueKey('tv'),
                deviceName: widget.androidTv ? 'TV' : 'Tablette',
                onPhoneMode: widget.androidTv ? null : () => setTvMode(false),
              )
            : const HomePage(key: ValueKey('phone')),
      ),
    );
  }
}
