#!/bin/bash
BASE=http://localhost:3030/sap/bc/adt
HS=$(curl -s -I -u alice:alice -H "x-csrf-token: fetch" "$BASE/core/discovery")
TOKEN=$(echo "$HS" | grep -i '^x-csrf-token:' | tr -d '\r' | awk '{print $2}')
COOKIE=$(echo "$HS" | grep -i '^set-cookie:' | grep -o 'sap-contextid=[^;]*' | head -1)
curl -s -u alice:alice -X POST "$BASE/oo/classrun/zcl_pia_probe" \
  -H "cookie: $COOKIE" -H "x-csrf-token: $TOKEN" -H "x-sap-adt-sessiontype: stateful" \
  --max-time 120 -w "\n---HTTP %{http_code}, %{time_total}s---\n"
