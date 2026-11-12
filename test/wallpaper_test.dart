import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granboard_proto/ui/theme.dart';
import 'package:granboard_proto/ui/wallpaper.dart';
import 'package:granboard_proto/ui/wallpaper_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Wallpaper.instance.load();
  });

  tearDown(() => Tv.skin.value = AppSkin.gold);

  test('Choix mémorisé, au hasard parmi les images de l\'appli', () async {
    final w = Wallpaper.instance;
    expect(w.choice, 'random');
    expect(w.all.length, Wallpaper.assetCount);
    expect(w.shown, startsWith('asset:'));
    await w.choose('asset:4');
    expect(w.shown, 'asset:4');
    expect(w.forTv, 'asset:4');
    await w.load();
    expect(w.choice, 'asset:4', reason: 'gardé après redémarrage');
    // TV : suit le téléphone ; une photo du téléphone → au hasard
    w.applyFromPhone('asset:7');
    expect(w.shown, 'asset:7');
    w.applyFromPhone('random');
    expect(w.shown, startsWith('asset:'));
  });

  testWidgets('Fond d\'écran derrière les pages, choix de l\'image',
      (tester) async {
    tester.view.physicalSize = const Size(2160, 1080);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    Tv.skin.value = AppSkin.wallpaper;
    await tester.pumpWidget(MaterialApp(
        theme: Tv.theme(),
        builder: Tv.appBuilder,
        home: const Scaffold(
            body: SingleChildScrollView(child: WallpaperPicker()))));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(Image), findsWidgets);
    expect(find.text('AU HASARD'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('wall-asset:2')));
    await tester.pump(const Duration(milliseconds: 800));
    expect(Wallpaper.instance.choice, 'asset:2');
    expect(Wallpaper.instance.shown, 'asset:2');
    expect(tester.takeException(), isNull);
  });
}
