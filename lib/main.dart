import 'package:flutter/material.dart';

import 'board_service.dart';
import 'players.dart';
import 'ui/home_page.dart';
import 'update_check.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    BoardService.instance.init(),
    PlayerStore.instance.load(),
  ]);
  runApp(const GranBoardApp());
}

class GranBoardApp extends StatelessWidget {
  const GranBoardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GranBoard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2E7D32),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: UpdateGate(key: updateGateKey, child: const HomePage()),
    );
  }
}
