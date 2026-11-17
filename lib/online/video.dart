import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../ui/theme.dart';
import 'online.dart';

/// Appel vidéo avec les autres maisons d'une partie en ligne (WebRTC) :
/// image et son passent en direct entre les téléphones (ou par le relais
/// TURN du serveur maison si c'est impossible) ; le serveur ne transporte
/// que les messages de mise en relation (par la salle).
///
/// Une liaison par autre maison (salon : jusqu'à 3). Mise en relation :
/// chacun annonce sa session (« ready », avec un identifiant tiré au hasard
/// et sa maison) ; pour chaque paire, la maison la plus petite (a avant b,
/// h1 avant h2) envoie l'offre. Les messages d'une ancienne session (appli
/// relancée) sont ignorés grâce à ces identifiants.
class VideoCall extends ChangeNotifier {
  VideoCall(this.room);
  final OnlineRoom room;

  final local = RTCVideoRenderer();

  bool camOn = true;
  bool micOn = true;
  bool front = true;

  /// Caméra et micro disponibles (autorisations données).
  bool ready = false;
  String? error;

  /// Liaisons avec les autres maisons (clé = maison : b, a, h2…).
  final peers = <String, VideoPeer>{};

  /// L'image d'au moins une autre maison arrive.
  bool get connected => peers.values.any((p) => p.connected);

  /// Image de la maison [home] (1 contre 1 : la seule).
  VideoPeer? peerOf(String home) => peers[home];

  /// 1 contre 1 : image de l'adversaire.
  RTCVideoRenderer? get remote =>
      peers.isEmpty ? null : peers.values.first.renderer;

  final _sid = '${Random().nextInt(1 << 31)}';
  MediaStream? _stream;
  StreamSubscription<Map<String, dynamic>>? _sub;
  bool _closed = false;

  Future<void> start() async {
    try {
      await local.initialize();
      final perms = await [Permission.camera, Permission.microphone].request();
      final cam = perms[Permission.camera]?.isGranted ?? false;
      final mic = perms[Permission.microphone]?.isGranted ?? false;
      if (!cam && !mic) {
        error = 'Caméra et micro refusés';
        notifyListeners();
      } else {
        camOn = cam;
        micOn = mic;
        // Salon : image plus petite (jusqu'à 3 envois en même temps)
        final many = room.isSalon && room.homes.length > 2;
        _stream = await navigator.mediaDevices.getUserMedia({
          'audio': mic
              ? {
                  'echoCancellation': true,
                  'noiseSuppression': true,
                  'autoGainControl': true
                }
              : false,
          'video': cam
              ? {
                  'facingMode': 'user',
                  'width': {'ideal': many ? 320 : 480},
                  'height': {'ideal': many ? 240 : 360},
                  'frameRate': {'ideal': many ? 12 : 15},
                }
              : false,
        });
        local.srcObject = _stream;
        try {
          await Helper.setSpeakerphoneOn(true);
        } catch (_) {}
      }
      if (_closed) return;
      ready = true;
      room.addListener(_onRoom);
      // Même sans caméra ni micro, on reçoit l'image des autres
      _sub = room.signals.listen(_onSignal);
      await _ready();
      notifyListeners();
    } catch (e) {
      error = 'Vidéo indisponible';
      notifyListeners();
    }
  }

  String get _me => room.side;

  /// Maison qui envoie le message : donnée par le serveur (salon), écrite
  /// dans le message, sinon l'autre côté du 1 contre 1.
  String _homeOf(Map<String, dynamic> m) {
    final h = m['_from'] ?? m['home'];
    if (h != null) return '$h';
    return _me == 'a' ? 'b' : 'a';
  }

  Future<void> _ready({String? ack}) => room.signal(
      {'type': 'ready', 'sid': _sid, 'home': _me, if (ack != null) 'ack': ack});

  /// Une maison a quitté la partie : sa liaison est fermée.
  void _onRoom() {
    var changed = false;
    for (final h in room.homes) {
      if (!h.left) continue;
      final p = peers.remove(h.home);
      if (p != null) {
        p.dispose();
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  Future<VideoPeer> _newPeer(String home, String sid) async {
    peers.remove(home)?.dispose();
    final peer = VideoPeer(home, sid);
    peers[home] = peer;
    await peer.renderer.initialize();
    final pc = await createPeerConnection({
      'iceServers': room.ice,
      'sdpSemantics': 'unified-plan',
    });
    if (!identical(peers[home], peer) || _closed) {
      await pc.close();
      return peer;
    }
    peer.pc = pc;
    final s = _stream;
    if (s != null) {
      for (final t in s.getTracks()) {
        await pc.addTrack(t, s);
      }
    }
    pc.onIceCandidate = (c) {
      if (c.candidate == null || !identical(peers[home], peer)) return;
      _send(peer, {'type': 'ice', 'c': c.toMap()});
    };
    pc.onTrack = (e) {
      if (e.streams.isEmpty || !identical(peers[home], peer)) return;
      peer.renderer.srcObject = e.streams.first;
      notifyListeners();
    };
    pc.onConnectionState = (st) {
      if (!identical(peers[home], peer)) return;
      final ok = st == RTCPeerConnectionState.RTCPeerConnectionStateConnected;
      if (ok != peer.connected) {
        peer.connected = ok;
        notifyListeners();
      }
      if (st == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        // Connexion perdue : on recommence la mise en relation
        peer.sid = null;
        _ready();
      }
    };
    return peer;
  }

  void _send(VideoPeer p, Map<String, dynamic> m) =>
      room.signal({...m, 'from': _sid, 'to': p.sid, 'home': _me});

  Future<void> _queue = Future.value();

  /// Les messages sont traités un par un, dans l'ordre.
  void _onSignal(Map<String, dynamic> m) =>
      _queue = _queue.then((_) => _handle(m));

  Future<void> _handle(Map<String, dynamic> m) async {
    if (_closed) return;
    final home = _homeOf(m);
    if (home == _me || room.goneHome(home)) return;
    try {
      switch (m['type']) {
        case 'ready':
          final sid = '${m['sid']}';
          if (sid == peers[home]?.sid) return;
          final peer = await _newPeer(home, sid);
          if (m['ack'] != _sid) await _ready(ack: sid);
          // Pour chaque paire, la plus petite maison fait l'offre
          if (_me.compareTo(home) < 0 && peer.pc != null) {
            final offer = await peer.pc!.createOffer(
                {'offerToReceiveAudio': true, 'offerToReceiveVideo': true});
            await peer.pc!.setLocalDescription(offer);
            _send(peer, {'type': 'offer', 'sdp': offer.sdp});
          }
          notifyListeners();
        case 'offer':
          final p = peers[home];
          if (p?.pc == null || m['to'] != _sid || m['from'] != p!.sid) return;
          await p.pc!.setRemoteDescription(
              RTCSessionDescription('${m['sdp']}', 'offer'));
          await p.drain();
          final answer = await p.pc!.createAnswer();
          await p.pc!.setLocalDescription(answer);
          _send(p, {'type': 'answer', 'sdp': answer.sdp});
        case 'answer':
          final p = peers[home];
          if (p?.pc == null || m['to'] != _sid || m['from'] != p!.sid) return;
          await p.pc!.setRemoteDescription(
              RTCSessionDescription('${m['sdp']}', 'answer'));
          await p.drain();
        case 'ice':
          final p = peers[home];
          if (p?.pc == null || m['to'] != _sid || m['from'] != p!.sid) return;
          final c = Map<String, dynamic>.from(m['c'] as Map);
          final cand = RTCIceCandidate('${c['candidate']}',
              c['sdpMid'] as String?, (c['sdpMLineIndex'] as num?)?.toInt());
          if (p.remoteSet) {
            await p.pc!.addCandidate(cand);
          } else {
            p.candidates.add(cand);
          }
      }
    } catch (_) {
      // Message d'une ancienne session ou arrivé trop tard : sans effet
    }
  }

  void toggleCam() {
    final tracks = _stream?.getVideoTracks() ?? const [];
    if (tracks.isEmpty) return;
    camOn = !camOn;
    for (final t in tracks) {
      t.enabled = camOn;
    }
    notifyListeners();
  }

  void toggleMic() {
    final tracks = _stream?.getAudioTracks() ?? const [];
    if (tracks.isEmpty) return;
    micOn = !micOn;
    for (final t in tracks) {
      t.enabled = micOn;
    }
    notifyListeners();
  }

  /// Caméra selfie ↔ caméra arrière (pour montrer la cible).
  Future<void> flip() async {
    final tracks = _stream?.getVideoTracks() ?? const [];
    if (tracks.isEmpty) return;
    try {
      await Helper.switchCamera(tracks.first);
      front = !front;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    room.removeListener(_onRoom);
    await _sub?.cancel();
    try {
      for (final t in _stream?.getTracks() ?? const <MediaStreamTrack>[]) {
        await t.stop();
      }
      await _stream?.dispose();
      for (final p in peers.values) {
        await p.dispose();
      }
      peers.clear();
      local.srcObject = null;
      await local.dispose();
    } catch (_) {}
  }
}

/// Liaison vidéo avec une autre maison.
class VideoPeer {
  VideoPeer(this.home, this.sid);
  final String home;

  /// Session annoncée par l'autre maison (null = à refaire).
  String? sid;
  RTCPeerConnection? pc;
  final renderer = RTCVideoRenderer();
  bool connected = false;
  bool remoteSet = false;
  final candidates = <RTCIceCandidate>[];

  Future<void> drain() async {
    remoteSet = true;
    for (final c in candidates) {
      await pc?.addCandidate(c);
    }
    candidates.clear();
  }

  Future<void> dispose() async {
    try {
      await pc?.close();
      renderer.srcObject = null;
      await renderer.dispose();
    } catch (_) {}
  }
}

/// Vignettes vidéo des autres maisons (une seule en 1 contre 1, jusqu'à 3
/// en salon, les unes sous les autres), à poser dans un Stack : on les
/// déplace au doigt, on les touche pour afficher les boutons (caméra,
/// micro, selfie / arrière, taille).
class VideoBubble extends StatefulWidget {
  final VideoCall call;

  /// Maison → nom affiché (1 contre 1 : une seule entrée).
  final Map<String, String> names;
  const VideoBubble({super.key, required this.call, required this.names});

  @override
  State<VideoBubble> createState() => _VideoBubbleState();
}

class _VideoBubbleState extends State<VideoBubble> {
  Offset _pos = const Offset(8, 8);
  bool _big = false;
  bool _tools = false;
  Timer? _hide;

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  void _showTools() {
    setState(() => _tools = !_tools);
    _hide?.cancel();
    if (_tools) {
      _hide = Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => _tools = false);
      });
    }
  }

  void _keep() {
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _tools = false);
    });
  }

  /// Une vignette : image de la maison [home] (ou du seul adversaire),
  /// avec mon image en petit dans la 1re.
  Widget _tile(VideoCall call, double w, double h, VideoPeer? peer, String name,
      bool first) {
    final on = peer != null && peer.connected;
    return Container(
      width: w,
      height: h,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: on ? Tv.gold : Tv.line, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8)],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (on)
            RTCVideoView(peer.renderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Text(call.error ?? 'Vidéo de $name…',
                    textAlign: TextAlign.center,
                    style: Tv.label(11, color: Tv.text)),
              ),
            ),
          if (widget.names.length > 1)
            Positioned(
              left: 4,
              top: 3,
              child: Text(name.toUpperCase(),
                  style: Tv.label(10, color: Colors.white)
                      .copyWith(shadows: const [Shadow(blurRadius: 3)])),
            ),
          // Mon image, en petit
          if (first && call.ready && call.camOn)
            Positioned(
              right: 4,
              bottom: 4,
              width: w * 0.3,
              height: h * 0.3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: RTCVideoView(call.local,
                    mirror: call.front,
                    objectFit:
                        RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
              ),
            ),
          if (first && !call.micOn)
            const Positioned(
                left: 4,
                bottom: 4,
                child: Icon(Icons.mic_off, size: 16, color: Tv.red)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final call = widget.call;
    final names = widget.names;
    final many = names.length > 1;
    return LayoutBuilder(builder: (context, box) {
      final w = many ? (_big ? 168.0 : 112.0) : (_big ? 248.0 : 140.0);
      final h = w * 3 / 4;
      final total = names.isEmpty ? h : names.length * (h + 4) - 4;
      final maxX = max(0.0, box.maxWidth - max(w, _tools ? 176.0 : 0));
      final maxY = max(0.0, box.maxHeight - total - (_tools ? 40 : 0));
      final pos = Offset(_pos.dx.clamp(0.0, maxX), _pos.dy.clamp(0.0, maxY));
      return Stack(
        children: [
          Positioned(
            left: pos.dx,
            top: pos.dy,
            child: GestureDetector(
              onTap: _showTools,
              onPanUpdate: (d) => setState(() => _pos = Offset(
                  (pos.dx + d.delta.dx).clamp(0.0, maxX),
                  (pos.dy + d.delta.dy).clamp(0.0, maxY))),
              child: ListenableBuilder(
                listenable: call,
                builder: (context, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (names.isEmpty)
                      _tile(call, w, h, null, '…', true)
                    else
                      for (final (i, e) in names.entries.indexed) ...[
                        if (i > 0) const SizedBox(height: 4),
                        _tile(
                            call,
                            w,
                            h,
                            many
                                ? call.peerOf(e.key)
                                : (call.peers.isEmpty
                                    ? null
                                    : call.peers.values.first),
                            e.value,
                            i == 0),
                      ],
                    if (_tools)
                      Container(
                        width: max(w, 176),
                        height: 38,
                        margin: const EdgeInsets.only(top: 2),
                        decoration: BoxDecoration(
                          color: Tv.panel,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Tv.line),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _tool(
                                call.camOn
                                    ? Icons.videocam
                                    : Icons.videocam_off,
                                'Caméra', () {
                              call.toggleCam();
                              _keep();
                            }, off: !call.camOn),
                            _tool(
                                call.micOn ? Icons.mic : Icons.mic_off, 'Micro',
                                () {
                              call.toggleMic();
                              _keep();
                            }, off: !call.micOn),
                            _tool(Icons.cameraswitch, 'Selfie / arrière', () {
                              call.flip();
                              _keep();
                            }),
                            _tool(
                                _big
                                    ? Icons.close_fullscreen
                                    : Icons.open_in_full,
                                'Taille', () {
                              setState(() => _big = !_big);
                              _keep();
                            }),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _tool(IconData icon, String tip, VoidCallback onTap,
          {bool off = false}) =>
      IconButton(
        tooltip: tip,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 40, height: 36),
        iconSize: 20,
        color: off ? Tv.red : Tv.text,
        icon: Icon(icon),
        onPressed: onTap,
      );
}
