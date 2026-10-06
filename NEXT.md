# Следующий шаг PIA
1. TUI/terminal via APC + стриминг (порт $ZLLM_05 -> zcl_pia_30_f_tui): APC-хендлер + xterm.js, подписка на event log сессии; до стриминга LLM — стрим тул-событий. (ЧАТ-UX: EN-H1 + thinking — СДЕЛАНО 2026-10-06)
   a) ADT-create probe-класса ZPIA_P2A_PROBE на 8091 (POST /oo/classes, формат — из adt-тестов vscode/c2a)
   b) probe (phase-машина по store OBJECT): нет объекта → STORE CREATE (CLAS, IV_JSON={"package":"$TMP","description":"..."}, source=красный selfcheck); есть+красный → WRITE зелёный; зелёный → DELETE
   c) между фазами: внешний ADT-activate + GET ?version=active + classrun disposable (RED→GREEN) + 404 после DELETE
   d) отчёт коллеге; после — согласовать рестарт 8091 с их EV_JSON {active,live,note,issues} и снять "gap-aware" ветку моего адаптера
2. ЧАТ-ДЕМО $ZPIA_30_f_web (порт $ZLLM_05) + multi-turn session
3. M2: checkpoint/resume + backend v2
4. Репо: github.com/oisee/pia ✅ (мастер залит, MIT)
6. Когда чат встанет: скриншоты (терминал-multi-turn, HTML-чат, APC-workbench) → README в github.com/oisee/pia

## Горячие хвосты чата (2026-10-06 поздняя ночь)
- НЕТ ТАЙМАУТА на LLM-вызов: зависший z.ai блокирует весь однопоточный рантайм (дважды ловили). Фикс: таймаут в llm_http (проверить поддержку в shim-клиенте) или async. Сообщить коллеге — это общий паттерн "долгий HTTP в handler".
- Русский ввод починен (unescape_url + \uXXXX-escape в json_util); модель ответила на бирманском -> добавлено правило языка; z.ai подвисает -> повторить тест.
## Чат-UX (от Alice, 2026-10-06)
- H1 только EN: "PIA — pi, writing itself in ABAP" (рус. убрать из заголовка)
- SEND: индикатор "думает..." сразу при отправке (кнопка disabled + статус) — сейчас выглядит сломанным
- TUI/terminal via APC + стриминг ответов — следующий фронт ($ZLLM_05 порт)

## ✅ P2a ПРИНЯТА (2026-10-06): CREATE→RED→green→GREEN→DELETE→404 на :8091
STORE CREATE/DELETE из ABAP работают по контракту; после рестарта 8091 с JSON CHECK/ACTIVATE — включится ветка моего адаптера (active/issues из EV_JSON).

## P3a wire contract (draft коллеги, 2026-10-06) — основа zif_pia_20_dev_backend v2
- ACTIVATE JSON: state/op_id/generation_id + active/live/note/issues + type/name/created_at/updated_at/failure_stage
- Lookup: STORE ACTIVATION_STATUS IV_JSON={op_id} — тот же документ, read-only; unknown/expired -> NOT_FOUND
- Retention: terminal >=24h; pending жив пока host; журнал вне serving child; parent restart: unfinished->failed/recovery (без ложного published)
- Реализация в docs/abap-development-api.md секция 'P3a wire contract'
- P3a-уточнения (review): op_id даже при refusal (refusal->failed сразу); checked=промежуточный; CHECK без op; completed_at терминально-иммутабельно; published историчен -> RUN_TESTS сверяет expected_generation и явно отказывает; решение о тестах по state=published (не active/live)
- P3a impl (2026-10-06): журнал + ACTIVATION_STATUS, pending->published/failed, recovery, >=24h retention, 10 focused PASS (гонки владения/IPC и потеря op_id закрыты ревью). SCOPE: lookup на ТОТ ЖЕ порт source-host; журнал по root+HTTP-port; второй владелец отказывается. На 8091 ещё не загружен — жду live GO.
- P3a: LIVE_GO получен, механизм доказан коллегой из ABAP. МОЙ probe (zpia_p3a_probe) не публикуется: ACT=200 -> 'not built' — прогнать CHECKRUN источника, найти отказ. Адаптер на op_id готов к подключению.

## A2A + MCP (2026-10-06, от Alice)
- $ZPIA_30: A2A handler (порт zcl_llm_00_a2a_handler) — PIA как A2A-сервер: внешний агент (Claude/Copilot) даёт задачу, PIA выполняет тулами в SAP/OSG
- $ZPIA_30: A2A client (порт zcl_llm_00_a2a_client) — PIA зовёт внешних агентов для подзадач
- MCP: потом, через a2a-mcp-server bridge
