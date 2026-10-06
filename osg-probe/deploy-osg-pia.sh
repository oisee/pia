#!/bin/bash
# Deploy PIA sources (~/dev/pia/src) into PIA's own OSG clone (~/dev/osg-pia).
# No secrets: the API key is read at runtime from pia.env (zcl_pia_00_config).
set -euo pipefail
SRC=~/dev/pia/src
OSG=${OSG:-~/dev/osg-pia}
DST=$OSG/local/tmp
mkdir -p "$DST"
cp ~/dev/osg-adt-abap/local/tmp/package.devc.xml "$DST/" 2>/dev/null || true
find "$SRC" -type f \( -name '*.abap' -o -name '*.xml' \) ! -name package.devc.xml ! -name 'zcl_pia_20_b_adt.*' ! -name 'zcl_pia_30_turn_daemon.*' -exec cp {} "$DST/" \;  # SAP-only backend stays out of OSG
# tadir.json: one entry per class/interface
python3 - "$DST" <<'PY'
import json, os, sys
d = sys.argv[1]; t = {}
for f in sorted(os.listdir(d)):
    p = f.split('.')
    if len(p) == 3 and p[1] in ('clas', 'intf') and p[2] == 'abap':
        t[f"{p[1].upper()} {p[0].upper()}"] = {"author": "PIA", "createdAt": "2026-10-06T00:00:00.000Z"}
json.dump(t, open(os.path.join(d, 'tadir.json'), 'w'), indent=0)
PY
if grep -rlE "[A-Za-z0-9]{24,}\.[A-Za-z0-9]{8,}" "$DST" >/dev/null; then echo "REFUSED: key-like string in $DST"; exit 1; fi
echo "deployed $(ls "$DST" | wc -l) files to $DST"
