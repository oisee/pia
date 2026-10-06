#!/bin/bash
# L6 retest: N rounds of ADT lock -> PUT (marker vN) -> unlock -> activate -> classrun; expect vN.
PORT=${PORT:-8021}; ROUNDS=${ROUNDS:-5}; CLS=zcl_pia_probe_l6; UCLS=ZCL_PIA_PROBE_L6
BASE=http://localhost:$PORT/sap/bc/adt
HS=$(curl -s -I -u alice:alice -H "x-csrf-token: fetch" "$BASE/core/discovery")
TOKEN=$(echo "$HS" | grep -i '^x-csrf-token:' | tr -d '\r' | awk '{print $2}')
COOKIE=$(echo "$HS" | grep -i '^set-cookie:' | grep -o 'sap-contextid=[^;]*' | head -1)
H="cookie: $COOKIE"; T="x-csrf-token: $TOKEN"; S="x-sap-adt-sessiontype: stateful"
TMP=$(mktemp)
for i in $(seq 1 $ROUNDS); do
  HANDLE=$(curl -s -u alice:alice -X POST "$BASE/oo/classes/$CLS?_action=LOCK&accessMode=MODIFY" -H "$H" -H "$T" -H "$S" | grep -o '<LOCK_HANDLE>[^<]*' | sed 's/<LOCK_HANDLE>//')
  curl -s -u alice:alice "$BASE/oo/classes/$CLS/source/main" | sed -E "s/L6 marker: v[0-9]+/L6 marker: v$i/" > $TMP
  P=$(curl -s -u alice:alice -X PUT "$BASE/oo/classes/$CLS/source/main?lockHandle=$HANDLE" -H "$H" -H "$T" -H "$S" -H "content-type: text/plain" --data-binary @$TMP -o /dev/null -w "%{http_code}")
  curl -s -u alice:alice -X POST "$BASE/oo/classes/$CLS?_action=UNLOCK&lockHandle=$HANDLE" -H "$H" -H "$T" -H "$S" -o /dev/null
  T0=$(date +%s.%N)
  A=$(curl -s -u alice:alice -X POST "$BASE/activation?method=activate&preauditRequested=true" -H "$H" -H "$T" -H "$S" -H "content-type: application/xml" \
    -d "<?xml version=\"1.0\" encoding=\"UTF-8\"?><adtcore:objectReferences xmlns:adtcore=\"http://www.sap.com/adt/core\"><adtcore:objectReference adtcore:uri=\"/sap/bc/adt/oo/classes/$CLS\" adtcore:name=\"$UCLS\"/></adtcore:objectReferences>" -o /dev/null -w "%{http_code}")
  T1=$(date +%s.%N)
  OUT=$(curl -s -u alice:alice -X POST "$BASE/oo/classrun/$CLS" -H "$H" -H "$T" -H "$S" --max-time 120 | grep -o "L6 marker: v[0-9]*")
  OK=FAIL; [ "$OUT" = "L6 marker: v$i" ] && OK=OK
  printf "round %d %s: PUT %s activate %s (%.1fs) classrun '%s' at %s\n" $i $OK $P $A $(echo "$T1 - $T0" | bc) "$OUT" "$(date +%T)"
done
rm -f $TMP
