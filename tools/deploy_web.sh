#!/usr/bin/env bash
# Build the web version and put it on fridge (go.fridge.run/hedgepets, its own container).
#   tools/deploy_web.sh            export + upload + (re)start the container
# Needs: Godot 4.7.2 export templates (~/.local/share/godot/export_templates/4.7.2.stable), ssh fridge@fridge.
set -euo pipefail
cd "$(dirname "$0")/.."
# no xvfb on this laptop's system (and no sudo): a private copy unpacked in ~/work/xvfb-local (docs/OWNER_QUICKSTART.md)
if ! command -v xvfb-run >/dev/null && [ -x "$HOME/work/xvfb-local/root/usr/bin/xvfb-run" ]; then
  export PATH="$HOME/work/xvfb-local/root/usr/bin:$PATH" LD_LIBRARY_PATH="$HOME/work/xvfb-local/root/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi
if [ -f world/woods.compile ]; then                     # opt-in: ship the compiled woods (faster woods, ~16 MB more download)
  echo "== compile the woods"
  xvfb-run -a -s "-screen 0 320x240x24" godot --audio-driver Dummy --rendering-driver opengl3 --resolution 320x240 --path . \
    --script tools/compile_woods.gd 2>&1 | grep -E "compiled woods|built from it" || true
fi
echo "== bake the startup cache (always before an export)"
godot --headless --audio-driver Dummy --path . --script tools/bake_shadows.gd | grep -E "baked shadows|shadow"
godot --headless --path . --script tools/bake_cache.gd | grep -E "round trip|cache file"
echo "== export the Web preset"
rm -rf build/web && mkdir -p build/web
godot --headless --path . --export-release "Web" build/web/index.html 2>&1 | grep -E "ERROR|savepack|DONE" | tail -3
godot --headless --path . --export-pack "Woods Pack" build/web/woods.pck 2>&1 | grep -E "ERROR|savepack|DONE" | tail -3
cp deploy/web/manifest.webmanifest deploy/web/icon-180.png deploy/web/icon-192.png deploy/web/icon-512.png build/web/   # the app bits (shell.html is the page)
ls -la build/web
echo "== upload to fridge:/srv/apps/hedgepets"
ssh fridge@fridge 'SUDO_ASKPASS=/home/fridge/.sudo-askpass sudo -A mkdir -p /srv/apps/hedgepets/web && SUDO_ASKPASS=/home/fridge/.sudo-askpass sudo -A chown -R fridge:fridge /srv/apps/hedgepets'
rsync -a --delete build/web/ fridge@fridge:/srv/apps/hedgepets/web/
# --inplace: nginx.conf is a single-file bind mount; a replaced file (new inode) would never reach the container
rsync -a --inplace deploy/fridge/compose.yml deploy/fridge/nginx.conf fridge@fridge:/srv/apps/hedgepets/
echo "== (re)start the container"
ssh fridge@fridge 'cd /srv/apps/hedgepets && SUDO_ASKPASS=/home/fridge/.sudo-askpass sudo -A docker compose up -d && SUDO_ASKPASS=/home/fridge/.sudo-askpass sudo -A docker exec hedgepets nginx -s reload'
echo "== check from inside the web network"
ssh fridge@fridge 'SUDO_ASKPASS=/home/fridge/.sudo-askpass sudo -A docker exec fridge-caddy wget -qS -O /dev/null http://hedgepets:8080/hedgepets/index.html 2>&1 | head -3'
echo "== tell the owner's phone (ntfy, via go's notify-owner: only phones that opted in as owner)"
V=$(grep -o 'VERSION := "[^"]*"' scripts/telemetry.gd | cut -d'"' -f2)
WHAT=${DEPLOY_NOTE:-$(git log -1 --format=%s | cut -c1-180)}
ssh fridge@fridge "SUDO_ASKPASS=/home/fridge/.sudo-askpass sudo -A docker exec -u www-data fridge-php php /var/www/go/scripts/notify-owner.php info $(printf '%q' "HedgePets build $V is up") $(printf '%q' "$WHAT - tap to play") https://go.fridge.run/hedgepets/?v=$V" || echo "(phone notification failed; the build is up)"
