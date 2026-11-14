import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:granboard_proto/audio.dart';
import 'package:granboard_proto/game/x01.dart';
import 'package:granboard_proto/granboard.dart';
import 'package:granboard_proto/players.dart';
import 'package:granboard_proto/tv/tv_client.dart';
import 'package:granboard_proto/tv/tv_home.dart';
import 'package:granboard_proto/ui/award.dart';
import 'package:granboard_proto/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_server.dart';

void main() {
  testWidgets(
      'Écran TV : vidéo du T20 lancée, erreur affichée, son habituel à la place',
      (tester) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    FakeServer().install();
    await PlayerStore.instance.load();
    final tv = TvClient(realtime: false);
    const ps = [
      X01Player(id: 'guest-1', name: 'Ana'),
      X01Player(id: 'guest-2', name: 'Bob'),
    ];
    final g = X01Game(const X01Settings(startScore: 501), ps);
    Map<String, dynamic> state() =>
        {'screen': 'game', 'host': 'Foc', 'game': g.toJson(), 'sound': true};
    tv.debugSetState('ABCD', state());
    await tester
        .pumpWidget(MaterialApp(theme: Tv.theme(), home: TvHome(client: tv)));
    await tester.pump(const Duration(seconds: 1));

    AudioService.instance
      ..voice = true
      ..dartCalls = true
      ..said.clear();
    AwardPlayer.enabled = true;
    addTearDown(() => AwardPlayer.enabled = false);
    g.throwDart(const DartHit(20, 3, Ring.triple));
    tv.debugSetState('ABCD', state());
    await tester.pump();
    expect(AwardPlayer.active, isTrue); // la TV lance bien la vidéo
    // Pas de lecteur vidéo en test : l'erreur s'affiche sur l'écran
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const ValueKey('video-error')), findsOneWidget);
    expect(AwardPlayer.active, isFalse);
    // … et l'annonce de la fléchette à la place du son de la vidéo
    expect(AudioService.instance.said, contains('triple 20'));
    await tester.pump(const Duration(seconds: 9));
    expect(find.byKey(const ValueKey('video-error')), findsNothing);
    AwardPlayer.enabled = false;
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets(
      'Écran TV : même état reçu 2 fois (serveur + Wi-Fi, champs dans un autre ordre) → effets gardés',
      (tester) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    FakeServer().install();
    await PlayerStore.instance.load();
    final tv = TvClient(realtime: false);
    const ps = [
      X01Player(id: 'guest-1', name: 'Ana'),
      X01Player(id: 'guest-2', name: 'Bob'),
    ];
    final g = X01Game(const X01Settings(startScore: 501), ps);
    // Wi-Fi : ordre d'origine ; serveur (jsonb) : clés réordonnées
    Map<String, dynamic> wifi() =>
        {'screen': 'game', 'game': g.toJson(), 'sound': true};
    Map<String, dynamic> server() {
      Object? rev(Object? x) => switch (x) {
            Map m => {
                for (final k in m.keys.toList().reversed) '$k': rev(m[k])
              },
            List l => [for (final e in l) rev(e)],
            _ => x,
          };
      return Map<String, dynamic>.from(rev(wifi()) as Map);
    }

    tv.debugSetState('ABCD', wifi());
    await tester
        .pumpWidget(MaterialApp(theme: Tv.theme(), home: TvHome(client: tv)));
    await tester.pump(const Duration(seconds: 1));
    g.throwDart(const DartHit(5, 1, Ring.singleOuter));
    tv.debugSetState('ABCD', wifi());
    await tester.pump();
    tv.debugSetState('ABCD', server()); // le même, par le serveur
    await tester.pump();
    AwardPlayer.enabled = true;
    addTearDown(() => AwardPlayer.enabled = false);
    g.throwDart(const DartHit(20, 3, Ring.triple));
    tv.debugSetState('ABCD', wifi()); // arrive d'abord par le Wi-Fi
    await tester.pump();
    expect(AwardPlayer.active, isTrue);
    AwardPlayer.stop();
    AwardPlayer.enabled = false;
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  test('Doublon (même heure d\'envoi) ignoré, plus récent gardé', () {
    final tv = TvClient(realtime: false);
    var n = 0;
    tv.addListener(() => n++);
    tv.debugApplyState({'screen': 'lobby', 'at': 100});
    tv.debugApplyState({'screen': 'lobby', 'at': 100}); // 2e chemin
    tv.debugApplyState({'screen': 'game', 'at': 90}); // plus ancien
    expect(n, 1);
    tv.debugApplyState({'screen': 'game', 'at': 101});
    expect(n, 2);
    expect(tv.state!['screen'], 'game');
    // Un autre téléphone dont l'horloge retarde : pas ignoré
    tv.debugApplyState({'screen': 'lobby', 'at': 50, 'src': 'ami'});
    expect(n, 3);
    expect(tv.state!['screen'], 'lobby');
    tv.debugApplyState({'screen': 'lobby', 'at': 50, 'src': 'ami'});
    expect(n, 3); // son doublon, si
  });

  test('Erreur vidéo : l\'essentiel du message d\'ExoPlayer', () {
    const e = 'PlatformException(VideoError, Video player had error '
        'or: MediaCodecVideoRenderer error, index=0, format=Format(1, null, '
        'video/mp4, video/avc, avc1.640028, 4500000, und, [1280, 720, 30.0, '
        'ColorInfo(BT709, Limited range, SDR SMPTE 170M, false, 8bit Luma, '
        '8bit Chroma)], [-1, -1]), format_supported=YES, null, null)';
    expect(videoErrorSummary(e, camera: true),
        'format accepté mais décodeur en échec · caméra en cours');
    expect(videoErrorSummary('Decoder init failed: OMX.MTK.VIDEO.DECODER.AVC, '
            'Format(…), format_supported=NO_EXCEEDS_CAPABILITIES'),
        'vidéo trop lourde pour le décodeur · Decoder init failed: '
        'OMX.MTK.VIDEO.DECODER.AVC');
    // causes ajoutées par la copie locale du lecteur
    expect(
        videoErrorSummary('Video player had error ExoPlaybackException: '
            'MediaCodecVideoRenderer error, index=0, format_supported=YES | '
            'cause: androidx.media3.exoplayer.mediacodec.MediaCodecRenderer'
            '\$DecoderInitializationException: Decoder init failed: '
            'OMX.MTK.VIDEO.DECODER.AVC, Format(1, null) | cause: '
            'android.media.MediaCodec\$CodecException: Error 0xfffffff4'),
        'format accepté mais décodeur en échec · Decoder init failed: '
        'OMX.MTK.VIDEO.DECODER.AVC · Error 0xfffffff4');
    // inconnu : la fin du message (où est la cause)
    final long = 'x' * 300 + 'CAUSE';
    expect(videoErrorSummary(long), endsWith('CAUSE'));
  });
}
