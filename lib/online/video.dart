import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../ui/theme.dart';
import 'online.dart';

/// Appel vidéo avec l'adversaire d'une partie en ligne (WebRTC) : image et
/// son passent en direct entre les 2 téléphones ; le serveur ne transporte
/// que les messages de mise en relation (par la salle).
///
/// Mise en relation : chacun annonce sa session (« ready », avec un
/// identifiant tiré au hasard) ; le joueur « a » envoie l'offre dès qu'il
/// connaît la session de l'autre. Les messages d'une ancienne session (appli
/// relancée) sont ignorés grâce à ces identifiants.
class VideoCall extends ChangeNotifier {
  VideoCall(this.room);
  final OnlineRoom room;

  final local = RTCVideoRenderer();
  final remote = RTCVideoRenderer();

  bool camOn = true;
  bool micOn = true;
  bool front = true;

  /// Caméra et micro disponibles (autorisations données).
  bool ready = false;

  /// L'image de l'adversaire arrive.
  bool connected = false;
  String? error;

  final _sid = '${Random().nextInt(1 << 31)}';
  String? _peerSid;
  RTCPeerConnection? _pc;
  MediaStream? _stream;
  StreamSubscription<Map<String, dynamic>>? _sub;
  final _candidates = <RTCIceCandidate>[];
  bool _remoteSet = false;
  bool _closed = false;

  Future<void> start() async {
    try {
      await local.initialize();
      await remote.initialize();
      final perms = await [Permission.camera, Permission.microphone].request();
      final cam = perms[Permission.camera]?.isGranted ?? false;
      final mic = perms[Permission.microphone]?.isGranted ?? false;
      if (!cam && !mic) {
        error = 'Caméra et micro refusés';
        notifyListeners();
      } else {
        camOn = cam;
        micOn = mic;
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
                  'width': {'ideal': 480},
                  'height': {'ideal': 360},
                  'frameRate': {'ideal': 15},
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
      // Même sans caméra ni micro, on reçoit l'image de l'autre
      _sub = room.signals.listen(_onSignal);
      await room.signal({'type': 'ready', 'sid': _sid});
      notifyListeners();
    } catch (e) {
      error = 'Vidéo indisponible';
      notifyListeners();
    }
  }

  Future<void> _newPeer() async {
    final old = _pc;
    _pc = null;
    _remoteSet = false;
    _candidates.clear();
    try {
      await old?.close();
    } catch (_) {}
    final pc = await createPeerConnection({
      'iceServers': room.ice,
      'sdpSemantics': 'unified-plan',
    });
    _pc = pc;
    final s = _stream;
    if (s != null) {
      for (final t in s.getTracks()) {
        await pc.addTrack(t, s);
      }
    }
    pc.onIceCandidate = (c) {
      if (c.candidate == null || !identical(pc, _pc)) return;
      _send({'type': 'ice', 'c': c.toMap()});
    };
    pc.onTrack = (e) {
      if (e.streams.isEmpty || !identical(pc, _pc)) return;
      remote.srcObject = e.streams.first;
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
        // Connexion perdue : on recommence la mise en relation
        _peerSid = null;
        room.signal({'type': 'ready', 'sid': _sid});
      }
    };
  }

  void _send(Map<String, dynamic> m) =>
      room.signal({...m, 'from': _sid, 'to': _peerSid});

  Future<void> _queue = Future.value();

  /// Les messages sont traités un par un, dans l'ordre.
  void _onSignal(Map<String, dynamic> m) =>
      _queue = _queue.then((_) => _handle(m));

  Future<void> _handle(Map<String, dynamic> m) async {
    if (_closed) return;
    try {
      switch (m['type']) {
        case 'ready':
          final sid = '${m['sid']}';
          if (sid == _peerSid) return;
          _peerSid = sid;
          connected = false;
          await _newPeer();
          if (m['ack'] != _sid) {
            await room.signal({'type': 'ready', 'sid': _sid, 'ack': sid});
          }
          if (room.side == 'a') {
            final offer = await _pc!.createOffer(
                {'offerToReceiveAudio': true, 'offerToReceiveVideo': true});
            await _pc!.setLocalDescription(offer);
            _send({'type': 'offer', 'sdp': offer.sdp});
          }
          notifyListeners();
        case 'offer':
          if (m['to'] != _sid || m['from'] != _peerSid || _pc == null) return;
          await _pc!.setRemoteDescription(
              RTCSessionDescription('${m['sdp']}', 'offer'));
          await _drain();
          final answer = await _pc!.createAnswer();
          await _pc!.setLocalDescription(answer);
          _send({'type': 'answer', 'sdp': answer.sdp});
        case 'answer':
          if (m['to'] != _sid || m['from'] != _peerSid || _pc == null) return;
          await _pc!.setRemoteDescription(
              RTCSessionDescription('${m['sdp']}', 'answer'));
          await _drain();
        case 'ice':
          if (m['to'] != _sid || m['from'] != _peerSid || _pc == null) return;
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
      // Message d'une ancienne session ou arrivé trop tard : sans effet
    }
  }

  Future<void> _drain() async {
    _remoteSet = true;
    for (final c in _candidates) {
      await _pc?.addCandidate(c);
    }
    _candidates.clear();
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
    await _sub?.cancel();
    try {
      for (final t in _stream?.getTracks() ?? const <MediaStreamTrack>[]) {
        await t.stop();
      }
      await _stream?.dispose();
      await _pc?.close();
      local.srcObject = null;
      remote.srcObject = null;
      await local.dispose();
      await remote.dispose();
    } catch (_) {}
  }
}

/// Vignette vidéo de l'adversaire, à poser dans un Stack : on la déplace au
/// doigt, on la touche pour afficher les boutons (caméra, micro, selfie /
/// arrière, taille).
class VideoBubble extends StatefulWidget {
  final VideoCall call;
  final String peerName;
  const VideoBubble({super.key, required this.call, required this.peerName});

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

  @override
  Widget build(BuildContext context) {
    final call = widget.call;
    return LayoutBuilder(builder: (context, box) {
      final w = _big ? 248.0 : 140.0;
      final h = w * 3 / 4;
      final maxX = max(0.0, box.maxWidth - w);
      final maxY = max(0.0, box.maxHeight - h - (_tools ? 40 : 0));
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
                  children: [
                    Container(
                      width: w,
                      height: h,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: call.connected ? Tv.gold : Tv.line,
                            width: 2),
                        boxShadow: const [
                          BoxShadow(color: Colors.black54, blurRadius: 8)
                        ],
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (call.connected)
                            RTCVideoView(call.remote,
                                objectFit: RTCVideoViewObjectFit
                                    .RTCVideoViewObjectFitCover)
                          else
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text(
                                    call.error ??
                                        'Vidéo de ${widget.peerName}…',
                                    textAlign: TextAlign.center,
                                    style: Tv.label(11, color: Tv.text)),
                              ),
                            ),
                          // Mon image, en petit
                          if (call.ready && call.camOn)
                            Positioned(
                              right: 4,
                              bottom: 4,
                              width: w * 0.3,
                              height: h * 0.3,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(5),
                                child: RTCVideoView(call.local,
                                    mirror: call.front,
                                    objectFit: RTCVideoViewObjectFit
                                        .RTCVideoViewObjectFitCover),
                              ),
                            ),
                          if (!call.micOn)
                            const Positioned(
                                left: 4,
                                bottom: 4,
                                child: Icon(Icons.mic_off,
                                    size: 16, color: Tv.red)),
                        ],
                      ),
                    ),
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
