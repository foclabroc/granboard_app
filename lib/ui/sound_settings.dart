import 'package:flutter/material.dart';

import '../audio.dart';
import '../tv_link.dart';
import 'theme.dart';
import 'tv_sheet.dart' show SoundTargetPicker;

/// Réglages des sons (feuille du bas).
Future<void> showSoundSettings(BuildContext context) {
  return showAppSheet(context, builder: (_) => const _SoundSheet());
}

class _SoundSheet extends StatelessWidget {
  const _SoundSheet();

  @override
  Widget build(BuildContext context) {
    final a = AudioService.instance;
    return ListenableBuilder(
      listenable: a,
      builder: (context, _) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (TvLink.instance.linked) ...[
                const TvSection('Le son sort sur (un ou plusieurs)',
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 8)),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SoundTargetPicker(),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              const TvSection('Sons',
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 8)),
              SwitchListTile(
                secondary: const Icon(Icons.record_voice_over),
                title: Text('Annonceur', style: Tv.title(18)),
                subtitle: const Text('Scores, bust, joueur suivant, victoire'),
                value: a.voice,
                onChanged: a.setVoice,
              ),
              SwitchListTile(
                key: const ValueKey('dart-calls'),
                secondary: const Icon(Icons.campaign_outlined),
                title: Text('Annoncer chaque fléchette', style: Tv.title(18)),
                subtitle: const Text('« Triple 20 », « double 16 », « raté »…'),
                value: a.dartCalls,
                onChanged: a.voice ? a.setDartCalls : null,
              ),
              SwitchListTile(
                key: const ValueKey('teasing'),
                secondary: const Icon(Icons.sentiment_very_satisfied),
                title: Text('Chambrage', style: Tv.title(18)),
                subtitle: const Text(
                    'Une petite phrase moqueuse sur un tour raté ou un bust'),
                value: a.teasing,
                onChanged: a.voice ? a.setTeasing : null,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.graphic_eq),
                title: Text('Effets sonores', style: Tv.title(18)),
                value: a.effects,
                onChanged: a.setEffects,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.music_note),
                title: Text('Musique des menus', style: Tv.title(18)),
                value: a.music,
                onChanged: a.setMusic,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.volume_down, color: Tv.muted),
                    Expanded(
                      child: Slider(
                        value: a.musicVolume,
                        onChanged: a.music ? a.setMusicVolume : null,
                      ),
                    ),
                    Icon(Icons.volume_up, color: Tv.muted),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: OutlinedButton.icon(
                  onPressed: () {
                    a.play(Sfx.crowd);
                    a.sayLater('Cent quatre-vingts !', 200);
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Tester'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
