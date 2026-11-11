import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'audio.dart';
import 'board_service.dart';
import 'players.dart';
import 'ui/home_page.dart';
import 'ui/theme.dart';
import 'update_check.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(
      [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await Future.wait([
    BoardService.instance.init(),
    PlayerStore.instance.load(),
    AudioService.instance.init(),
  ]);
  runApp(const GranBoardApp());
  // Comptes : vérifie les sessions, envoie les parties en attente
  PlayerStore.instance.sync();
}

class GranBoardApp extends StatelessWidget {
  const GranBoardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GranBoard',
      debugShowCheckedModeBanner: false,
      theme: Tv.theme(),
      home: UpdateGate(key: updateGateKey, child: const HomePage()),
    );
  }
}
