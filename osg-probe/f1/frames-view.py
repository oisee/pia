"""Readable view of an F1 frames.jsonl: what was sent, tool calls/results, turn ends (stdin -> stdout)."""
import json, re, sys
for l in sys.stdin:
    try:
        j = json.loads(l)
    except ValueError:
        continue
    t = "%5ds" % (j["ms"] // 1000)
    d = re.sub(r"\x1b\[[0-9;]*m|\x1b\]777;pia-done\x07", "", j["data"])
    if j["dir"] == "sent" and d != "/hb":
        print(t, "SENT", d[:100], flush=True)
    elif j["dir"] == "close":
        print(t, "WS CLOSED", flush=True)
    elif j["dir"] == "recv":
        for line in d.splitlines():
            s = line.strip()
            if s.startswith(("> ", "< ")) or "PIA-DONE" in s or "ERROR" in s or s.startswith("iters="):
                print(t, s[:120], flush=True)
