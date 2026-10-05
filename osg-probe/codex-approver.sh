#!/bin/bash
# CODEX NEEDS ATTENTION: auto-approve read-only, notify otherwise
STATE=/tmp/codex-approver.state
LOG=/home/alice/dev/pia/osg-probe/codex-approver.log
while true; do
  STATUS=$(~/.local/bin/herdr agent list 2>/dev/null | python3 -c "import json,sys
try:
    d=json.load(sys.stdin)
    print(next((a['agent_status'] for a in d['result']['agents'] if a.get('agent')=='codex'),'?'))
except: print('?')" 2>/dev/null)
  if [ "$STATUS" = "blocked" ]; then
    CMD=$(~/.local/bin/herdr pane read w3:p1 2>/dev/null | grep -E '^\s*\$ ' | tail -1 | sed 's/^\s*\$ //')
    H=$(echo "$CMD" | md5sum | cut -c1-8)
    LAST=$(grep "$H ok" $STATE 2>/dev/null | tail -1)
    if [ -z "$LAST" ]; then
      if echo "$CMD" | grep -qE '^(gh (api|run|pr|issue) |git (status|log|diff|show|branch|tag --list|rev-parse) |cat |head |tail |grep |ls |find |sed -n |wc |python3 - <<|PATH=[^ ]* OSD_HEAVY_RANGE=; then
        ~/.local/bin/herdr pane send-keys w3:p1 Enter >/dev/null 2>&1
        echo "$(date '+%T') AUTO-OK [$H] $CMD" >> $LOG; echo "$H ok" >> $STATE
      else
        ~/.local/bin/herdr pane run w4:p1 "[codex-approver] НУЖНО ВНИМАНИЕ: $CMD — одобрить вручную (Enter в w3:p1) или скажи мне" >/dev/null 2>&1
        echo "$(date '+%T') NOTIFY [$H] $CMD" >> $LOG; echo "$H notify" >> $STATE
      fi
    fi
  fi
  sleep 25
done
