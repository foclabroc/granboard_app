import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'audio.dart';
import 'board_service.dart';
import 'media.dart';
import 'online/online.dart';
import 'players.dart';
import 'tv/tv_home.dart';
import 'tv_link.dart';
import 'ui/cricket_view.dart' show CricketStyle;
import 'ui/dartboard.dart' show BoardSkin;
import 'ui/home_page.dart';
import 'ui/theme.dart';
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
  await Future.wait([
    AudioService.instance.init(),
    BoardSkin.load(),
    CricketStyle.load(),
    Tv.load(),
    MediaStore.instance.load(),
    if (!tv) BoardService.instance.init(),
    if (!tv) PlayerStore.instance.load(),
  ]);
  if (!tv) await TvLink.instance.load();
  // Jamais de mise en veille de l'écran tant que l'appli est ouverte
  WakelockPlus.enable().catchError((_) {});
  runApp(GranBoardApp(tv: tv, androidTv: androidTv));
  // Comptes : vérifie les sessions, envoie les parties en attente
  if (!tv) {
    PlayerStore.instance.sync();
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

  /// Bascule téléphone ↔ écran TV (mémorisé).
  Future<void> setTvMode(bool on) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kPrefTvMode, on);
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
      builder: Tv.appBuilder,
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
