#!/bin/bash
# Run the ABAP Unit tests of one class through ADT and print one line per test method.
#   PORT=8020 aunit.sh zcl_pia_00_json_util      (USER/PASS default alice/alice; BASE overrides the URL)
set -euo pipefail
CLS=${1:?class name}
BASE=${BASE:-http://localhost:${PORT:-8020}/sap/bc/adt}
AUTH=${USER_PASS:-alice:alice}
HS=$(curl -s -I -u "$AUTH" -H "x-csrf-token: fetch" "$BASE/core/discovery")
TOKEN=$(echo "$HS" | grep -i '^x-csrf-token:' | tr -d '\r' | awk '{print $2}')
COOKIE=$(echo "$HS" | grep -i '^set-cookie:' | grep -o 'sap-contextid=[^;]*' | head -1)
curl -s -u "$AUTH" -X POST "$BASE/abapunit/testruns" -H "cookie: $COOKIE" -H "x-csrf-token: $TOKEN" \
  -H "x-sap-adt-sessiontype: stateful" -H "content-type: application/xml" --max-time 300 \
  -d "<?xml version=\"1.0\" encoding=\"UTF-8\"?><aunit:runConfiguration xmlns:aunit=\"http://www.sap.com/adt/aunit\"><external><coverage active=\"false\"/></external><options><uriType value=\"semantic\"/><testDeterminationStrategy sameProgram=\"true\" assignedTests=\"false\"/><testRiskLevels harmless=\"true\" dangerous=\"true\" critical=\"true\"/><testDurations short=\"true\" medium=\"true\" long=\"true\"/></options><adtcore:objectSets xmlns:adtcore=\"http://www.sap.com/adt/core\"><objectSet kind=\"inclusive\"><adtcore:objectReferences><adtcore:objectReference adtcore:uri=\"/sap/bc/adt/oo/classes/${CLS,,}\"/></adtcore:objectReferences></objectSet></adtcore:objectSets></aunit:runConfiguration>" |
python3 -c '
import re, sys
x = sys.stdin.read()
ok = bad = 0
for m in re.finditer(r"<testMethod [^>]*?adtcore:name=\"([^\"]+)\"(.*?)(?:</testMethod>|/>)", x, re.S):
    name, body = m.group(1), m.group(2)
    a = re.search(r"<alert kind=\"(\w+)\".*?<title>([^<]*)</title>", body, re.S)
    if a and "severity=\"tolerable\"" not in body[:body.find("<title>")]:
        bad += 1; print("FAIL", name, "-", a.group(2))
    else:
        ok += 1; print("ok  ", name)
print(f"{ok} passed, {bad} failed")
if ok + bad == 0: print(x[:800])
'
