#!/bin/bash
# PIA metronome: каждые 11 мин будит pi безусловно — двигаться вперёд, не зависать
TS=$(date '+%F %T')
CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 4 http://localhost:8020/sap/bc/adt/discovery 2>/dev/null)
echo "$TS osg=$CODE" >> /home/alice/dev/pia/osg-probe/heartbeat.log
NEXT=$(head -2 /home/alice/dev/pia/NEXT.md | tail -1 | sed 's/^[0-9]*\. //')
if [ "$CODE" = "200" ]; then S="OSG ok"; else S="OSG DOWN($CODE) — сначала подними"; fi
~/.local/bin/herdr pane run w4:p1 "[метроном] $S. Дальше: $NEXT. Не зависай — действуй." 2>/dev/null
