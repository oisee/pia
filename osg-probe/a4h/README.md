# PIA on A4H (real SAP 7.58)

Deploy single files with the vsp CLI (profile `a4h-vsp` from `vsp config mcp-to-vsp`, `.vsp.json` is gitignored):

    vsp -s a4h-vsp deploy src/00/zcl_pia_00_json_util.clas.abap '$TMP'

Classes with cyclic references (zif_pia_00_llm <-> zcl_pia_00_session <-> zcl_pia_00_llm_http) are created
inactive one by one and then activated together (vsp MCP: `edit` target `ACTIVATE_MULTI`).
Do not deploy `zcl_pia_20_b_osg_store` (OSG only); `zcl_pia_20_backend=>default( )` picks `zcl_pia_20_b_adt`.

Probe `ZPIA_PROBE_ADT` (report in $TMP, parameter P_CLS) runs write tests -> activate -> run_tests (RED)
-> fix -> activate -> run_tests (GREEN) through the SAP backend. Run it as a background job
(`SAP(action="rfc", target="ZPIA_PROBE_ADT", params={"op":"run","params":{"P_CLS":"..."}})`) and read
the result from INDX: `vsp -s a4h-vsp cluster read INDX --where "relid = 'ZP' AND srtfd = 'ZPIA_PROBE_ADT'"`.
(The list of a report that makes internal HTTP calls did not reach the spool.)

Findings while porting:
- `DATA x TYPE i VALUE <variable>` is a syntax error on SAP (OSG accepted it).
- `FIND ... REGEX` (POSIX) is deprecated on 7.58: use PCRE.
- strlen/to_upper on an xstring does not compile on SAP.
- cl_http_client=>create_internal runs ADT as the current user without a password (checked from a
  background job, user CLAUDE).
- the first POST after the CSRF fetch lost its query string with cl_http_utility=>set_request_uri;
  setting the `~request_uri` header directly works.
- writing a class include whose name exists but has no source (`...CCAU does not have any inactive
  version`, HTTP 500) needs POST /includes first, like a 404.
- aunit details: `<detail text="Expected [5] Actual [1-]"/>`; negative numbers print as `1-`.

## Front ends in $ZPIA (abapGit import)

`abapgit-front/` holds the SICF files in abapGit's naming (name padded to 15 + hash of the parent node):
`64ad2b3a5b1a9bfe420f1ef3e` = /sap/bc/, `c4b74e9e2a43316bca6442d43` = /sap/bc/apc/sap/. Classes, SAPC and SAMC
come from `src/`. Zip `.abapgit.xml` + `src/` and run `vsp -s a4h-vsp git import-zip <zip> --package '$ZPIA'`.

Lessons from the first install:
- A SAPC imported by abapGit does not generate its ICF node under /sap/bc/apc/sap/; import that SICF node
  explicitly (abapgit-front has it). Without it the WebSocket handshake fails and the TUI loops Connecting/Disconnected.
- `vsp deploy` checks syntax before writing. If the check fails (dependencies not there yet), a NEW object is left
  as an empty stub (`CREATE PRIVATE`, empty sections); activating it later activates the stub. Symptoms:
  "Method NEW is unknown", or APC "The constructor of the class ... is PRIVATE". Deploy in dependency order and
  compare line counts with the repo (`vsp -s a4h-vsp source CLAS <name> | wc -l`).
- Re-importing with --overwrite created nested SICF nodes (/sap/bc/zpia_tui/zpia_tui/); harmless, to be cleaned
  with SAP(action="system", params={"type":"git_delete_objects", ...}) which takes names with spaces.
- Source lines over 255 characters break on SAP ("Literals across more than one line").

## Turn modes (0.1: job; daemon is 0.1.+)

- `job` (default on SAP): the push channel writes the task beside the session file and schedules job
  `PIA_<sid>` (report ZPIA_TURN). ~10 s per simple turn, first tool event after 4.5-5.5 s. Works.
- `daemon` (0.1.+, not working yet): ZPIA_DAEMON starts daemon PIA_TURNS (from a job: a push channel may
  not touch CL_ABAP_DAEMON_CLIENT), the daemon subscribes to AMC ZPIA_AMC /turns, the terminal publishes
  the sid there. Observed: nothing happens, ICM closes the socket after 120 s. To check: does AMC reach the
  daemon at all (daemons get AMC only while waiting between callbacks), or does the turn die inside the
  daemon on the same forbidden statements (ABAP Unit sandbox, ADT loopback)? Next: log receive() into
  INDX, try a trivial turn without tools, and if ABAP Unit is forbidden in daemons, let the daemon keep the
  session and hand tool calls to jobs.
- `inline`: OSG only.
