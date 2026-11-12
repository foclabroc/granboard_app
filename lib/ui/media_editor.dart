import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../audio.dart';
import '../media.dart';
import '../players.dart';
import '../server.dart';
import 'theme.dart';

void _toast(BuildContext context, String text) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(text)));

String _error(Object e) => e is ApiError ? e.message : 'Erreur : $e';

/// Photo de profil : appareil photo, galerie ou retirer.
Future<void> showPhotoSheet(BuildContext context, PlayerProfile p) async {
  final hasPhoto = MediaStore.instance.imageOf(p.key) != null;
  final choice = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Tv.panel,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Row(
          children: [
            Expanded(
                child: _BigChoice(
                    icon: Icons.photo_camera,
                    label: 'PRENDRE UNE PHOTO',
                    onTap: () => Navigator.pop(context, 'camera'))),
            const SizedBox(width: 10),
            Expanded(
                child: _BigChoice(
                    icon: Icons.photo_library,
                    label: 'GALERIE',
                    onTap: () => Navigator.pop(context, 'gallery'))),
            if (hasPhoto) ...[
              const SizedBox(width: 10),
              Expanded(
                  child: _BigChoice(
                      icon: Icons.delete_outline,
                      label: 'RETIRER',
                      onTap: () => Navigator.pop(context, 'remove'))),
            ],
          ],
        ),
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  try {
    if (choice == 'remove') {
      await MediaStore.instance.setPhoto(p, null);
      if (context.mounted) _toast(context, 'Photo retirée');
      return;
    }
    final file = await ImagePicker().pickImage(
      source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
      preferredCameraDevice: CameraDevice.front,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 92,
    );
    if (file == null) return;
    final jpeg = await compute(MediaStore.squareJpeg, await file.readAsBytes());
    await MediaStore.instance.setPhoto(p, jpeg);
    if (context.mounted) _toast(context, 'Photo enregistrée');
  } catch (e) {
    if (context.mounted) _toast(context, _error(e));
  }
}

class _BigChoice extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _BigChoice(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 18)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34),
            const SizedBox(height: 6),
            Text(label, style: Tv.title(16)),
          ],
        ),
      );
}

/// Son joué quand c'est le tour du joueur : sons fournis ou sa voix.
Future<void> showTurnSoundSheet(BuildContext context, PlayerProfile p) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Tv.panel,
      builder: (context) => _TurnSoundSheet(p: p),
    );

class _TurnSoundSheet extends StatefulWidget {
  final PlayerProfile p;
  const _TurnSoundSheet({required this.p});

  @override
  State<_TurnSoundSheet> createState() => _TurnSoundSheetState();
}

class _TurnSoundSheetState extends State<_TurnSoundSheet> {
  final media = MediaStore.instance;
  bool _busy = false;

  Future<void> _choose(String sound, {Uint8List? voice}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await media.setSound(widget.p, sound, voice: voice);
    } catch (e) {
      if (mounted) _toast(context, _error(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _record() async {
    final voice = await showDialog<Uint8List>(
        context: context, builder: (_) => const _RecordDialog());
    if (voice == null) return;
    AudioService.instance.preview(kVoiceSound, voice: voice);
    await _choose(kVoiceSound, voice: voice);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: media,
      builder: (context, _) {
        final current = media.soundOf(widget.p.key);
        final voice = media.voiceOf(widget.p.key);
        Widget chip(String id, String label, {IconData? icon}) {
          final on = current == id;
          return ChoiceChip(
            selected: on,
            avatar: icon == null ? null : Icon(icon, size: 18),
            label: Text(label.toUpperCase(), style: Tv.title(16)),
            selectedColor: Tv.gold.withValues(alpha: 0.35),
            onSelected: _busy
                ? null
                : (_) {
                    if (id.isNotEmpty) {
                      AudioService.instance.preview(id, voice: voice);
                    }
                    _choose(id);
                  },
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TvSection('Son du tour de ${widget.p.name}',
                          padding: EdgeInsets.zero),
                    ),
                    if (_busy)
                      const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                    'Joué quand c\'est ton tour, puis l\'annonceur dit ton nom.',
                    style: Tv.label(13, color: Tv.muted)),
                const SizedBox(height: 10),
                Flexible(
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        chip('', 'Aucun'),
                        for (final e in kTurnSounds.entries)
                          chip(e.key, e.value),
                        if (voice != null)
                          chip(kVoiceSound, 'Ma voix',
                              icon: Icons.record_voice_over),
                        ActionChip(
                          avatar:
                              const Icon(Icons.mic, size: 18, color: Tv.red),
                          label: Text(
                              voice == null
                                  ? 'ENREGISTRER MA VOIX'
                                  : 'RÉENREGISTRER',
                              style: Tv.title(16)),
                          onPressed: _busy ? null : _record,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Enregistrement de 3 s max : appuyer pour commencer, s'arrête tout seul.
class _RecordDialog extends StatefulWidget {
  const _RecordDialog();

  @override
  State<_RecordDialog> createState() => _RecordDialogState();
}

class _RecordDialogState extends State<_RecordDialog>
    with SingleTickerProviderStateMixin {
  final _rec = AudioRecorder();
  late final _progress = AnimationController(vsync: this, duration: kVoiceMax)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) _stop();
    });
  bool _recording = false;
  Uint8List? _voice;
  String? _error;

  @override
  void dispose() {
    _progress.dispose();
    _rec.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      if (!await _rec.hasPermission()) {
        setState(() => _error = 'Micro refusé : autorise-le dans les réglages');
        return;
      }
      final dir = await getTemporaryDirectory();
      await _rec.start(
        const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 64000,
            sampleRate: 22050,
            numChannels: 1),
        path: '${dir.path}/voix_tour.m4a',
      );
      setState(() {
        _recording = true;
        _voice = null;
        _error = null;
      });
      _progress.forward(from: 0);
    } catch (e) {
      setState(() => _error = 'Enregistrement impossible : $e');
    }
  }

  Future<void> _stop() async {
    if (!_recording) return;
    _progress.stop();
    try {
      final path = await _rec.stop();
      final bytes = path == null ? null : await File(path).readAsBytes();
      setState(() {
        _recording = false;
        _voice = bytes;
      });
      if (bytes != null) {
        AudioService.instance.preview(kVoiceSound, voice: bytes);
      }
    } catch (e) {
      setState(() {
        _recording = false;
        _error = 'Enregistrement impossible : $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Tv.panel,
      title: Text('MA VOIX (3 S MAX)', style: Tv.title(22)),
      content: SizedBox(
        width: 360,
        child: Row(
          children: [
            GestureDetector(
              onTap: _recording ? _stop : _start,
              child: SizedBox(
                width: 96,
                height: 96,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _progress,
                      builder: (_, __) => SizedBox(
                        width: 96,
                        height: 96,
                        child: CircularProgressIndicator(
                            value: _recording ? _progress.value : 0,
                            strokeWidth: 5,
                            color: Tv.red,
                            backgroundColor: Tv.line),
                      ),
                    ),
                    CircleAvatar(
                      radius: 38,
                      backgroundColor: _recording ? Tv.red : Tv.panel2,
                      child: Icon(_recording ? Icons.stop : Icons.mic,
                          size: 40, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                _error ??
                    (_recording
                        ? 'Parle maintenant… (touche pour arrêter)'
                        : _voice == null
                            ? 'Touche le micro et dis ta phrase : « C\'est moi ! »'
                            : 'Enregistré. Écoute, recommence ou garde-le.'),
                style: Tv.title(17, color: _error == null ? Tv.text : Tv.red),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ANNULER')),
        if (_voice != null) ...[
          TextButton.icon(
            onPressed: () =>
                AudioService.instance.preview(kVoiceSound, voice: _voice),
            icon: const Icon(Icons.play_arrow),
            label: const Text('ÉCOUTER'),
          ),
          FilledButton(
              onPressed: () => Navigator.pop(context, _voice),
              child: const Text('GARDER')),
        ],
      ],
    );
  }
}
