import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'audio.dart';
import 'board_service.dart';
import 'media.dart';
import 'players.dart';
import 'tv/tv_home.dart';
import 'tv_link.dart';
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
    MediaStore.instance.load(),
    if (!tv) BoardService.instance.init(),
    if (!tv) PlayerStore.instance.load(),
  ]);
  if (!tv) await TvLink.instance.load();
  runApp(GranBoardApp(tv: tv, androidTv: androidTv));
  // Comptes : vérifie les sessions, envoie les parties en attente
  if (!tv) PlayerStore.instance.sync();
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
    setState(() => tv = on);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Foclaboard',
      debugShowCheckedModeBanner: false,
      theme: Tv.theme(),
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
