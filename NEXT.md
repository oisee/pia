# Следующий шаг PIA
1. ЧАТ-UX: H1 только EN + индикатор 'думает...' при отправке; затем TUI/terminal via APC + стриминг (порт $ZLLM_05)
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
