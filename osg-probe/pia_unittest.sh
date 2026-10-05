#!/bin/bash
BASE=http://localhost:3030/sap/bc/adt
HS=$(curl -s -I -u alice:alice -H "x-csrf-token: fetch" "$BASE/core/discovery")
TOKEN=$(echo "$HS" | grep -i '^x-csrf-token:' | tr -d '\r' | awk '{print $2}')
COOKIE=$(echo "$HS" | grep -i '^set-cookie:' | grep -o 'sap-contextid=[^;]*' | head -1)
curl -s -u alice:alice -X POST "$BASE/abapunit/testruns" \
  -H "cookie: $COOKIE" -H "x-csrf-token: $TOKEN" -H "x-sap-adt-sessiontype: stateful" \
  -H "content-type: application/xml" \
  -H "accept: application/vnd.sap.adt.abapunit.testruns.result.v2+xml" \
  --max-time 180 \
  -d '<?xml version="1.0" encoding="UTF-8"?>
<aunit:runConfiguration xmlns:aunit="http://www.sap.com/adt/aunit" xmlns:adtcore="http://www.sap.com/adt/core">
  <external><coverage active="false"/></external>
  <adtcore:objectReferences>
    <adtcore:objectReference adtcore:uri="/sap/bc/adt/oo/classes/zcl_pia_probe"/>
  </adtcore:objectReferences>
</aunit:runConfiguration>' -w "\n---HTTP %{http_code}, %{time_total}s---\n"
