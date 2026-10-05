#!/bin/bash
BASE=http://localhost:3030/sap/bc/adt
HS=$(curl -s -I -u alice:alice -H "x-csrf-token: fetch" "$BASE/core/discovery")
TOKEN=$(echo "$HS" | grep -i '^x-csrf-token:' | tr -d '\r' | awk '{print $2}')
COOKIE=$(echo "$HS" | grep -i '^set-cookie:' | grep -o 'sap-contextid=[^;]*' | head -1)
echo "token=${TOKEN:0:12}... cookie=${COOKIE:0:24}..."
curl -s -u alice:alice -X POST "$BASE/activation?method=activate&preauditRequested=true" \
  -H "cookie: $COOKIE" -H "x-csrf-token: $TOKEN" -H "x-sap-adt-sessiontype: stateful" \
  -H "content-type: application/xml" \
  --max-time 240 \
  -d '<?xml version="1.0" encoding="UTF-8"?>
<adtcore:objectReferences xmlns:adtcore="http://www.sap.com/adt/core">
  <adtcore:objectReference adtcore:uri="/sap/bc/adt/oo/classes/zcl_pia_probe" adtcore:name="ZCL_PIA_PROBE"/>
</adtcore:objectReferences>' -w "\nHTTP %{http_code}, %{time_total}s\n"
