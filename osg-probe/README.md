# OSG probe — M0/M2 proof, 2026-10-05

Живой инстанс OSG (from source, `npm start`, порт 3030), объект `ZCL_PIA_PROBE` в `$TMP` (`local/tmp` OSG-репо), весь цикл — через ADT REST (`zcl_pia_backend_adt`-путь).

## Результаты

| Шаг | Команда | Результат |
|---|---|---|
| Класс файлами в `local/tmp` | — | виден сервером **сразу**, без рестарта |
| Активация (новый объект) | `pia_activate.sh` | 200, 29.5 s, `activationExecuted=true`, генерация перезагружена (WBCROSSGT 5829→5834) |
| **HTTPS-проба из ABAP** | `pia_classrun.sh` | **`HTTPS status 401, body: {"type":"error","error":{"type":"authentication_error","message":"invalid x-api-key"}}`** — TLS + POST + headers + чтение ответа работают в ABAP внутри OSG |
| ABAP Unit (1 зелёный + 1 намеренно красный) | `pia_unittest.sh` | 200, 2.3 s, XML: pass без alerts; fail = `kind="failedAssertion" severity="critical"`, `Expected [1]/Actual [2]`, stack с navigationUri на строки исходника |
| Warm-итерация (lock→PUT→unlock→activate) | `pia_warm.sh` | PUT 4.8 s + activate 24.5 s ≈ ~29 s **на полный publish+reload живого сервера** (внимание: это НЕ warm-регрессия билда — в изолированном прогоне OSG класс/интерфейс/include ≈ 2.4 s; при сравнениях сверять mode/readiness/generation, см. письмо коллеги 2026-10-05) |

## Значение

- **M0 (коннективность LLM-слоя) закрыт**; полный M0 («ZLLM core установлен в OSG») сворачивается в M1/M2 — payload-адаптеры ZLLM подключаются, когда появится второй формат провайдера (см. ревью 2026-10-05-1843): LLM-слой ZLLM будет работать в OSG; живой round-trip с моделью (ABAP-fine-tuned!) подтверждён (`cl_http_client` subset подтверждён end-to-end против api.anthropic.com).
- **Verification-loop реален**: юнит-отчёт приходит структурированным XML с expected/actual и точными ссылками на строки — ровно то, что должен парсить `run_tests`-инструмент PIA.
- Стоимость итерации агента ~30 с (активация) — цель W4/fast-path понятна.

## Операционные детали (выяснены вживую)

- Сессия: `HEAD /core/discovery` c `x-csrf-token: fetch` → token + `sap-contextid` cookie; все записи — с ними + `x-sap-adt-sessiontype: stateful`.
- `classrun` — **POST** (не GET; GET уходит в miss-registry).
- PUT source требует `?lockHandle=` (lock через `POST ?_action=LOCK&accessMode=MODIFY`).
- Любой логин принимается (loopback-дизайн).
- Файл в `local/tmp` подхватывается watcher'ом на лету.

## Как воспроизвести

```bash
cd ~/dev/osg-adt-abap && npm start        # ждём "serving generation … on :3030"
cp zcl_pia_probe.clas.* ~/dev/osg-adt-abap/local/tmp/
./pia_activate.sh && ./pia_classrun.sh && ./pia_unittest.sh
```
