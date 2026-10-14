#!/bin/sh
# Render a FilmProject offline with Godot's Movie Maker (fixed frame rate, audio recorded in lockstep), then
# assemble an MP4 with ffmpeg. Silent on the speakers, nothing on the desktop (xvfb).
#   tools/film_render.sh res://films/demo/project.tres out_dir [540x960] [fps]
# Writes out_dir/frame########.png, out_dir/frame.wav and out_dir/film.mp4.
set -e
FILM=${1:?film project res:// path}
OUT=${2:?output dir}
SIZE=${3:-540x960}
FPS=${4:-30}
cd "$(dirname "$0")/.."
mkdir -p "$OUT"
rm -f "$OUT"/frame*.png "$OUT"/frame.wav "$OUT"/film.mp4
W=${SIZE%x*}; H=${SIZE#*x}
# FILM_GPU=1: render on the real GPU (a silent window on $DISPLAY, ~100x faster than the offscreen software path)
RUN="xvfb-run -a -s \"-screen 0 ${W}x${H}x24\" godot --path . --audio-driver Dummy --rendering-driver opengl3"
[ -n "$FILM_GPU" ] && RUN="godot --path . --audio-driver Dummy"
eval $RUN \
  --resolution "$SIZE" --fixed-fps "$FPS" --disable-vsync --write-movie "$OUT/frame.png" \
  res://filmmaker.tscn -- --film="$FILM" --render || true    # Godot may core-dump on quit ("double free"): harmless
[ -s "$OUT/frame.wav" ] && ls "$OUT"/frame00000001.png >/dev/null || { echo "render failed: no frames"; exit 1; }
ffmpeg -loglevel error -y -framerate "$FPS" -i "$OUT/frame%08d.png" -i "$OUT/frame.wav" \
  -c:v libx264 -pix_fmt yuv420p -crf 18 -c:a aac -b:a 160k -shortest "$OUT/film.mp4"
echo "rendered $(ls "$OUT"/frame*.png | wc -l) frames -> $OUT/film.mp4"
