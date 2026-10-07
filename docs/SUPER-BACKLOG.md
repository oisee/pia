# PIA super-backlog (brainstorm, 2026-10-06)

Ideas after 0.1, not yet ordered or promised. Grouped by theme; each line is a seed for a design note.

## 0.1.x — finish what 0.1 started

- **Daemon turns.** A pre-started ABAP daemon `PIA_TURNS` fed over AMC `/turns` instead of a job per turn:
  lower latency, the session kept in memory. Today the daemon does not pick up turns: find out whether AMC
  reaches it and whether ABAP Unit / ADT loopback are allowed inside a daemon; if not, the daemon keeps the
  session and hands tool calls to jobs.
- **Cancel a turn** with Ctrl+D (delete the job / tell the daemon).
- **Steering**: messages typed during a turn reach the agent between steps (today they queue for the next turn).
- **Create classes on SAP** (ADT create), and transportable packages with an explicit transport.
- open-steamgate from `main` once #626 is merged (0.1.1); P4 warm create for new objects.
- Clean up on A4H: nested SICF nodes left by early installs.
- **LLM record / replay** (`PIA_LLM=record:<file>` / `replay:<file>`, on top of zcl_pia_00_llm_mock): deterministic
  runs without a key, for the osg-demo book chapter and for CI; a recorded transcript in the release.
- abapGit import skipped ZCL_PIA_30_F_TUI_APC in the v0.1.0 zip (decision "add", no error): find out why.
- ~~A real JSON parser~~ done (2026-10-07): LLM answers, tool arguments and the session's tool calls are read with
  sXML (zcl_pia_00_json_util=>to_paths); the bracket-counting helpers remain only for JSON PIA writes itself.
- **End the turn on "publication pending"** in the executor instead of trusting the model (it retried run_tests until
  the step limit, three times in F1).
- ~~read_object for the testclasses include~~ done (2026-10-07), with outline / read_method / write_method on the
  system's own method ranges.
- **LLM call timeout**: a z.ai call once hung ~3 min after a tool result (OSG e8a3a643, en break); the turn then
  ended without an answer. Give the HTTP call a shorter timeout and one retry, and tell the user.
- **One zip for SAP and OSG** (2026-10-07): the STORE backend is in the zip now (dynamic host call). Waiting for
  open-steamgate feat/pia-zip-parity (import carries SICF/SAPC/SAMC, the daemon compiles, package $ZPIA from
  package.devc.xml, `osd up --layer <zip>`), then e2e on both from the same release zip.

## Tools like ZLLM

- A tool registry that is data, not code: tools described like ZLLM's formulas/patterns.
- Classes as tools, function modules as tools (RFC signature → JSON schema, as `vsp rfc describe` does).
- External tools over **MCP** (PIA as an MCP client) and other agents over **A2A**.
- Search / where-used / package listing (the agent cannot find classes by itself yet).

## Many agents

- **Swarm**: several PIA sessions working on one task (planner, coder, tester, critic), the pattern that worked
  here (pi drafts, a Fable critic reviews, RUN_TESTS decides).
- **Agent bus**: one shared channel where agents talk and the user sees everything — candidates: IRC,
  Telegram, Slack, or an AMC channel inside SAP bridged out.
- **herdr plugin**: PIA sessions as herdr panes/agents next to Claude, codex and pi.
- **Local chat client** for an agent working inside a system (OSG or A4H): a small terminal app that talks to
  the PIA terminal channel (the same WebSocket protocol as the browser TUI).

## Self-hosting (finish criterion F1)

- PIA fixes a real bug in its own code, red → green, without a human prompt per step.
- Its own tests as the safety net (30 tests for json_util today; more for the executor and the session store).
