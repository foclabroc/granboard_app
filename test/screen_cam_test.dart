import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granboard_proto/players.dart';
import 'package:granboard_proto/tv/screen_cam.dart';
import 'package:granboard_proto/tv/tv_client.dart';
import 'package:granboard_proto/tv/tv_home.dart';
import 'package:granboard_proto/tv_link.dart';
import 'package:granboard_proto/ui/theme.dart';
import 'package:granboard_proto/ui/tv_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_server.dart';

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  late TvClient tv, tab;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FakeServer().install();
    await PlayerStore.instance.load();
    await TvLink.instance.load();
    tv = TvClient(realtime: false);
    await tv.start();
    tab = TvClient(realtime: false, deviceName: 'Tablette', prefKey: 'tab');
    await tab.start();
    await TvLink.instance.link(tv.code!);
    await TvLink.instance.link(tab.code!);
  });

  tearDown(() {
    tv.dispose();
    tab.dispose();
  });

  test(
      'Caméra tablette → TV : demandée par le téléphone, messages entre écrans',
      () async {
    final link = TvLink.instance;
    // sans demande du téléphone, les écrans ne se parlent pas
    expect(await tab.signal(tv.code!, {'t': 'hello'}), isFalse);

    link.startCam(tab.code!, tv.code!);
    await settle();
    await tv.fetch();
    await tab.fetch();
    final c = tv.state!['cam'] as Map;
    expect(c['from'], tab.code);
    expect(c['to'], tv.code);
    expect(c['front'], false);
    expect(c['name'], 'Tablette');

    final camTv = ScreenCam(tv)..update(c);
    final camTab = ScreenCam(tab)..update(tab.state!['cam'] as Map);
    expect(camTv.role, 'recv');
    expect(camTab.role, 'send');
    expect(tv.signalsWanted, isTrue);

    final got = <Map>[];
    tv.signals.listen(got.add);
    expect(await tab.signal(tv.code!, {'t': 'offer', 'sid': c['sid']}), isTrue);
    await tv.fetchSignals();
    await settle();
    expect(got.single['from'], tab.code);
    expect(got.single['t'], 'offer');
    await tv.fetchSignals(); // déjà lu
    await settle();
    expect(got, hasLength(1));

    // réglages : position, taille, avant/arrière (même session)
    link.setCam(pos: 'full', front: true);
    await settle();
    await tv.fetch();
    camTv.update(tv.state!['cam'] as Map);
    expect(camTv.cam!['pos'], 'full');
    expect(camTv.role, 'recv');

    // arrêt
    link.stopCam();
    await settle();
    await tv.fetch();
    camTv.update(tv.state!['cam'] as Map?);
    expect(camTv.role, isNull);
    expect(tv.signalsWanted, isFalse);
    expect(await tab.signal(tv.code!, {'t': 'hello'}), isFalse);

    // écran retiré : caméra arrêtée
    link.startCam(tab.code!, tv.code!);
    await link.unlink(tab.code!);
    expect(link.cam, isNull);
    camTv.dispose();
    camTab.dispose();
  });

  testWidgets('Écran TV : image de la tablette dans le coin, plein écran',
      (tester) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tv.debugSetState(tv.code!, {
      'screen': 'lobby',
      'host': 'Foc',
      'cam': {
        'from': tab.code,
        'to': tv.code,
        'sid': '1',
        'pos': 'br',
        'size': 'm',
        'name': 'Tablette',
      },
    });
    await tester
        .pumpWidget(MaterialApp(theme: Tv.theme(), home: TvHome(client: tv)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('cam-view')), findsOneWidget);
    expect(find.text('CAMÉRA TABLETTE'), findsOneWidget);
    expect(tester.takeException(), isNull);

    tv.debugSetState(tv.code!, {
      'screen': 'lobby',
      'cam': {'from': tab.code, 'to': tv.code, 'sid': '1', 'pos': 'full'},
    });
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('cam-full')), findsOneWidget);

    // la tablette qui filme : petit aperçu « EN DIRECT »
    await tester.pumpWidget(const SizedBox());
    tab.debugSetState(tab.code!, {
      'screen': 'lobby',
      'cam': {'from': tab.code, 'to': tv.code, 'sid': '1'},
    });
    await tester
        .pumpWidget(MaterialApp(theme: Tv.theme(), home: TvHome(client: tab)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('cam-preview')), findsOneWidget);
    expect(find.text('EN DIRECT'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('Téléphone : panneau caméra de la fenêtre TV', (tester) async {
    tester.view.physicalSize = const Size(785, 392) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        theme: Tv.theme(),
        home: const Scaffold(body: SingleChildScrollView(child: CamPanel()))));
    await tester.pump();
    // par défaut : la tablette filme, la TV affiche
    expect(
        tester
            .widget<ChoiceChip>(find.byKey(ValueKey('cam-from-${tab.code}')))
            .selected,
        isTrue);
    await tester.tap(find.byKey(const ValueKey('cam-toggle')));
    await tester.pump();
    expect(TvLink.instance.cam?['from'], tab.code);
    expect(TvLink.instance.cam?['to'], tv.code);
    await tester.tap(find.byKey(const ValueKey('cam-pos-bl')));
    await tester.pump();
    expect(TvLink.instance.cam?['pos'], 'bl');
    await tester.tap(find.byKey(const ValueKey('cam-front')));
    await tester.pump();
    expect(TvLink.instance.cam?['front'], true);
    expect(find.text('CAMÉRA AVANT'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('cam-toggle')));
    await tester.pump();
    expect(TvLink.instance.cam, isNull);
    await tester.pump(const Duration(seconds: 1));
  });
}
