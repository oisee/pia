# Что из ZLLM / ZLLM-V2 переиспользовать для PIA

**Дата:** 2026-10-05
 **Входные репозитории:** `~/dev/pia/zllm` (v1, 313 файлов), `~/dev/pia/zllm-v2` (v2, 666 файлов, ядро `$ZLLM_00` — 431 файл), `~/dev/pia/pi` (reference architecture, MIT), `~/dev/osg-adt-abap` (= open-steamgate / vsp)
 **Связанные документы:** `zllm-v2/reports/2026-04-05-gap-matrix.md`, `zllm-v2/reports/2026-04-05-implementation-roadmap.md`, `zllm-v2/contexts/2026-04-05-agent-runtime-upgrade.md`

---

## 0. TL;DR

1. **ZLLM-V2 — это уже ~60% агентского ядра PIA.** LLM-слой, tool registry, executor-loop, buffer, sessions, web-терминал — всё существует и работает. PIA не начинается с нуля.
2. **Но ZLLM-V2 — это research agent: read-only, one-shot investigation.** PIA — coding agent: write-loop, верификация, workspace. Разница не в количестве кода, а в **контракте инструментов**: половина PIA-инструментов (write / activate / test / diff) не существует ни в одной из версий ZLLM — и именно эта половина является PIA-спецификой.
3. **Главная новая абстракция PIA — `dev backend`**: один tool contract, две имплементации (SAP и OSG). Ни один существующий инструмент ZLLM-V2 под этот контракт не подписан — все завязаны на SAP-native API (`READ REPORT`, `cl_oo_classname_service`, DDIC, SE91…). Это рефакторинг-перепривязка, а не переписывание.
4. **Executor нужно рефакторить в любом случае** — и это уже спланировано апрельским gap-matrix (messages persistence — blocker #1). PIA добавляет к этому плану три требования: настоящий system message (сейчас системный промпт склеен в user-prompt), permission-gate перед `invoke_call`, и обработка асинхронной активации OSG.
5. **OSG готов к приёму PIA лучше, чем ожидалось:** исходящий `cl_http_client=>create_by_url` в рантайме есть (его использует `zcl_osd_git`), APC/WebSocket есть, ABAP Unit есть, ADT-фасад есть, спроектирован `ZCL_OSD_DEVELOPMENT` — готовый бэкенд для write-инструментов. Docker — одна команда.
6. **v1 не нужен как база** — она почти целиком поглощена v2. v1 остаётся источником отдельных утилит и исторических идей.

---

## 1. Карта переиспользования по слоям PIA

Вердикты: **KEEP** — брать как есть; **ADAPT** — брать с рефакторингом; **NEW** — в ZLLM нет, делать в PIA; **SKIP** — не тащить.

### 1.1 LLM-слой (ZLLM как «LLM runtime» из концепции)

| Актив (v2, `$ZLLM_00`) | Вердикт | Комментарий |
|---|---|---|
| `zcl_llm_00_llm_lazy` + `zif_llm_00_llm_lazy` | **KEEP** | Ядро: кэш, throttle, q/a-протокол, dotenv-конфиг. Использует ровно тот subset `cl_http_client`, который есть в OSG (см. §3.1) |
| `zcl_llm_00_payload_adapter*` (`_cl`, `_4o`, `_o3`, factory) | **KEEP** | Provider-специфичные payload'ы. Фабрика уже маршрутизирует по типу модели |
| `zcl_llm_00_capabilities` + intf | **KEEP** | Автодетект model family + context/output лимиты. Обновить таблицу моделей (сейчас актуальна на начало 2026) |
| `zcl_llm_00_predictoken` + семейство (`_claude`, `_gpt4`, `_mistral`, `_qwen`, factory) | **KEEP** | Триггер компакции (в executor ещё не подключён — см. §4) |
| `zcl_llm_00_cache` / `cache_never` + intf | **KEEP** | Кэш ответов; для PIA важно: кэш не должен ловить write-циклы (дифференцировать по наличию tool-результатов — проверить ключ `q( io_, iv_k )`) |
| `zcl_llm_00_json` / `json_raw` / `zif_llm_00_json` | **KEEP** | Критическая зависимость всего. Свой парсер —must stay |
| `zcl_llm_00_dotenv` + env/bin storage (`zllm_00_bin` и т.д.) | **KEEP** | Конфиг провайдеров. В OSG SMW0-вариант `zcl_llm_00_file_smw0` проверит совместимость |
| `zcl_llm_00_codec` (шифрование) + `codec_mock` | **KEEP** | API keys не в открытом виде |
| `zcl_llm_00_llm_lazy_wrap` / `_composite` / `_balancer` / `_mock` | **KEEP** | Balancer (роутинг по сложности) и mock (тесты executor без API) переедут в PIA-тесты как есть |
| `zcl_llm_00_embedding` / `embed_in` / `embed_out` | **SKIP (пока)** | Semantic search — не MVP. Вернуться, когда появится repo-index |
| `zcl_llm_00_step_lazy` / `flow_lazy` (+parallel) / `pat*` / `formula*` | **SKIP (для PIA MVP)** | Это chain-слой LangChain-стиля. Для coding agent цикл управляется tool-calling'ом, не флоу. Оставить в ZLLM как библиотеку |
| `zcl_llm_00_trace` + `qa_store` | **KEEP** | Полный аудит-лог conversations — база для отладки self-hosting-циклов |

### 1.2 Agent runtime (собственно PIA)

| Актив (v2) | Вердикт | Комментарий |
|---|---|---|
| `zcl_llm_00_executor` | **ADAPT (серьёзно)** | Единственный настоящий agent loop. Что менять — §4. Скелет (while-цикл, parse tool_calls, invoke, append results) — правильный |
| `zif_llm_00_tool` / `zcl_llm_00_tool_custom` / `zcl_llm_00_tool_registry` | **KEEP + расширить** | Контракт инструмента хороший. Добавить: `get_required_permission()` (READONLY/WRITE/EXECUTE — уже в апрельском плане), `filter()` у registry |
| `zcl_llm_00_tool_fm` / `tool_method` | **KEEP** | Reflection-обёртки; в OSG проверить поддержку RTTS на FM — вторично |
| `zcl_llm_00_agent_buffer` | **KEEP** | Production-ready: 8KB чанки, 12KB порог, `read_buffer`/`search_buffer`. Прямо переезжает в PIA как context-менеджмент больших исходников |
| `zif_llm_00_session` / `zcl_llm_00_session` / `session_store(_v2)` | **ADAPT** | Модель богатая (hyper_runs, plan, findings, conclusions, key_facts). Главный пробел — **сообщения не персистятся** (blocker #1 по апрельскому анализу; roadmap §1.1 уже готов: `ts_content_block`, `push_message`…) |
| `zcl_llm_00_agent_ctx` + intf | **KEEP** | Findings/artifacts/sources/observations + scope-check `is_in_scope` по пакетам. Для PIA «пакеты» → «workspace/repo» |
| `zcl_llm_00_research_agent` | **ADAPT → шаблон `zcl_pia_agent`** | Орkeстратор: registry-сборка, system prompt, session-wiring, continue(). Структура переносится, содержимое промпта меняется с research на coding |
| hypervisor (design: `docs/2026-01-04-agent-architecture-v2.md`, типы `ts_hyper_run`/`ts_appeal` есть) | **ADAPT, но иначе** | Для PIA верификатор — **не второй LLM-судья, а компилятор с тестами**: syntax check → activate → ABAP Unit — это объективный verdict-цикл. LLM-hypervisor остаётся для «мягких» задач. Это упрощение по сравнению с планом v2 |
| `zcl_llm_00_tool_counter` / `tool_notepad` | **KEEP** | Мелочь, пригодится |

### 1.3 Инструменты (существующие, read-половина)

Все 29 `zcl_llm_00_agent_t_*` переезжают **по логике, но не по имплементации**: каждый сейчас ходит напрямую в SAP API. Перепривязка на `zif_pia_20_dev_backend` — см. §2.

| Инструмент | PIA-вардики | Комментарий |
|---|---|---|
| `search` (search_object) | **KEEP** | За бэкенд-интерфейсом. OSG: поиск по файловому дереву |
| `source` (get_source) | **KEEP** | SAP: `READ REPORT` + `cl_oo_classname_service`; OSG: чтение abapGit-файла/ADT. Разносится по имплементациям |
| `callers` / `callees` (where-used) | **KEEP (SAP)**, **NEW (OSG)** | В OSG нет SAP where-used. Варианты: YAAC-граф из src/02 (§1.5) или grep-по-дереву как fallback |
| `grep` (grep_source) | **KEEP** | SAP: пакетный скан REPO; OSG: grep по файлам. За бэкендом |
| `table` / `query` / `cds` / `messages` / `domain` / `badi` / `pricing` | **KEEP, SAP-only** | DDIC/SE91/BAdI — только настоящий SAP. В OSG — просто отсутствуют (registry собирается per-backend) |
| `report` (run_report, ALV capture) | **KEEP, SAP-only** | OSG-эквивалент появится сам, когда PIA сможет SUBMIT (OSG jobs уже есть) |
| `read` / `search_buf` (buffer) | **KEEP** | Привязаны к `agent_buffer`, бэкенда не требуют вообще |
| `plan` (write_plan) | **KEEP** | Todo-лист агента — уже session-aware. Прямо в PIA |
| `finding` / `cite` | **KEEP** | Контекст-инструменты, бэкенда не требуют |
| `doc` / `save_doc` / `read_doc` / `list_docs` / `elevate_doc` / `srch_docs` | **KEEP** | Doc store (SESSION/USER/GLOBAL) — готовая основа **project memory** (аналог AGENTS.md/skills у pi): для PIA добавить scope REPO |
| `list_sess` / `srch_sess` / `sess_info` | **KEEP** | |

### 1.4 Write-половина — её нет нигде (NEW)

| PIA-инструмент | SAP-имплементация | OSG-имплементация |
|---|---|---|
| `create_object` | ADT REST / `RS_API`-семейство | store `WRITE`/создание через дерево; `ZCL_OSD_DEVELOPMENT=>create(…)` когда смержится P2 |
| `write_source` | ADT source write + lock | `zcl_osd_adt_host=>store( command='WRITE' type=… name=… source=… )` — **напрямую из ABAP, без HTTP** |
| `delete_object` | ADT | пока нет в store-командах → через ADT-фасад HTTP |
| `syntax_check` | ADT checkruns | store `CHECK` (parse) / `CHECKRUN` |
| `activate` | ADT activation | store `ACTIVATE` — уже ждёт `publish()` внутри шага |
| `get_diagnostics` | ADT problems / ATC | `CHECKRUN`/активационные сообщения (объект/include/line/col/severity/text) |
| `run_tests` | ABAP Unit (a2x/SAUNIT; MCP-доступ к a4h уже проверен) | ABAP Unit: маршруты `/abapunit/*` ADT-фасада + Test Explorer это уже использует |
| `run_program` | `SUBMIT`/`run_report` | `classrun` маршрут (F8) есть; jobs есть |
| `where_used` | where-used SAP | ADT-фасад уже несёт `xref/closure`, `xref/readers` |
| `search_objects` | ADT RIS search / `zcl_osd…`-аналог | store `SEARCH`, `PACKAGES`; маршруты `informationsystem/search`, VFS |
| `git_status` / `git_diff` | **abapGit** (`zcl_abapgit_file_status`, `zcl_abapgit_diff`, сериализаторы) | store `HISTORY`/`REVISION` + host-git (дерево = рабочий каталог git); `zcl_osd_git` — только fetch/clone |

Плюс чисто PIA-ские runtime-части, которых нет: **permissions** (write/delete/activate/run — с подтверждением; greenlist-дизайн уже есть в `docs/2026-01-05-tool-security-design.md`), **system prompt coding-агента** (у research-агента — однострочный монолит, у pi — секционный builder с бюджетами; roadmap §2.4), **sub-agents** (registry `filter()` — почти одна строка, роли EXPLORER/VERIFIER), **compaction** (roadmap Phase 1 — спека полная).

### 1.5 Стратегические активы за пределами ядра

| Актив | Где | Вердикт |
|---|---|---|
| **YAAC / code_unit / src / graph / xray / git_source** (свой ABAP-парсер: token/statement/syntax-tree, координаты, call-graph) | v2, `src/02` | **KEEP, не блокер**. Это единственный собственный where-used/semantic-index для OSG, где нет SAP-индексов. Для MVP — grep; для v2 PIA — граф |
| **Web terminal** (`zcl_llm_05_http_handler` + `zcl_llm_05_apc` + `zllm_05_trace_ws`, xterm.js) | v2, `src/05` | **KEEP — это и есть HTML-UI PIA.** APC в OSG работает (демо Zork/WebGL это доказывают). Дописать: показ плана/диффов/подтверждение write-инструментов |
| **A2A** (`a2a_client/handler/agent_card/task_mgr`) | v2, `src/00` | **KEEP, потом**. PIA как A2A-сервер = доступ внешних агентов к ABAP-среде. Не MVP |
| REPL (dynpro, `zllm_00_repl`) + session browser/doc browser (ALV) | v2 | **KEEP** — основа GUI-варианта интерфейса |
| `zcl_llm_spl` (GUI splitter) и прочее из `src/03/04` | v2 | SKIP для ядра; утилиты |
| `zcl_llm_00_markdown` | v2 | KEEP — рендер отчётов/документов |
| `zcl_llm_00_kanban_mgr` | v2 | потом: визуализация плана в UI |
| v1: `train_models.py`, `_predictoken/` | v1 | SKIP |
| v1: steps/flows/patterns/balancer | v1 | SKIP (есть в v2; для PIA не нужны) |

**Итог по v1:** базироваться только на v2. v1 держать как архив.

---

## 2. Главный архитектурный сдвиг: read-only research → write coding loop

ZLLM-V2 executor сегодня:

```
user prompt (system склеен внутрь)
  → LLM → tool_calls → invoke → tool_result → …
  → финальный текст
```

PIA-цикл (по концепции):

```
task → inspect → read → modify/create → syntax check → activate → run tests
     → errors? → iterate → done
```

Разница реализуется тремя вещами:

1. **`zif_pia_20_dev_backend`** — единый контракт:
   ```abap
   METHODS read_object / search_objects / create_object / write_source / delete_object
           syntax_check / activate / get_diagnostics / run_tests / where_used
           git_status / git_diff   " SAP: abapGit; OSG: HISTORY/REVISION + host-git
   ```
   Адаптеры — см. матрицу в §3.2 (`zcl_pia_20_b_osg_store` — in-process OSG; `zcl_pia_20_b_adt` — HTTP, работает в обе среды; `zcl_pia_20_b_sap_native` — READ REPORT/SEO/DDIC + abapGit). Инструменты PIA — тонкие обёртки над интерфейсом; registry собирается per-backend (SAP-набор шире на DDIC/SE91-инструменты).

2. **Verification loop как first-class часть промпта и контракта.** Результат `activate`/`run_tests` возвращается агенту в структурированном виде (список issues с line/col — формат уже определён в OSG `ZCX_OSD_DEVELOPMENT`). Agent loop должен позволять модели «крутиться» на ошибках компиляции/тестов — это обычный tool-цикл, executor его уже поддерживает.

3. **Permissions.** Все write-инструменты помечаются `WRITE`/`EXECUTE`; в UI (web terminal) — подтверждение человеком; headless — policy из greenlist-конфига. Дизайн в `docs/2026-01-05-tool-security-design.md` переносится почти дословно.

**Само-hosting** из этой схемы вытекает бесплатно: PIA в том же git-дереве, что и разрабатываемый код → `read_object( zcl_pia_* )`, `write_source`, `activate`, `run_tests` — обычные операции над самим собой. Поколение N пишет N+1, перезапуск — обычный bootstrap (как в концепции).

---

## 3. OSG: что уже проверено по репозиторию

### 3.1 LLM-слой сможет жить внутри OSG

`cl_http_client=>create_by_url` используется рантаймом OSG в ABAP (`src/osd/git/zcl_osd_git.clas.abap`, строки 515/539 — git over HTTP), и есть тестовый прогон полного цикла request→send→receive в `tools/gogen/testdata-httpc/`. ZLLM-шный `api_send` использует ровно этот subset (create_by_url, set_method, set_header_field, set_cdata, send, receive, get_cdata).

**Проба M0 — ✅ пройдена 2026-10-05** (живой инстанс, `~/dev/pia/osg-probe/`): `cl_http_client` из ABAP внутри OSG → `POST https://api.anthropic.com/v1/messages` → **401 `invalid x-api-key`** — TLS, заголовки, тело, чтение ответа работают. Единственный был-риск (TLS) снят; остаются таймауты/429-семантика при реальной нагрузке. Заодно вживую проверен весь ADT-цикл: файлы в `local/tmp` видны серверу без рестарта; lock→PUT→activate (29 s); ABAP Unit через `/abapunit/testruns` — структурированный XML (expected/actual, stack, navigationUri) за 2.3 s.

### 3.2 Tool-бэкенд: три пути, все говорят на одном языке

В OSG для dev-операций фактически есть **три уровня доступа**, и это меняет план M2 к лучшему:

1. **Store-seam — напрямую из ABAP, без HTTP (лучший путь для PIA-в-OSG).**
   `ZOSD_STORE DESTINATION 'STORE'` — «the one host seam»: `zcl_osd_adt_host=>store( command = … type = … name = … source = … )`. Команды: `LIST, READ, WRITE, CHECK, ACTIVATE, CAPABILITIES, HISTORY, REVISION, OBJECT, PACKAGE(S), CHECKRUN, PARSE, SEARCH, SYSTEM`. `ACTIVATE` уже ждёт `publish()` внутри вызывающего шага. Это и есть «ZCL_OSD_DEVELOPMENT до ZCL_OSD_DEVELOPMENT» — write-цикл PIA в OSG возможен **уже сегодня**, без ожидания фаз P2/P3 и без HTTP-loopback. Нюанс: seam OSG-only (на настоящем SAP STORE-destination нет и вызов честно падает) — то есть это ровно тот случай, для которого нужен адаптер.
2. **ADT-фасад по HTTP — кросс-средовый путь.** Маршруты (`zcl_osd_adt_router`): поиск (`informationsystem/search`, VFS contents), дерево (`nodepath/nodestructure`), DDIC, per-object source read/write (`/source/main`, `/includes/:include/source/main`), `checkruns`, `abapunit`, `classrun` (F8), `xref/closure`+`xref/readers`, packages, versions. **Ключевое: это та же поверхность ADT, что и на настоящем SAP.** Один HTTP-адаптер `zcl_pia_20_b_adt` (на `cl_http_client`) работает в оба конца — OSG loopback и SAP ICF.
3. **`ZCL_OSD_DEVELOPMENT` (design, фазы P0–P6)** — будущий слой *под* ADT-маршрутами; когда смержится, store-seam-адаптер мигрирует на него без изменения контракта PIA.

Плюс гит-слой:

- **`zcl_osd_git`** — git smart HTTP **fetch/clone** внутри OSG на ABAP (refs → upload-pack → pack → файлы коммита), переиспользует zlib из abapGit (`zcl_abapgit_zlib` засендорен в `src/osd/git/`). Это read-only: для status/diff/commit рабочего дерева не годится.
- **Рабочее дерево OSG = git-репозиторий**: status/diff — host-git или store `HISTORY`/`REVISION`.
- **abapGit на настоящем SAP** — полноценный слой сериализации + git (`zcl_abapgit_repo`, `file_status`, `diff`, stage, сериализаторы объектов; git-протокол на ABAP). В OSG приложение abapGit не запускается — но **формат общий**: дерево OSG состоит из abapGit-файлов, т.е. « serialization contract» один на обе среды.
- `READ REPORT` в рантайме OSG не найден (только в probe-инструментарии) — read-инструменты обязаны идти через абстракцию бэкенда.
- Dev-only gate: API пишет только в development-системе — правильное умолчание и для SAP, и для OSG.
- `GENERATE SUBROUTINE POOL` спроектирован (P5) — пригодится для «песочницы» (проверка сниппетов без создания объектов), не блокер.

**Итоговая матрица адаптеров `zif_pia_20_dev_backend`:**

```
zcl_pia_20_b_osg_store   — zcl_osd_adt_host=>store( )  (in-process, OSG-only, основной для M2)
zcl_pia_20_b_adt         — cl_http_client → ADT REST    (работает и в SAP, и в OSG loopback)
zcl_pia_20_b_sap_native  — READ REPORT/SEO/DDIC + abapGit (быстрые read-тулы на SAP)
```

Протокольная унификация сверху (ADT — общий протокол), ABAP-унификация внутри (`zif_pia_20_dev_backend` — общий контракт). abapGit — git/format-слой на SAP; в OSG его роль играет нативное дерево.

---

## 4. Рефакторинг executor — конкретный дельта-список PIA

Базовый план уже есть (`reports/2026-04-05-implementation-roadmap.md`: 1.1 messages → 1.2 compaction → 1.5 hypervisor → 2 hooks/permissions/prompt-builder → 3 sub-agents). PIA-специфичные добавления к нему:

| # | Что | Зачем для PIA |
|---|---|---|
| E1 | **Отдельный system message** вместо склейки в user-prompt | Кэшируемый префикс (у Claude — prompt caching), секционный builder (roadmap §2.4), coding-промпт с правилами «сначала прочитай, потом пиши, потом проверь» |
| E2 | **Message persistence** (roadmap 1.1) | Критично вдвойне: без неё нет ни компакции, ни resume сессии, ни аудита — и **ни approvals/interrupt** (см. `2026-10-05-pia-headless-frontend-architecture.md` §3) |
| E3 | **Permission-gate в цикле**: перед `mo_registry->invoke_call` — hooks/allowlist | Write-инструменты опасны; greenlist + подтверждение в UI |
| E4 | **Асинхронные tool-результаты** (ticket/poll для activate) | OSG-активация «live after this step»; в SAP массовая активация тоже не мгновенна |
| E5 | **Типизированный content-block model** (roadmap §9, `zif_llm_00_content_block`) | Сегодня executor манипулирует JSON-строками руками (regex-склейка `tool_result`-сообщений, отдельные костыли под Ollama-формат). Для write-цикла с диффами и большими исходниками это хрупко |
| E6 | **Streaming (опционально)** | UX терминала; не блокер MVP — v2-терминал уже показывает tool-прогресс через APC, LLM-ответ приходит целиком |
| E7 | **Структурированный конверт результата инструмента** (`{success,data,issues[]}`) | Диагностика компиляции/тестов должна приходить модели машиночитаемо, не свободным текстом |
| E8 | **Event emission в цикле** (`tool_started/finished`, turn lifecycle, approval lifecycle) в persisted event log | Дёшево, если делать сразу; это основа headless-принципа: сменные frontends + attach mid-session (`…headless-frontend-architecture.md`) |

Чего **не** делать: не переписывать executor на generality «под всё» — один loop, два провайдера (Claude + OpenAI-совместимые, Ollama уже покрывается вторым), остальные — через адаптеры.

---

## 5. Граница пакетов: ZLLM vs PIA

Формула концепции — «ZLLM is the LLM runtime, PIA is the agent runtime» — натурально ложится на существующий код:

```
$ZLLM   (LLM runtime — то, что остаётся библиотекой)
  llm_lazy(+wrap/composite/balancer/mock), payload_adapters, capabilities,
  predictoken, cache, json, dotenv/file/bin, codec, trace, embeddings,
  step/flow/pat (chain-слой, не нужен PIA, но пусть живёт в ZLLM)

$ZPIA  (корень; ядро в $ZPIA_00)
  executor' (E1–E7), tool registry+zif (расширенный), agent_buffer,
  session(+messages), agent_ctx, permissions/hooks, compactor,
  prompt_builder, subagents
  coding tools: read-половина (перепривязанная) + write/verify/git (новое)
  zif_pia_20_dev_backend + адаптеры: zcl_pia_20_b_osg_store, _adt, _sap_native  (см. §3.2)
  UI (presentation layer, см. 2026-10-05-pia-headless-frontend-architecture.md):
  zif_pia_00_view / zif_pia_00_commands / event log / AMC-publisher;
  frontends: terminal (classrun), TUI (из $ZLLM_05), HTML workbench,
  SAP GUI (repl+ALV+spl), ADT/VS Code, headless run( )
```

Физический перенос executor/registry/buffer/session из `$ZLLM_00` в `$ZPIA` — вопрос одного рефакторинг-прохода (abapGit-friendly). Альтернатива на первый релиз — оставить их в ZLLM и считать «ZLLM agent core» deprecated-in-favor-of-PIA; но чище сразу провести границу, пока потребителей нет.

Из `src/02` (YAAC и граф) — отдельная подбиблиотека `ZLLM-CODE-ANALYSIS` (или в PIA как `pia_index_*`), подключается позже.

---

## 6. Дорожная карта (дельта к апрельскому roadmap)

| Этап | Что | Критерий готовности |
|---|---|---|
| **M0** | OSG в docker + ZLLM v2 core внутри OSG + один LLM-вызов из ABAP (проба TLS; fallback — Ollama http) | `q/a` работает в OSG |
| **M1** | Граница пакетов `$ZPIA`; executor E1+E2+E5 (system message, персистенция, content blocks); registry + permission level | research-агент ходит в OSG-LLM, сессии с сообщениями |
| **M2** | `zif_pia_20_dev_backend` под контракт §2.1 `docs/pia-development-contract` (OSG): `activate → {state: checked\|pending\|published\|failed, op_id, generation_id}` (op_id — операции; generation_id после подтверждённой публикации; диагностика различает отказ валидации/сбой билда/конфликт ревизии; lookup идемпотентен, статус переживает recycle; поллинга достаточно, AMC — супплмент); `run_tests(object, expected_generation)` — изолированный контекст, отдельные execution-status и test-verdict (красный тест ≠ ошибка запуска), мисматч поколения = явная ошибка. **Разделение владения: OSG — статус операции/публикация/поколение; PIA — персистентный checkpoint, выход из шага, resume в новом шаге.** Приёмка = сценарий §2.1 (red→green→delete + ADT-совместимость); interim — внешний ADT-активатор | сценарий приёмки из ABAP полностью зелёный |
| **M3** | `zcl_pia_20_b_sap_native`/ADT на a4h (+ abapGit как git-слой) + тот же агент, другой бэкенд | тот же сценарий на настоящем SAP |
| **M4** | Compaction (roadmap 1.2), sub-agents (registry filter), permissions UI в web-терминале | длинная self-hosting-сессия не теряет контекст |
| **M5** | **Self-hosting demo**: PIA-поколение N модифицирует класс PIA в дереве OSG, тесты зелёные, перезапуск → N+1 | запись loop'а «agent modifies itself» |

M0–M2 не зависят от апрельских Phase 1.5–3 (hypervisor и пр.) — их можно параллелить.

---

## 7. Риски и открытые вопросы

1. **TLS из OSG `cl_http_client`** — не подтверждён для внешних https-API. Проба M0. Mitigation: Ollama локально / http-прокси.
2. **Фазы OSG dev-API**: `ZCL_OSD_DEVELOPMENT` — design, не код. Но это **не блокер**: store-seam (`zcl_osd_adt_host=>store`) уже даёт READ/WRITE/CHECK/ACTIVATE/CHECKRUN из ABAP; при смерже dev-API адаптер переезжает на него без смены контракта. Отсутствует `DELETE` в store-командах — interim через ADT HTTP или обходиться без delete в M2.
3. **Асинхронная активация/swap** — агент должен понимать «active, live after this step»; E4.
4. **Строковый JSON в executor** — при write-циклах объёмы диффов/диагностики вырастут; E5 обязательнее, чем казалось в research-сценарии.
5. **Кэш LLM vs write-цикл** — закэшированный ответ с устаревшим tool_result на изменившийся код; ключ кэша должен включать ревизию workspace.
6. **Ollama-совместимость** как дешёвый контур разработки — уже решена в v2 (capabilities + parse-костыли); при E5 костыли уходят в адаптер.
7. **Скорость cold build в OSG** (30–350 s по замерам OSG) — fast path проектируется; для PIA это означает: не пересоздавать объекты без нужды, писать в существующие (warm 0.5–1.5 s).

---

## 8. Соответствие pi (reference) ↔ PIA-стек

| pi (packages/*) | PIA-эквивалент | Источник |
|---|---|---|
| `ai` (providers) | ZLLM llm_lazy + adapters | есть |
| `agent` (loop, session) | executor' + session(+messages) | adapt |
| `coding-agent` (tools, prompts, permissions) | PIA coding tools + prompt_builder + permissions | новое частично |
| `client` / `tui` | web terminal (APC/xterm), REPL, GUI | есть |
| `mcp` | SKIP на MVP (A2A — свой путь) | — |
| `protocol` (RPC) | потом: A2A / AMC-канал | есть задел |
| `skills`/`packages` | doc store scope REPO (project memory) | adapt |
| `durable`, `evals`, `telemetry` | trace/qa_store/session store | частично |

---

**Вывод.** Переиспользуем: LLM-слой целиком, agent-скелет с рефакторингом, все read-инструменты (перепривязав на бэкенд-контракт), buffer, sessions, web-терминал, doc store. Новое — только то, что и составляет PIA: write/verify/git-инструменты над двумя dev-бэкендами, permissions, coding-промпт, self-hosting-цикл. Апрельский roadmap по compaction/hooks/sub-agents остаётся в силе и ложится в M4 без изменений.
