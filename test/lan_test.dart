import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:granboard_proto/lan.dart';

void main() {
  setUp(() => Lan.enabled = true);
  tearDown(() => Lan.enabled = false);

  test('Wi-Fi local : l\'écran répond à son code et reçoit l\'état', () async {
    var code = 'KX7P';
    Map<String, dynamic>? got;
    final tv = LanServer(code: () => code, name: 'TV', onState: (s) => got = s);
    await tv.start(httpPort: 0, udpPort: 47912);
    addTearDown(tv.close);
    expect(tv.port, greaterThan(0));

    final lo = [InternetAddress.loopbackIPv4];
    expect(await Lan.discover('ZZZZ', targets: lo, udpPort: 47912), isNull);
    final f = await Lan.discover('kx7p', targets: lo, udpPort: 47912);
    expect(f, isNotNull);
    expect(f!.name, 'TV');
    expect(f.address, '127.0.0.1:${tv.port}');

    expect(await Lan.push(f.address, 'KX7P', {'screen': 'lobby'}), isTrue);
    expect(got?['screen'], 'lobby');

    // Nouveau code sur l'écran : l'ancien téléphone est refusé
    code = 'AB12';
    got = null;
    expect(await Lan.push(f.address, 'KX7P', {'screen': 'game'}), isFalse);
    expect(got, isNull);
  });
}
