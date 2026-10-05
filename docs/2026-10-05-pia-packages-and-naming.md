# Пакеты и префиксы PIA: $ZPIA*

**Дата:** 2026-10-05
**Основа:** конвенции `$ZLLM*` (zllm-v2) с исправлением замеченных расползаний; сравнение с `ZCL_OSD_*`/packs в OSG.

---

## 1. Что показывает $ZLLM (факты из репо)

Хорошее:
- пакеты `$ZLLM_00…05, 99` с числовым сегментом; объекты несут тот же сегмент: `zcl_llm_05_*` в `$ZLLM_05`;
- подсемейства инфиксом: `zcl_llm_00_agent_t_*` — инструменты агента;
- корневой фасад без номера: `zcl_llm` / `zif_llm`.

Что исправляем в PIA (наблюдаемое в zllm-v2):
- **число ≠ пакет**: в `$ZLLM_01…04` лежат `zcl_llm_00_*` объекты (20+ штук в 02);
- **чужие префиксы**: `zlocal_*`, `zoai_01_enh_*` внутри zllm-пакетов;
- **объекты без сегмента**: `zcl_llm_str_to_ted`, `zcl_llm_log_*` (99-й пакет назван по-другому);
- **нет собственных исключений**: всё на общем `zcx_s`.

## 2. Правила PIA

1. **Один префикс — `PIA`.** Никаких сторонних префиксов внутри `$ZPIA*` (внешние зависимости — только `ZLLM*` и `ZCX_S` на границе LLM-слоя).
2. **Пакет = `$ZPIA_NN`; после `NN` — никакого текста** (иначе префикс объектов `…_PIA_NN_…` перестаёт совпадать с именем пакета-владельца, как расползлось в zllm: `$ZLLM_02` с `zcl_llm_00_*` внутри). Назначение подпакета — в его **Description (CTEXT)**. Сегмент `NN` в имени объекта обязателен и совпадает с пакетом-владельцем.
3. **Подсемейства — инфиксом после NN:**
   - `ZCL_PIA_NN_T_*` — инструменты (tools);
   - `ZCL_PIA_NN_B_*` — бэкенды (dev backends);
   - `ZCL_PIA_NN_F_*` — фронтенды.
4. **Типовые префиксы:** `ZCL_` / `ZIF_` / `ZCX_` / программы `ZPIA_NN_*` / таблицы и структуры `ZPIA_NN_*` / CDS `ZPIA_NN_I_*` / transакции `ZPIA_NN_*`.
5. **Корневой фасад без номера:** `zcl_pia` + `zif_pia` в `$ZPIA` (зеркало `zcl_llm`): `zcl_pia=>run( )`, `zcl_pia=>version( )`.
6. **Исключения свои:** `ZCX_PIA_00_*` (корень + конкретные); `zcx_s` допустим только как проброс с LLM-слоя.
7. **`$` → транспортабельность без переименований:** объекты не меняют имён при переходе `$ZPIA_NN` → `ZPIA_NN` (меняются только пакеты).
8. **Длина ≤ 30**, имена — по regex OSG `^[A-Z0-9_]{1,40}$` ($TMP-правила_store).

## 3. Дерево пакетов

| Пакет | Содержимое | Примеры имён |
|---|---|---|
| `$ZPIA` | корень + фасад | `zcl_pia`, `zif_pia` |
| `$ZPIA_00` | **agent core**: executor', session(+messages), ctx, buffer, registry, permissions/hooks, compactor, prompt_builder, event log | `zcl_pia_00_executor`, `zif_pia_00_session`, `zcx_pia_00_root` |
| `$ZPIA_10` | инструменты **read** | `zcl_pia_10_t_read_object`, `zcl_pia_10_t_search`, `zcl_pia_10_t_grep` |
| `$ZPIA_15` | инструменты **write/verify/git** | `zcl_pia_15_t_write_source`, `zcl_pia_15_t_activate`, `zcl_pia_15_t_run_tests`, `zcl_pia_15_t_git_diff` |
| `$ZPIA_20` | dev-бэкенды: контракт + адаптеры | `zif_pia_20_dev_backend`, `zcl_pia_20_b_osg_store`, `zcl_pia_20_b_adt`, `zcl_pia_20_b_sap_native` |
| `$ZPIA_30` | фронтенды (seam `zif_pia_00_view/commands` живёт в 00) | `zcl_pia_30_f_terminal`, `zcl_pia_30_f_web`, `zcl_pia_30_f_gui`, `zcl_pia_30_f_adt` |
| `$ZPIA_90` | демо/отчёты | `zpia_90_demo` |
| `$ZPIA_99` | инфра: лог, персист, утилиты | `zcl_pia_99_store`, `zcl_pia_99_log` |

Нумерация — **десятка = домен** (00–09 core, 10–19 tools, 20–29 backends, 30–39 frontends, 90 демо, 99 инфра). Соседи внутри десятка — предпочтительно через 5 (10, 15), можно плотнее, но **минимальный зазор — 2**: никогда не вплотную, между любыми двумя соседями всегда остаётся свободный номер для вставки. Новый подпакет берёт середину самой большой дырки (11–14 → 12, 16–18 → 17).

## 4. Карта миграции (что из ZLLM во что переезжает)

| Было (zllm-v2) | Станет (PIA) |
|---|---|
| `zcl_llm_00_executor` | `zcl_pia_00_executor` (+E1–E8) |
| `zcl_llm_00_tool_registry` / `zif_llm_00_tool` / `zcl_llm_00_tool_custom` | `zcl_pia_00_registry` / `zif_pia_00_tool` / `zcl_pia_00_tool_base` |
| `zcl_llm_00_agent_buffer` | `zcl_pia_00_buffer` |
| `zif/zcl_llm_00_session(_store)` | `zif/zcl_pia_00_session`, `zcl_pia_00_session_store` |
| `zcl_llm_00_agent_ctx` | `zcl_pia_00_ctx` |
| `zcl_llm_00_research_agent` | `zcl_pia_00_agent` (шаблон) |
| `zcl_llm_00_agent_t_source/search/grep/…` | `zcl_pia_10_t_read_object / search / grep / …` (за `zif_pia_20_dev_backend`) |
| — (новое) | `zcl_pia_15_t_*`, `zcl_pia_20_b_*`, `zcl_pia_30_f_*` |
| `zcl_llm_05_*` (web terminal) | `zcl_pia_30_f_web_*` |
| `zllm_00_repl`, session browser | `zcl_pia_30_f_gui` + `zpia_90_*` |

**Остаётся в ZLLM** (не переезжает): llm_lazy + adapters, capabilities, predictoken, cache, json, dotenv, codec, trace, embeddings — PIA зависит от ZLLM как от библиотеки (см. assessment §5).

## 5. OSG-специфика

- `$ZPIA_NN` — обычные DEVC в дереве (store создаёт DEVC; «library package is ReadOnly» нас не касается).
- Store `create` требует именованный пакет → self-hosting пишет в свои `$ZPIA_NN`, не в `$TMP`.
- Дерево OSG = abapGit-формат: репо PIA кладётся каталогами `src/00…99` один-в-один с пакетами (как zllm-v2).

## 6. Резюме одной строкой

> Пакеты `$ZPIA_NN`: десятка = домен (00 core, 10 tools, 20 backends, 30 frontends, 90/99 хвосты), соседи внутри десятка через 5; объекты `Z{CL,IF,CX}_PIA_NN[_{T,B,F}]_NAME` с NN = пакету; фасад `zcl_pia`; один префикс; исключения свои; `$`→транспортабельно без переименований.
