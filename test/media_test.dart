import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:granboard_proto/media.dart';
import 'package:granboard_proto/players.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_server.dart';

void main() {
  late FakeServer server;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    server = FakeServer()..install();
    await PlayerStore.instance.load();
    MediaStore.instance.debugClear();
    await MediaStore.instance.load();
  });

  test('Photo recadrée au carré, 256 px, JPEG léger', () {
    final big = img.Image(width: 1200, height: 800);
    img.fill(big, color: img.ColorRgb8(200, 30, 40));
    final jpeg = MediaStore.squareJpeg(Uint8List.fromList(img.encodePng(big)));
    final back = img.decodeJpg(jpeg)!;
    expect(back.width, 256);
    expect(back.height, 256);
    expect(base64Encode(jpeg).startsWith('/9j/'), isTrue);
    expect(jpeg.length, lessThan(55000));
  });

  test('Photo et son envoyés, puis relus par un autre appareil', () async {
    final foc = await PlayerStore.instance.register('Foc', '1234');
    final jpeg = MediaStore.squareJpeg(
        Uint8List.fromList(img.encodePng(img.Image(width: 300, height: 300))));
    await MediaStore.instance.setPhoto(foc, jpeg);
    await MediaStore.instance.setSound(foc, 'fanfare');
    expect(MediaStore.instance.imageOf(foc.key), isNotNull);
    expect(MediaStore.instance.soundOf(foc.key), 'fanfare');

    // Autre appareil (TV) : cache vide → tout est téléchargé
    MediaStore.instance.debugClear();
    await MediaStore.instance.ensure([foc.key, 'guest-1']);
    expect(MediaStore.instance.of(foc.key)!.photo, jpeg);
    expect(MediaStore.instance.soundOf(foc.key), 'fanfare');
    expect(MediaStore.instance.of('guest-1'), isNull);

    // Voix
    final voice = Uint8List.fromList([1, 2, 3, 4]);
    await MediaStore.instance.setSound(foc, kVoiceSound, voice: voice);
    MediaStore.instance.debugClear();
    await MediaStore.instance.ensure([foc.key]);
    expect(MediaStore.instance.voiceOf(foc.key), voice);
    expect(server.media[foc.id]!['v'], 3);

    // Retirer la photo
    await MediaStore.instance.setPhoto(foc, null);
    expect(MediaStore.instance.imageOf(foc.key), isNull);
  });

  test('Hors ligne : le cache reste', () async {
    final foc = await PlayerStore.instance.register('Foc', '1234');
    await MediaStore.instance.setSound(foc, 'gong');
    server.offline = true;
    await MediaStore.instance.ensure([foc.key]);
    expect(MediaStore.instance.soundOf(foc.key), 'gong');
  });
}
