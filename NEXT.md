# Следующий шаг PIA
1. P2a-ПРИЁМКА на http://127.0.0.1:8091 (сервер коллеги стабилен, GO дан):
   a) ADT-create probe-класса ZPIA_P2A_PROBE на 8091 (POST /oo/classes, формат — из adt-тестов vscode/c2a)
   b) probe (phase-машина по store OBJECT): нет объекта → STORE CREATE (CLAS, IV_JSON={"package":"$TMP","description":"..."}, source=красный selfcheck); есть+красный → WRITE зелёный; зелёный → DELETE
   c) между фазами: внешний ADT-activate + GET ?version=active + classrun disposable (RED→GREEN) + 404 после DELETE
   d) отчёт коллеге; после — согласовать рестарт 8091 с их EV_JSON {active,live,note,issues} и снять "gap-aware" ветку моего адаптера
2. ЧАТ-ДЕМО $ZPIA_30_f_web (порт $ZLLM_05) + multi-turn session
3. M2: checkpoint/resume + backend v2
4. Репо: github.com/oisee/pia ✅ (мастер залит, MIT)
6. Когда чат встанет: скриншоты (терминал-multi-turn, HTML-чат, APC-workbench) → README в github.com/oisee/pia
