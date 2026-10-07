#!/bin/bash
# (Re)start PIA's open-steamgate server with durable jobs: STG_DB=file + the batch worker beside it.
#   osg-run.sh [tree] [log]     default: ~/dev/osg-pia, <tree>/.local/osg-pia.log
# Jobs run only on STG_DB=file, and only in a worker that sees the same database file and identity;
# the terminal's turns run there (job mode), so a turn ends its own dialog step and publishes.
set -euo pipefail
TREE=${1:-$HOME/dev/osg-pia}; LOG=${2:-$TREE/.local/osg-pia.log}
DB=${PIA_DB:-.local/db/pia-jobs.sqlite}
[ -n "${NODE_BIN:-}" ] && export PATH=$NODE_BIN:$PATH   # NODE_BIN: a node 22 bin directory, if the default node is older
[ "$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)" -ge 22 ] || { echo "node 22 or later needed (set NODE_BIN)"; exit 1; }
cd "$TREE"
for p in $(ps -eo pid,args | grep "[ ]$TREE/tools/osd-heavy.sh" | awk '{print $1}'); do kill -TERM -"$p" 2>/dev/null || true; done
for p in $(pgrep -f "[o]sd-batch-runs.mjs worker" || true); do [ "$(readlink /proc/$p/cwd)" = "$TREE" ] && kill "$p" || true; done
sleep 3
export STG_DB=file STG_DB_PATH="$DB" OSD_ADT_ONE_RUNTIME=1 OSD_WARM=1 \
  OSD_DATASET_READ="$HOME/.config/pia" OSD_DATASET_WRITE="$HOME/.config/pia" OSD_DATASET_HOME="$HOME/.config/pia"
setsid nohup env OSD_HEAVY_RANGE=20-29 OSD_HEAVY_SLOTS=3 \
  bash -c "exec tools/osd-heavy.sh env OSD_BIND=${OSD_BIND:-0.0.0.0} npm start > '$LOG' 2>&1" > /dev/null 2>&1 &
# the worker needs the built generation: start it once the server serves
( until grep -q "serving generation" "$LOG" 2>/dev/null; do sleep 3; done
  exec node tools/osd-batch-runs.mjs worker > "$LOG.worker" 2>&1 ) > /dev/null 2>&1 &
disown -a
echo "server log: $LOG   worker log: $LOG.worker   db: $TREE/$DB"
