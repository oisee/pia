#!/bin/bash
# Set up an open-steamgate instance for PIA from scratch and start it.
#   osg-setup.sh [dir] [instance range]   default: ~/dev/osg-pia, 20-29 (the first free instance is taken)
#   OSG_REF=<tag|commit|main> picks open-steamgate (default: vscode-stable-v0.7.1696, where PIA 0.1.1 was accepted)
# Needs: node 22, git, ~/.config/pia/pia.env with ZAI_API_KEY=... (or PIA_LLM=replay:<file>, see README).
# Steps: clone, check out OSG_REF, npm ci, own copy of the pinned ABAP libraries, the pinned transpiler build
# (warm compile), packs, deploy PIA, start with ONE_RUNTIME + warm, PIA's files beside pia.env.
set -euo pipefail
DIR=${1:-$HOME/dev/osg-pia}
RANGE=${2:-20-29}
PIA=$(cd "$(dirname "$0")/.." && pwd)
[ -n "${NODE_BIN:-}" ] && export PATH=$NODE_BIN:$PATH   # NODE_BIN: a node 22 bin directory, if the default node is older
[ "$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)" -ge 22 ] || { echo "node 22 or later needed (set NODE_BIN)"; exit 1; }
mkdir -p "$HOME/.config/pia"
[ -f "$HOME/.config/pia/pia.env" ] || echo "note: $HOME/.config/pia/pia.env is missing (ZAI_API_KEY=... or PIA_LLM=replay:...)"
if [ ! -d "$DIR/.git" ]; then git clone https://github.com/oisee/open-steamgate.git "$DIR"; fi
cd "$DIR"
REF=${OSG_REF:-vscode-stable-v0.7.1696}
git fetch -q --tags origin
if [ "$REF" = main ]; then git checkout -q main && git pull -q --ff-only origin main; else git checkout -q "$REF"; fi
echo "open-steamgate $(git log -1 --format='%h %s')"
npm ci --no-audit --no-fund
[ -L .local/lars ] && rm .local/lars          # a long-running instance keeps its own copy, not a symlink
node tools/osd-libs.mjs --sync
npm run -s transpiler:pin                      # without it OSD_WARM=1 says "warm off"
npm run -s packs:fetch
OSG="$DIR" "$PIA/osg-probe/deploy-osg-pia.sh"
LOG=${LOG:-$DIR/.local/osg-pia.log}
setsid nohup env OSD_HEAVY_RANGE="$RANGE" OSD_HEAVY_SLOTS=3 OSD_ADT_ONE_RUNTIME=1 OSD_WARM=1 \
  OSD_DATASET_READ="$HOME/.config/pia" OSD_DATASET_WRITE="$HOME/.config/pia" OSD_DATASET_HOME="$HOME/.config/pia" \
  OSD_HEAVY_TIMEOUT=0 bash -c "exec tools/osd-heavy.sh env OSD_BIND=${OSD_BIND:-127.0.0.1} npm start > '$LOG' 2>&1" > /dev/null 2>&1 &
echo "starting; log: $LOG; the first build takes a few minutes"
# wait until the generation is served, then take the port from the heavy wrapper's line (STG_PORT=...)
for i in $(seq 1 300); do grep -q "serving generation" "$LOG" 2>/dev/null && break; sleep 2; done
grep -q "serving generation" "$LOG" || { echo "not up after 10 minutes, see $LOG"; exit 1; }
PORT=$(grep -o 'STG_PORT=[0-9]*' "$LOG" | head -1 | cut -d= -f2)
# activate the demo class once: RUN_TESTS needs an activated version on a fresh database
PORT=$PORT "$PIA/osg-probe/activate.sh" CLAS:zcl_pia_demo
echo "PIA terminal: http://127.0.0.1:$PORT/sap/bc/zpia_tui/ (user alice, password alice)"
