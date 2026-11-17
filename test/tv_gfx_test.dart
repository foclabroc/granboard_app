import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granboard_proto/tv/tv_gfx.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('granboard/device'),
            (c) async {
      calls.add(c);
      if (c.method == 'gfxInfo') {
        return {'engine': 'skia', 'display': '', 'size': '1920×1080'};
      }
      return null;
    });
    TvGfx.enabled = true;
    TvGfx.engine = 'skia';
    TvGfx.video = 'auto';
    TvGfx.hwFailed = false;
  });

  tearDown(() => TvGfx.enabled = false);

  test('Décodeur matériel au départ, logiciel après un échec', () async {
    await TvGfx.load();
    expect(calls.last.method, 'videoSoftware');
    expect(calls.last.arguments, false);
    await TvGfx.videoFailed();
    expect(calls.last.arguments, true);
    expect((await SharedPreferences.getInstance()).getBool(TvGfx.kHwFail), true);
    // Le téléphone passe en logiciel puis revient en auto : on réessaie
    await TvGfx.apply({'render': 'skia', 'video': 'sw'});
    await TvGfx.apply({'render': 'skia', 'video': 'auto'});
    expect(TvGfx.softwareVideo, false);
    expect(calls.last.arguments, false);
  });

  test('Skia par défaut ; Impeller demandé : gardé puis redémarrage', () async {
    await TvGfx.load();
    expect(TvGfx.engine, 'skia');
    // téléphone en 0.6.22-0.6.23 : « engine » impeller ignoré
    await TvGfx.apply({'engine': 'impeller', 'video': 'auto'});
    await TvGfx.apply({'render': 'skia', 'video': 'auto'});
    expect(calls.where((c) => c.method == 'restart'), isEmpty);
    await TvGfx.apply({'render': 'impeller', 'video': 'auto'});
    expect(calls.last.method, 'restart');
    expect((await SharedPreferences.getInstance()).getString(TvGfx.kEngine),
        'impeller');
    expect(TvGfx.label, contains('SKIA'));
  });
}
