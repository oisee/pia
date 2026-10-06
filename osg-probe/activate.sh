#!/bin/bash
# usage: PORT=8022 activate.sh CLAS:zcl_x INTF:zif_y ...
BASE=http://localhost:${PORT:-8021}/sap/bc/adt
HS=$(curl -s -I -u alice:alice -H "x-csrf-token: fetch" "$BASE/core/discovery")
TOKEN=$(echo "$HS" | grep -i '^x-csrf-token:' | tr -d '\r' | awk '{print $2}')
COOKIE=$(echo "$HS" | grep -i '^set-cookie:' | grep -o 'sap-contextid=[^;]*' | head -1)
REFS=""
for o in "$@"; do t=${o%%:*}; n=${o#*:}; case $t in CLAS) u=oo/classes;; INTF) u=oo/interfaces;; esac
  REFS="$REFS<adtcore:objectReference adtcore:uri=\"/sap/bc/adt/$u/$n\" adtcore:name=\"${n^^}\"/>"; done
curl -s -u alice:alice -X POST "$BASE/activation?method=activate&preauditRequested=true" -H "cookie: $COOKIE" -H "x-csrf-token: $TOKEN" -H "x-sap-adt-sessiontype: stateful" -H "content-type: application/xml" --max-time 600 \
  -d "<?xml version=\"1.0\" encoding=\"UTF-8\"?><adtcore:objectReferences xmlns:adtcore=\"http://www.sap.com/adt/core\">$REFS</adtcore:objectReferences>" -w "\nactivate HTTP %{http_code}, %{time_total}s\n" | grep -v "^<?xml" | grep -i "msg\|HTTP\|error" | head -10
