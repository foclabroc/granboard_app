import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_test/flutter_test.dart';
import 'package:granboard_proto/audio.dart';
import 'package:granboard_proto/players.dart';
import 'package:granboard_proto/settings_sync.dart';
import 'package:granboard_proto/ui/cricket_view.dart';
import 'package:granboard_proto/ui/game_page.dart';
import 'package:granboard_proto/ui/home_page.dart';
import 'package:granboard_proto/ui/options_page.dart';
import 'package:granboard_proto/ui/dartboard.dart';
import 'package:granboard_proto/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_server.dart';

/// Nouveau téléphone : préférences vides, mêmes comptes sur le serveur.
Future<void> newPhone(FakeServer server, {bool login = true}) async {
  SharedPreferences.setMockInitialValues({});
  await PlayerStore.instance.load();
  await SettingsSync.instance.load();
  await Tv.load();
  await BoardSkin.load();
  await CricketStyle.load();
  await AutoNext.load();
  await AudioService.instance.reloadSettings();
  if (login) await PlayerStore.instance.login('Foc', '1234');
}

void main() {
  test('Photo de fond d\'écran réduite pour l\'envoi', () {
    final big = img.Image(width: 2400, height: 1200);
    img.fill(big, color: img.ColorRgb8(40, 90, 160));
    final out = SettingsSync.shrinkJpeg(
        Uint8List.fromList(img.encodeJpg(big, quality: 95)))!;
    final small = img.decodeJpg(out)!;
    expect(small.width, 1600);
    expect(small.height, 800);
    expect(out.length, lessThan(500000));
    expect(SettingsSync.shrinkJpeg(Uint8List.fromList([1, 2, 3])), isNull);
  });

  late FakeServer server;
  final sync = SettingsSync.instance;

  setUp(() async {
    server = FakeServer()..install();
    SharedPreferences.setMockInitialValues({});
    await PlayerStore.instance.load();
    await SettingsSync.instance.load();
    await PlayerStore.instance.register('Foc', '1234');
  });

  test('Compte sans sauvegarde : téléphone lié, réglages envoyés s\'ils changent',
      () async {
    expect(sync.linked, isFalse);
    expect(await sync.save(), isFalse, reason: 'pas lié : rien n\'est écrasé');
    expect(await sync.check(), isNull);
    expect(sync.linked, isTrue);

    await BoardSkin.choose(BoardSkin.neon);
    await AutoNext.set(true);
    expect(await sync.save(), isTrue);
    final id = PlayerStore.instance.owner!.id;
    expect(server.settings[id]!['v'], 1);
    expect(server.settings[id]!['data']['board_skin'], 'neon');
    expect(server.settings[id]!['data']['auto_next_v1'], true);
    expect(sync.savedAt, isNotNull);

    // rien n'a changé : pas de nouvel envoi
    expect(await sync.save(), isTrue);
    expect(server.settings[id]!['v'], 1);
  });

  test('Nouveau téléphone : la sauvegarde est proposée, reprise ou refusée',
      () async {
    await sync.check();
    await BoardSkin.choose(BoardSkin.sakura);
    await CricketStyle.choose(CricketStyle.columns);
    await AutoNext.set(true);
    AudioService.instance.setTeasing(false);
    AudioService.instance.setPronunciation('Foc', 'Fok');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sync.save();

    await newPhone(server);
    expect(BoardSkin.current.value, isNot(BoardSkin.sakura));
    expect(sync.linked, isFalse);
    // pas lié : ce téléphone tout neuf n'écrase pas la sauvegarde
    expect(await sync.save(), isFalse);
    final saved = await sync.check();
    expect(saved, isNotNull);
    await sync.apply(saved!);
    expect(BoardSkin.current.value, BoardSkin.sakura);
    expect(CricketStyle.current.value, CricketStyle.columns);
    expect(AutoNext.on.value, isTrue);
    expect(AudioService.instance.teasing, isFalse);
    expect(AudioService.instance.pronunciations['foc'], 'Fok');
    expect(sync.linked, isTrue);

    // autre téléphone : refusée, ses réglages remplacent ceux du compte
    await newPhone(server);
    expect(await sync.check(), isNotNull);
    await sync.decline();
    await BoardSkin.choose(BoardSkin.ember);
    expect(await sync.save(), isTrue);
    final id = PlayerStore.instance.owner!.id;
    expect(server.settings[id]!['data']['board_skin'], 'ember');
  });

  testWidgets('Accueil d\'un nouveau téléphone : « REPRENDRE » applique le style de cible',
      (tester) async {
    tester.view.physicalSize = const Size(785, 392);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await sync.check();
      await BoardSkin.choose(BoardSkin.neon);
      await sync.save();
      await newPhone(server);
      await PlayerStore.instance.setWelcomed();
    });
    await tester.pumpWidget(MaterialApp(theme: Tv.theme(), home: const HomePage()));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('Tes réglages'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('settings-yes')));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(BoardSkin.current.value, BoardSkin.neon);
    expect(sync.linked, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Options : sauvegarder maintenant, reprendre', (tester) async {
    tester.view.physicalSize = const Size(785, 392);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        theme: Tv.theme(),
        home: Builder(
            builder: (c) => Scaffold(
                body: TextButton(
                    onPressed: () => showSettingsSyncSheet(c),
                    child: const Text('go'))))));
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const ValueKey('settings-restore')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Aucune sauvegarde sur ce compte'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('settings-save')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Réglages sauvegardés'), findsOneWidget);
    expect(find.textContaining('SAUVEGARDÉS LE'), findsOneWidget);
    expect(server.settings.values.single['v'], 1);
    expect(tester.takeException(), isNull);
  });
}
