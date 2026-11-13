import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../ui/theme.dart';
import 'tv_client.dart';

/// Caméra d'un écran (tablette) affichée sur un autre écran (TV), à la
/// demande du téléphone qui pilote (état « cam » : {from, to, sid, front,
/// pos, size, name}). L'écran [from] filme et envoie l'image, l'écran [to]
/// l'affiche. Les 2 écrans s'échangent la mise en relation (WebRTC) par le
/// serveur (`gb_tv_signal`), puis l'image passe en direct par le Wi-Fi.
///
/// Mise en relation : l'émetteur envoie une offre dès qu'il démarre et à
/// chaque « hello » du récepteur (récepteur arrivé après, connexion perdue) ;
/// les messages portent l'identifiant de session [sid] du téléphone : ceux
/// d'une ancienne session sont ignorés. Image seulement, pas de son.
class ScreenCam extends ChangeNotifier {
  ScreenCam(this.client);
  final TvClient client;

  /// Faux en test (pas de WebRTC) : seul l'emplacement est affiché.
  static bool enabled = true;

  /// État « cam » du téléphone, si cet écran est concerné.
  Map<String, dynamic>? cam;

  /// 'send' (cet écran filme) | 'recv' (cet écran affiche) | null.
  String? role;
  String? _sid;
  String? _peer;

  RTCVideoRenderer? renderer;
  bool connected = false;
  String? error;

  RTCPeerConnection? _pc;
  MediaStream? _stream;
  StreamSubscription<Map<String, dynamic>>? _sub;
  final _candidates = <RTCIceCandidate>[];
  bool _remoteSet = false;
  Future<void> _queue = Future.value();
  Timer? _retry;
  int _gen = 0;

  bool get front => cam?['front'] == true;

  /// Nouvel état du téléphone.
  void update(Map? c) {
    final me = client.code;
    String? r;
    if (c != null && me != null) {
      if (c['from'] == me) {
        r = 'send';
      } else if (c['to'] == me) {
        r = 'recv';
      }
    }
    final sid = r == null ? null : '${c!['sid']}';
    final before = cam;
    cam = r == null ? null : Map<String, dynamic>.from(c!);
    if (sid != _sid || r != role) {
      _stop();
      role = r;
      _sid = sid;
      _peer =
          r == 'send' ? '${c!['to']}' : (r == 'recv' ? '${c!['from']}' : null);
      if (r != null) _start();
    } else if (r == 'send' && (before?['front'] == true) != front) {
      _flip();
    }
    notifyListeners();
  }

  Future<void> _start() async {
    final gen = ++_gen;
    error = null;
    connected = false;
    client.signalsWanted = true;
    _sub =
        client.signals.listen((m) => _queue = _queue.then((_) => _handle(m)));
    if (!enabled) return;
    try {
      final r = RTCVideoRenderer();
      await r.initialize();
      if (gen != _gen) {
        await r.dispose();
        return;
      }
      renderer = r;
      if (role == 'send') {
        final ok = await Permission.camera.request();
        if (!ok.isGranted) {
          error = 'Caméra refusée sur cet appareil';
          notifyListeners();
          return;
        }
        final s = await navigator.mediaDevices.getUserMedia({
          'audio': false,
          'video': {
            'facingMode': front ? 'user' : 'environment',
            'width': {'ideal': 1280},
            'height': {'ideal': 720},
            'frameRate': {'ideal': 24},
          },
        });
        if (gen != _gen) {
          for (final t in s.getTracks()) {
            await t.stop();
          }
          return;
        }
        _stream = s;
        r.srcObject = s; // aperçu sur l'écran qui filme
        notifyListeners();
        await _offer(gen);
        // Pas de réponse : on renvoie l'offre de temps en temps
        _retry = Timer.periodic(const Duration(seconds: 10), (_) {
          if (!connected) _queue = _queue.then((_) => _offer(gen));
        });
      } else {
        await _send({'t': 'hello'});
      }
      client.fetchSignals();
      notifyListeners();
    } catch (_) {
      error = 'Vidéo indisponible';
      notifyListeners();
    }
  }

  Future<void> _newPeer(int gen) async {
    final old = _pc;
    _pc = null;
    _remoteSet = false;
    _candidates.clear();
    try {
      await old?.close();
    } catch (_) {}
    final ice = client.ice.isNotEmpty
        ? client.ice
        : const [
            {
              'urls': ['stun:stun.l.google.com:19302']
            }
          ];
    final pc = await createPeerConnection(
        {'iceServers': ice, 'sdpSemantics': 'unified-plan'});
    if (gen != _gen) {
      await pc.close();
      return;
    }
    _pc = pc;
    final s = _stream;
    if (s != null) {
      for (final t in s.getVideoTracks()) {
        await pc.addTrack(t, s);
      }
    }
    pc.onIceCandidate = (c) {
      if (c.candidate == null || !identical(pc, _pc)) return;
      _send({'t': 'ice', 'c': c.toMap()});
    };
    pc.onTrack = (e) {
      if (e.streams.isEmpty || !identical(pc, _pc) || role != 'recv') return;
      renderer?.srcObject = e.streams.first;
      notifyListeners();
    };
    pc.onConnectionState = (st) {
      if (!identical(pc, _pc)) return;
      final ok = st == RTCPeerConnectionState.RTCPeerConnectionStateConnected;
      if (ok != connected) {
        connected = ok;
        notifyListeners();
      }
      if (st == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        // Connexion perdue : on recommence
        Timer(const Duration(seconds: 2), () {
          if (gen != _gen) return;
          if (role == 'send') {
            _queue = _queue.then((_) => _offer(gen));
          } else {
            _send({'t': 'hello'});
          }
        });
      }
    };
  }

  Future<void> _offer(int gen) async {
    if (gen != _gen || role != 'send') return;
    await _newPeer(gen);
    final pc = _pc;
    if (pc == null) return;
    final offer = await pc.createOffer(
        {'offerToReceiveAudio': false, 'offerToReceiveVideo': false});
    await pc.setLocalDescription(offer);
    await _send({'t': 'offer', 'sdp': offer.sdp});
  }

  Future<bool> _send(Map<String, dynamic> m) async {
    final to = _peer, sid = _sid;
    if (to == null || sid == null) return false;
    return client.signal(to, {...m, 'sid': sid});
  }

  Future<void> _handle(Map<String, dynamic> m) async {
    final gen = _gen;
    if (m['sid'] != _sid || m['from'] != _peer || role == null) return;
    if (!enabled) return;
    try {
      switch (m['t']) {
        case 'hello':
          if (role == 'send' && _stream != null) await _offer(gen);
        case 'offer':
          if (role != 'recv') return;
          await _newPeer(gen);
          final pc = _pc;
          if (pc == null) return;
          await pc.setRemoteDescription(
              RTCSessionDescription('${m['sdp']}', 'offer'));
          await _drain();
          final answer = await pc.createAnswer();
          await pc.setLocalDescription(answer);
          await _send({'t': 'answer', 'sdp': answer.sdp});
        case 'answer':
          if (role != 'send' || _pc == null) return;
          await _pc!.setRemoteDescription(
              RTCSessionDescription('${m['sdp']}', 'answer'));
          await _drain();
        case 'ice':
          if (_pc == null) return;
          final c = Map<String, dynamic>.from(m['c'] as Map);
          final cand = RTCIceCandidate('${c['candidate']}',
              c['sdpMid'] as String?, (c['sdpMLineIndex'] as num?)?.toInt());
          if (_remoteSet) {
            await _pc!.addCandidate(cand);
          } else {
            _candidates.add(cand);
          }
      }
    } catch (_) {
      // message d'une connexion remplacée : sans effet
    }
  }

  Future<void> _drain() async {
    _remoteSet = true;
    for (final c in _candidates) {
      await _pc?.addCandidate(c);
    }
    _candidates.clear();
  }

  Future<void> _flip() async {
    final tracks = _stream?.getVideoTracks() ?? const [];
    if (tracks.isEmpty) return;
    try {
      await Helper.switchCamera(tracks.first);
      notifyListeners();
    } catch (_) {}
  }

  void _stop() {
    _gen++;
    _retry?.cancel();
    _retry = null;
    _sub?.cancel();
    _sub = null;
    client.signalsWanted = false;
    connected = false;
    final pc = _pc, s = _stream, r = renderer;
    _pc = null;
    _stream = null;
    renderer = null;
    () async {
      try {
        await pc?.close();
        for (final t in s?.getTracks() ?? const <MediaStreamTrack>[]) {
          await t.stop();
        }
        await s?.dispose();
        r?.srcObject = null;
        await r?.dispose();
      } catch (_) {}
    }();
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }
}

/// Image de la caméra sur l'écran qui la reçoit (coin choisi ou plein
/// écran), ou petit aperçu « EN DIRECT » sur l'écran qui filme. À poser
/// au-dessus de tout dans un Stack.
class ScreenCamLayer extends StatelessWidget {
  final ScreenCam cam;
  const ScreenCamLayer({super.key, required this.cam});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: cam,
      builder: (context, _) {
        final c = cam.cam;
        if (c == null || cam.role == null) return const SizedBox.shrink();
        return LayoutBuilder(builder: (context, box) {
          if (cam.role == 'send') {
            final w = (box.maxWidth * 0.18).clamp(120.0, 220.0);
            return Stack(children: [
              Positioned(
                right: 12,
                bottom: 12,
                child: _Frame(
                  key: const ValueKey('cam-preview'),
                  width: w,
                  cam: cam,
                  label: 'EN DIRECT',
                  live: true,
                ),
              ),
            ]);
          }
          final pos = '${c['pos'] ?? 'tr'}';
          if (pos == 'full') {
            return Container(
              key: const ValueKey('cam-full'),
              color: Colors.black,
              child: _Video(cam: cam, fit: true),
            );
          }
          final f = switch (c['size']) { 's' => 0.24, 'l' => 0.46, _ => 0.34 };
          final w = box.maxWidth * f;
          const m = 14.0;
          return Stack(children: [
            Positioned(
              left: pos.endsWith('l') ? m : null,
              right: pos.endsWith('r') ? m : null,
              top: pos.startsWith('t') ? m + 44 : null,
              bottom: pos.startsWith('b') ? m : null,
              child: _Frame(
                key: const ValueKey('cam-view'),
                width: w,
                cam: cam,
                label: 'CAMÉRA ${'${c['name'] ?? ''}'.toUpperCase()}',
              ),
            ),
          ]);
        });
      },
    );
  }
}

class _Frame extends StatelessWidget {
  final double width;
  final ScreenCam cam;
  final String label;
  final bool live;
  const _Frame(
      {super.key,
      required this.width,
      required this.cam,
      required this.label,
      this.live = false});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: width,
        height: width * 9 / 16,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: cam.connected ? Tv.gold : Tv.line, width: 2.5),
          boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 14)],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _Video(cam: cam),
            Positioned(
              left: 8,
              top: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: cam.connected || live ? Tv.red : Tv.muted,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(label,
                        style: Tv.title(width < 200 ? 11 : 14,
                            color: Colors.white)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Video extends StatelessWidget {
  final ScreenCam cam;
  final bool fit;
  const _Video({required this.cam, this.fit = false});

  @override
  Widget build(BuildContext context) {
    final r = cam.renderer;
    final waiting = cam.role == 'recv' && !cam.connected;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (r != null && !waiting)
          RTCVideoView(r,
              mirror: cam.front,
              objectFit: fit
                  ? RTCVideoViewObjectFit.RTCVideoViewObjectFitContain
                  : RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
        else
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.videocam, color: Tv.muted, size: 32),
                const SizedBox(height: 4),
                Text(cam.error ?? 'CONNEXION…',
                    textAlign: TextAlign.center,
                    style: Tv.label(12, color: Tv.text)),
              ],
            ),
          ),
      ],
    );
  }
}
