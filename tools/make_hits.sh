#!/bin/bash
# Vidéos des coups (T20, bull, double bull) : assets/hits/<style>_<slug>.mp4
# (1,5 s, 1280 × 720, texte incrusté, son du coup).
# usage : tools/make_hits.sh <dossier des fonds> <dossier des sons> <sortie> <style>...
#   fonds (fournis par foclabroc, Pixabay) : flamme.mp4, fire_burst.mp4,
#   circle_blue.mp4, blue_burst.mp4 ; sons : fire_<t20|bull|dbull>.m4a
#   (à extraire d'une vidéo actuelle : ffmpeg -i assets/hits/flame_t20.mp4 -vn -c:a copy fire_t20.m4a)
set -e
A=$1; SND=$2; OUT=$3; shift 3
FONT=$(dirname "$0")/../assets/fonts/BarlowCondensed-ExtraBold.ttf
# style : fichier, début, couleur du contour (hex)
declare -A SRC=([flame]="$A/flamme.mp4" [sparks]="$A/fire_burst.mp4" [ring]="$A/circle_blue.mp4" [nova]="$A/blue_burst.mp4")
declare -A START=([flame]=0.12 [sparks]=8.85 [ring]=1.3 [nova]=0.0)
declare -A COL=([flame]=E8431A [sparks]=E0182D [ring]=1E7BFF [nova]=1E7BFF)
declare -A TXT=([t20]="TRIPLE 20" [bull]="BULL" [dbull]="D-BULL")
make() { # style slug
  local st=$1 sl=$2 c=${COL[$1]}
  ffmpeg -nostdin -loglevel error -y -ss ${START[$st]} -t 1.5 -i ${SRC[$st]} -i $SND/fire_$sl.m4a \
   -filter_complex "
    [0:v]scale=1280:720:force_original_aspect_ratio=increase:flags=lanczos,crop=1280:720,fps=30,setsar=1,format=yuv420p,eq=brightness=-0.06,vignette=PI/4[bg];
    color=c=black@0:s=1280x720:d=1.5:r=30,format=rgba,drawtext=fontfile=$FONT:text='${TXT[$sl]}':fontsize=210:fontcolor=white:borderw=9:bordercolor=0x$c:x=(w-tw)/2:y=(h-th)/2,split=3[t][g][s];
    [s]colorchannelmixer=rr=0:gg=0:bb=0,gblur=sigma=26[sh];
    [g]gblur=sigma=14,colorchannelmixer=aa=0.9[gl];
    [bg][sh]overlay=format=auto[b1];[b1][gl]overlay=format=auto[b2];
    [t]fade=t=in:st=0:d=0.08:alpha=1[tt];
    [b2][tt]overlay=format=auto,fade=t=out:st=1.15:d=0.35,format=yuv420p[v]" \
   -map "[v]" -map 1:a -c:v libx264 -preset veryfast -crf 21 -maxrate 4500k -bufsize 9000k -profile:v main -level 3.1 -pix_fmt yuv420p -c:a copy -t 1.5 -movflags +faststart $OUT/${st}_$sl.mp4
}
for st in "$@"; do for sl in t20 bull dbull; do make $st $sl; done; done
