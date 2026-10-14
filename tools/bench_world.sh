#!/bin/sh
# Repeat tools/bench_world.gd: each mode N times, each run its own process, results as JSON lines.
#   tools/bench_world.sh out.jsonl [runs=3] [modes="procedural cached"] [--gpu]
# Headless by default (build time, nodes, memory). --gpu opens a real window on $DISPLAY (silent) for frame times,
# draw calls and primitives. Run on an otherwise idle machine; report the spread, not the best run.
set -e
OUT=${1:?out.jsonl}; RUNS=${2:-3}; MODES=${3:-procedural cached}
FLAGS="--headless"
[ "$4" = "--gpu" ] && FLAGS="--disable-vsync --resolution 540x960"
cd "$(dirname "$0")/.."
: > "$OUT"
for m in $MODES; do
  for i in $(seq "$RUNS"); do
    BENCH_MODE=$m timeout 900 godot $FLAGS --audio-driver Dummy --path . --script tools/bench_world.gd 2>/dev/null \
      | sed -n 's/^BENCH //p' >> "$OUT"
    echo "$m run $i done"
  done
done
