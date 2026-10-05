# PIA is headless by design: frontends, seam, multi-view

**Дата:** 2026-10-05
**Статус:** принятый архитектурный принцип (по итогам ревью от 2026-10-05)
**Связанные:** `2026-10-05-zllm-for-pia-assessment.md` (карта ZLLM→PIA), `2026-10-05-osg-wishlist-for-pia.md`

---

## Принцип

> **PIA is a headless ABAP-native agent runtime with pluggable development backends and pluggable user interfaces.**
>
> The agent runtime is independent of its user interface. The same PIA session can be exposed through a terminal CLI, interactive TUI, browser-based workbench, SAP GUI, or IDE integration.

Снизу у нас уже есть симметрия: один tool-контракт `zif_pia_20_dev_backend` поверх OSG store / ADT / SAP-native. Этот документ задаёт симметрию сверху: **один session/interaction API, поверх которого — сменные frontends**.

```
                 FRONTENDS
────────────────────────────────────
Terminal / TUI / HTML / SAP GUI / ADT / headless-run
                 │
                 │ commands + events   ← zif_pia_00_view / event log / AMC+APC
                 ▼
              PIA CORE
────────────────────────────────────
agent loop · sessions · context · tools · approvals · subagents
                 │
                 │ zif_pia_20_dev_backend
                 ▼
              BACKENDS
────────────────────────────────────
OSG Store | ADT | SAP Native
```

---

## 1. The seam в ABAP-терминах

Разделение — это три вещи: **snapshot** (рендерабельное состояние), **commands** (frontend → core), **events** (core → frontends). Всё это поверх уже существующего session-слоя ZLLM-V2.

### 1.1 Snapshot (что рендерит frontend)

Всё — части уже существующей модели сессии (`zif_llm_00_session` + добавляемые messages, см. assessment §4):

| Блок | Источник в ZLLM-V2 | Примечание |
|---|---|---|
| session header (id, task, status, verdict) | `ts_session` | есть |
| conversation (messages + content blocks) | `tt_messages` (E2) | рендерится всеми UI |
| plan / todo | `ts_plan_item` (pending/in_progress/completed/blocked) | есть |
| activity: tool calls (name, args, duration, ok, buffer_id) | `tt_tool_trace` | есть |
| **pending approvals** | НОВОЕ: `ts_approval` (tool, args, diff_ref, status) | см. §3 |
| artifacts: **diffs**, **test reports**, diagnostics | НОВОЕ (structured envelope, E7) | W7/W3 из wishlist |
| counters: iterations, tool_calls, токены | есть | |

### 1.2 Commands (frontend → core)

```abap
INTERFACE zif_pia_00_commands PUBLIC.
  METHODS submit_input IMPORTING iv_text TYPE string.          " user turn
  METHODS approve  IMPORTING iv_approval_id TYPE string
                             iv_note TYPE string OPTIONAL.
  METHODS reject  IMPORTING iv_approval_id TYPE string
                            iv_note TYPE string OPTIONAL.
  METHODS stop.                                               " interrupt
  METHODS list_sessions / load_session / get_snapshot.
ENDINTERFACE.
```

### 1.3 Events (core → frontends)

Монотонный **persisted event log** (sequence numbers, append к сессии в `zcl_llm_00_session_store`):

`session_started / message_appended / plan_updated / tool_started / tool_finished /
approval_requested / approval_resolved / artifact_created (diff, test_report, diagnostics) /
turn_completed / session_completed`

Три транспорта, один контракт:

| Транспорт | Где | Для кого |
|---|---|---|
| **in-process callback** `zif_pia_00_view` (sync render snapshot) | везде | Terminal/CLI, тесты, headless-run |
| **push**: AMC topic `/pia/session/<id>/events` → APC/WebSocket | SAP и OSG (обе имеют APC) | TUI (xterm.js), HTML workbench |
| **pull**: snapshot + event log по seq | везде | ADT-панель, поллинг, replay |

Persisted log — это заодно и **attach mid-session** («открыла ADT — увидела diff»), и resume после рестарта, и audit trail. Event sourcing получается не как мода, а как побочный эффект уже существующего session store.

---

## 2. Матрица frontends: механизм + переиспользуемые активы

| Frontend | Механизм | Берём из ZLLM-V2 | Статус |
|---|---|---|---|
| **Terminal** (MVP) | report / `if_oo_adt_classrun` + `zif_pia_00_view`; команды `/tools /status /diff /approve` | демо-программы `$ZLLM_00` как каркас | M1 |
| **TUI** (HTML terminal) | ICF-страница + APC push + xterm.js | **`$ZLLM_05` целиком** (http_handler + apc + trace_ws) | M2 |
| **HTML workbench** (chat + activity + diff + tests) | ICF static + APC + маленький REST для артефактов | рендер из `zcl_llm_00_markdown`; диффы — W7 | M3–M4 |
| **SAP GUI** | dynpro + `zcl_llm_spl` splitter + ALV (activity/objects) + CL_GUI_TEXTEDIT + Approve/Reject/Stop | `zllm_00_repl`, session browser (ALV), `zcl_llm_spl` | M4 |
| **ADT / VS Code** | PIA REST (commands) + event stream; или A2A JSON-RPC | `zcl_llm_00_a2a_*`; в OSG VSIX-расширение уже говорит ADT | потом |
| **Headless run** | `zcl_pia=>run( task )` → результат (print/JSON-режим как у pi) | executor как есть | M1 — нужен тестам и CI |

В OSG HTML-фронтенд особенно органичен: browser → OSG HTML UI → PIA ABAP session → OSG dev backend, **без Python/Node agent service между ними** (веб-контент и APC-события OSG уже раздаёт из ABAP — Fiori launchpad, SEGW-редактор, Zork это доказывают).

---

## 3. Следствие для agent loop: interruptibility

Approvals — первая фича, которая требует от executor **останавливаться и возобновляться**:

```
LLM → tool_call(WRITE_SOURCE) → permission gate → approval_requested
                                                            │
agent loop: persist state (session + messages) ────────────┤
agent loop: WAIT / roll-out / AMC-subscribe …              ▼
                                              approve (любой frontend)
                                                            │
agent loop: resume ← load state ◄──────────────────────────┘
       → invoke → tool_result → продолжить цикл
```

Это означает:
- состояние цикла **сериализуемо в любой точке** ( messages persistence E2 становится ещё жёстче требованием: не «для компакции», а «для приостановки»);
- место, где живёт loop, отвязано от места, где смотрят: dialog step / APC-сессия / фоновый job — событиям всё равно, кто подписчик;
- headless-режим без интерактива = auto-approve по policy (greenlist из tool-security design) — тот же код, другая policy.

## 4. Multi-view: одна session, много окон

Single writer (agent-задача владеет циклом) + много readers (каждый frontend — подписчик event log с собственного seq). Консистентность — snapshot + log; конфликтов нет, потому что write-команды идут только в единственную команду-очередь core.

```
              PIA session
              /     |     \
        terminal   HTML    ADT
```
Запущено из HTML → открыта ADT-панель (attach, replay по log) → raw trace в terminal. Для этого не нужен отдельный «мультиплексор»: сессия и так персистится, events и так пишутся.

---

## 5. Что меняется в прежних документах

- **Assessment §4 (executor delta)**: E2 (message persistence) и E3 (permission gate) повышаются из «важно» в «критично» — они теперь несут approvals/interrupt. Добавляется E8: **event emission** в цикле (tool_started/finished, turn lifecycle) — дёшево, если делать сразу.
- **Assessment §5 (пакеты)**: в `$ZPIA_40` добавляются фронтенды: `zif_pia_00_view / zif_pia_00_commands / event log / AMC-publisher` + frontends. Core не зависит от frontends (только наоборот).
- **Wishlist OSG**: пункты W3 (RUN_TESTS), W6 (publish-event), W7 (revision diff) теперь читаются и как «фронтендные» тоже — они кормят activity/diff-панели workbench'а.

## 6. Порядок (дельта к роадмапу)

1. **M1:** headless `run( )` + Terminal (`classrun`, in-process view) — доказать loop без UI.
2. **M2:** event log в session store + TUI из `$ZLLM_05` (push уже есть).
3. **M3–M4:** approvals → interrupt/resume; HTML workbench (diff/test-панели); SAP GUI.
4. Дальше: ADT/VS Code панель, multi-view demo как визитка PIA.
