#!/bin/bash
# usage: PORT=8022 classrun.sh <class>
BASE=http://localhost:${PORT:-8021}/sap/bc/adt
HS=$(curl -s -I -u alice:alice -H "x-csrf-token: fetch" "$BASE/core/discovery")
TOKEN=$(echo "$HS" | grep -i '^x-csrf-token:' | tr -d '\r' | awk '{print $2}')
COOKIE=$(echo "$HS" | grep -i '^set-cookie:' | grep -o 'sap-contextid=[^;]*' | head -1)
curl -s -u alice:alice -X POST "$BASE/oo/classrun/$1" -H "cookie: $COOKIE" -H "x-csrf-token: $TOKEN" -H "x-sap-adt-sessiontype: stateful" --max-time 300 -w "\n--- HTTP %{http_code}, %{time_total}s\n"
