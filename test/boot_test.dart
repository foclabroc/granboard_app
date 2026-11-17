import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granboard_proto/ui/boot_page.dart';
import 'package:granboard_proto/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Démarrage : barre de chargement puis accueil', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    BootGate.enabled = true;
    addTearDown(() => BootGate.enabled = false);
    await tester.pumpWidget(MaterialApp(
      theme: Tv.theme(),
      home: const BootGate(child: Text('ACCUEIL')),
    ));
    expect(find.byKey(const ValueKey('boot-progress')), findsOneWidget);
    expect(find.text('ACCUEIL'), findsNothing);
    // fichiers et images : vraie attente hors du temps simulé
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)));
    for (var i = 0; i < 30 && find.text('ACCUEIL').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 200));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
    }
    expect(find.text('ACCUEIL'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
