# PIA Handover — 2026-10-06

> **PIA** (Pi-ABAP Agent) — ABAP-native headless coding agent runtime.
> ABAP agent, written in ABAP, developing ABAP, inside an ABAP-compatible environment.

## Быстрый старт

```bash
# 1. Поднять OSG с PIA (:8020)
cd ~/dev/osg-adt-abap
P=$(ss -tlnp | grep ':8020' | grep -oP 'pid=\K\d+' | head -1); [ -n "$P" ] && kill $P; sleep 3
rm -rf build  # при изменениях в local/tmp
setsid nohup env OSD_BIND=0.0.0.0 OSD_HEAVY_RANGE=20-29 OSD_HEAVY_SLOTS=1 \
  bash -c 'exec tools/osd-heavy.sh env STG_PORT=8020 OSD_BIND=0.0.0.0 npm start > /tmp/osd.log 2>&1' &
# Ждать ~3 мин (полный ребилд) или ~2 мин (инкрементальный)

# 2. Проверить
curl -s -u alice:alice -o /dev/null -w "%{http_code}" http://localhost:8020/sap/bc/adt/discovery
# 200 = сервер жив
```

## Интерфейсы

| Интерфейс | URL | Статус |
|---|---|---|
| HTML чат | `http://192.168.8.105:8020/sap/bc/zpia_chat/` | ✅ multi-turn, русский |
| TUI терминал | `http://192.168.8.105:8020/sap/bc/zpia_tui/` | ✅ xterm.js, terminal input |
| A2A сервер | `http://192.168.8.105:8020/sap/bc/zpia_a2a/` | ✅ agent card + send |
| MCP bridge | `node ~/dev/pia/mcp/pia-mcp-server.mjs` | ✅ Claude Code → PIA |

## Архитектура

```
Claude Code ──── MCP ────► pia-mcp-server.mjs ──── HTTP ───► PIA A2A
Browser    ──── HTML ────► /sap/bc/zpia_chat/  (ICF + forms)
Terminal   ──── WS ──────► /sap/bc/zpia_tui/   (APC WebSocket)
                                                                    │
                                                          ┌─────────▼─────────┐
                                                          │   PIA Agent Core   │
                                                          │  ($ZPIA_00)        │
                                                          │                    │
                                                          │  executor (loop)   │
                                                          │  session (+ckpt)   │
                                                          │  registry (tools)  │
                                                          │  amc_listener      │
                                                          └────────┬──────────┘
                                                                   │ tools
                                                    ┌──────────────▼──────────────┐
                                                    │  $ZPIA_10/15 (read/write)   │
                                                    └──────────────┬──────────────┘
                                                                   │ zif_pia_20_dev_backend
                                                    ┌──────────────▼──────────────┐
                                                    │  $ZPIA_20 (backends)        │
                                                    │  osg_store (in-process)     │
                                                    │  adt (HTTP, cross-system)   │
                                                    └──────────────┬──────────────┘
                                                                   │
                                                          ┌────────▼────────┐
                                                          │  OSG / SAP      │
                                                          └─────────────────┘
```

## Закрытые вехи

| Веха | Что | Отчёт |
|---|---|---|
| M0 | LLM из ABAP в OSG (TLS, z.ai) | `osg-probe/README.md` |
| M1 | Агентный цикл (read→write→activate→verify PASS) | `reports/2026-10-06-M1-live.md` |
| M2 | Checkpoint/resume (cross-restart, base64) | в git history |
| P2a | CREATE/DELETE через STORE | принято OSG |
| Chat | HTML multi-turn + русский + thinking | работает |
| TUI | WebSocket терминал + xterm.js | работает (post-fact) |
| A2A | PIA как сервер для внешних агентов | работает |
| MCP | Claude Code → PIA bridge | работает |
| Self-hosting | PIA модифицирует собственный код | `reports/2026-10-06-SELF-HOSTING.md` |

## Что дальше (приоритеты)

1. **AMC streaming** — архитектура готова, binding работает, но события не доставляются в реальном времени. Дебаг: проверить что `amc_listener` публикует и broker доставляет.
2. **P3a op_id** — код готов в backend v2, активируется когда коллега задеплоит EV_JSON на общий сервер.
3. **P3b RUN_TESTS** — коллега работает (W3).
4. **MCP расширение** — больше тулов (read/write/activate как отдельные MCP tools).
5. **Self-hosting v2** — PIA чинит реальный баг в себе (не добавление метода).

## Ключевые уроки (транспилятор/OSG)

1. `|...|` шаблоны с `{`/`"` — валят парсер непрозрачно → JSON только через `&&`
2. `'...'` литералы НЕ обрабатывают `\` → python-экранирование при генерации запрещено
3. `DATA ... VALUE` внутри LOOP — хойстится, не переинициализируется
4. `str+offset(len)` с выражением в len — запрещено → через переменные
5. `pkill -f` с паттерном из собственной команды = самоубийство → `[.]` экранирование
6. Warm-push (ADT activate) не всегда обновляет модуль → для надёжности cold restart
7. `set_header_field('Authorization')` съедает пробел после Bearer → template `|Bearer { key }|`
8. Двойное JSON-экранирование при checkpoint → base64 решает всё
9. APC `on_message` — весь вывод буферизуется до завершения → AMC для стриминга
10. `\.samc.xml`: `AUTHORITIES`/`PROGRAM_ID` (не `AUTH`/`PROGRAMNAME`), padding `padEnd(30,'=')+'CP'`

## Инфраструктура

- **PIA сервер**: `:8020` (диапазон 20-29, `tools/osd-heavy.sh`, БД `osd-8020.sqlite`)
- **OSG коллега**: `:8091` (диапазон 90-99, P3a/P3b разработка)
- **Метроном**: cron `*/9`, `~/dev/pia/osg-probe/heartbeat.sh`
- **Codex-approver**: `~/dev/pia/osg-probe/codex-approver.sh` (greenlist + уведомления)
- **MCP**: `~/dev/pia/mcp/pia-mcp-server.mjs`

## Репозиторий

- **GitHub**: `github.com/oisee/pia` (MIT, публичный)
- **Git identity**: `Alice V. <ooisee@gmail.com>` (настроен, hostname не утекает)
- **Pre-commit hook**: блокирует API-ключи в staged changes
- **API ключ**: `ZAI_API_KEY` env var, в source — плейсхолдер `PIA_ZAI_KEY`

## Коллаборация с OSG

- Коллега (codex) на `:8091`, w3:p1 в herdr
- Контракт активации §2.1 в `docs/abap-development-api.md`
- P2a принята, P3a готов к деплою, P3b (RUN_TESTS) в работе
- Связь: `herdr agent prompt w3:p1 "текст"`
