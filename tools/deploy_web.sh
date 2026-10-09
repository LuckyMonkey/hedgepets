#!/usr/bin/env bash
# Build the web version and put it on fridge (go.fridge.run/hedgepets, its own container).
#   tools/deploy_web.sh            export + upload + (re)start the container
# Needs: Godot 4.7.2 export templates (~/.local/share/godot/export_templates/4.7.2.stable), ssh fridge@fridge.
set -euo pipefail
cd "$(dirname "$0")/.."
echo "== bake the startup cache (always before an export)"
godot --headless --path . --script tools/bake_cache.gd | grep -E "round trip|cache file"
echo "== export the Web preset"
rm -rf build/web && mkdir -p build/web
godot --headless --path . --export-release "Web" build/web/index.html 2>&1 | grep -E "ERROR|savepack|DONE" | tail -3
cp deploy/web/manifest.webmanifest deploy/web/icon-180.png deploy/web/icon-192.png deploy/web/icon-512.png build/web/   # the app bits (shell.html is the page)
ls -la build/web
echo "== upload to fridge:/srv/apps/hedgepets"
ssh fridge@fridge 'SUDO_ASKPASS=/home/fridge/.sudo-askpass sudo -A mkdir -p /srv/apps/hedgepets/web && SUDO_ASKPASS=/home/fridge/.sudo-askpass sudo -A chown -R fridge:fridge /srv/apps/hedgepets'
rsync -a --delete build/web/ fridge@fridge:/srv/apps/hedgepets/web/
rsync -a deploy/fridge/compose.yml deploy/fridge/nginx.conf fridge@fridge:/srv/apps/hedgepets/
echo "== (re)start the container"
ssh fridge@fridge 'cd /srv/apps/hedgepets && SUDO_ASKPASS=/home/fridge/.sudo-askpass sudo -A docker compose up -d && SUDO_ASKPASS=/home/fridge/.sudo-askpass sudo -A docker exec hedgepets nginx -s reload'
echo "== check from inside the web network"
ssh fridge@fridge 'SUDO_ASKPASS=/home/fridge/.sudo-askpass sudo -A docker exec fridge-caddy wget -qS -O /dev/null http://hedgepets:8080/hedgepets/index.html 2>&1 | head -3'
