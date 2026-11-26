#!/usr/bin/env python3
"""Son de l'intro des parties (assets/sounds/intro.ogg, 4 s) : souffle,
coup + accord à l'ouverture du bandeau, glissés des joueurs, reflet, puis
« GAME ON » (coup + accord). usage : python3 tools/motion_hits/intro_sound.py"""
import subprocess, sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import make as m  # noqa: E402

m.set_dur(4.0)
s = m.whoosh(0, .5, 1, 300, 5000, .45)
s += m.kick(.55, 120, 40, .45, 1.1) + m.stab(.58, [262, 330, 392], .8, .3, 2800)
for i in range(6):
    s += m.whoosh(1.05 + i * .12, 1.2 + i * .12, 10 + i, 1500, 6000, .1)
s += m.bell(1.65, [2637, 3520], .35, .08)
s += m.kick(2.7, 150, 45, .45, 1.2) + m.burst(2.7, 4, .12, 4000, .5)
s += m.stab(2.72, [392, 494, 587, 784], 1.0, .35, 3200)
s += m.whoosh(3.3, 3.55, 30, 5000, 400, .2)
x = m.finish(s)
out = Path(__file__).resolve().parent.parent.parent / 'assets/sounds/intro.ogg'
wav = Path('/tmp/intro.wav')
m.write_wav(wav, x)
subprocess.run(['ffmpeg', '-nostdin', '-loglevel', 'error', '-y', '-i', str(wav), '-ac', '1', '-af', 'loudnorm=I=-14',
                '-ar', '44100', '-c:a', 'libvorbis', '-q:a', '4', str(out)], check=True)
print(out)
