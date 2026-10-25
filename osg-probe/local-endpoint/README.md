# Local endpoint smoke test

The fake server uses only Python's standard library and binds to loopback. It checks
sampling settings, absent Authorization, valid tool argument strings and nested chat
function calls on subsequent requests. Restart it to reset its script.

```sh
python3 osg-probe/local-endpoint/fake-server.py --port 8089 --delay 150
```

In a separate shell, create a dedicated settings directory with this `pia-settings.env`:

```ini
PIA_BASE_URL=http://127.0.0.1:8089/v1/chat/completions
PIA_API_TYPE=chat
PIA_MODEL=local-test
PIA_API_KEY=
PIA_TEMPERATURE=0.2
PIA_MAX_TOKENS=512
PIA_TURN_MODE=inline
```

Run `PIA_DATA_DIR=<settings-directory> osg-probe/osg-setup.sh <new-runtime-directory> 80-89`.
Use the port printed by setup, then POST `{"text":"Exercise the demo class tools."}` to
`/sap/bc/zpia_a2a/` with the runtime's configured test credentials and an HTTP client
timeout of at least 600 seconds. The response includes `trace` with read, write,
activate and test events. The server delays the final answer by 150 seconds.
On this runtime, activation publishes at the end of the turn, so the same-turn
`run_tests` returns the expected "activation not published yet" guard. Run tests
in a subsequent turn to verify the published demo: stop the fake, restart it with
`--tests-only --delay 0`, and POST another task to A2A. The script rewrites unchanged
source; it does not claim to test newly published code within that turn.

Run ABAP Unit with `PORT=<port> osg-probe/aunit.sh zcl_pia_00_llm_http` and repeat
for `zcl_pia_00_config`. Stop both the fake server and the isolated runtime process
group after the run. No real model or remote inference endpoint is needed.
