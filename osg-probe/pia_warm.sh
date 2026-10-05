#!/bin/bash
BASE=http://localhost:3030/sap/bc/adt
HS=$(curl -s -I -u alice:alice -H "x-csrf-token: fetch" "$BASE/core/discovery")
TOKEN=$(echo "$HS" | grep -i '^x-csrf-token:' | tr -d '\r' | awk '{print $2}')
COOKIE=$(echo "$HS" | grep -i '^set-cookie:' | grep -o 'sap-contextid=[^;]*' | head -1)
H="cookie: $COOKIE"
T="x-csrf-token: $TOKEN"
# 1. lock
HANDLE=$(curl -s -u alice:alice -X POST "$BASE/oo/classes/zcl_pia_probe?_action=LOCK&accessMode=MODIFY" -H "$H" -H "$T" -H "x-sap-adt-sessiontype: stateful" | grep -o '<LOCK_HANDLE>[^<]*' | sed 's/<LOCK_HANDLE>//')
echo "lock handle: ${HANDLE:0:12}..."
# 2. read source, add a comment
curl -s -u alice:alice "$BASE/oo/classes/zcl_pia_probe/source/main" > /tmp/src.abap
echo "* warm touch $(date +%T)" >> /tmp/src.abap
# 3. PUT
T0=$(date +%s.%N)
curl -s -u alice:alice -X PUT "$BASE/oo/classes/zcl_pia_probe/source/main?lockHandle=$HANDLE" -H "$H" -H "$T" -H "x-sap-adt-sessiontype: stateful" --data-binary @/tmp/src.abap -o /dev/null -w "PUT: %{http_code} (%{time_total}s)\n"
# 4. unlock
curl -s -u alice:alice -X POST "$BASE/oo/classes/zcl_pia_probe?_action=UNLOCK&lockHandle=$HANDLE" -H "$H" -H "$T" -o /dev/null -w "unlock: %{http_code}\n"
# 5. activate
curl -s -u alice:alice -X POST "$BASE/activation?method=activate&preauditRequested=true" \
  -H "$H" -H "$T" -H "x-sap-adt-sessiontype: stateful" -H "content-type: application/xml" \
  -d '<?xml version="1.0" encoding="UTF-8"?>
<adtcore:objectReferences xmlns:adtcore="http://www.sap.com/adt/core">
  <adtcore:objectReference adtcore:uri="/sap/bc/adt/oo/classes/zcl_pia_probe" adtcore:name="ZCL_PIA_PROBE"/>
</adtcore:objectReferences>' -o /dev/null -w "activate: %{http_code} (%{time_total}s)\n"
