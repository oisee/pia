# M2 Design: Checkpoint/Resume для устойчивого Self-Hosting

**Дата:** 2026-10-06 04:00
**Статус:** DESIGN (реализация — следующая сессия)
**Зависимости:** P3a контракт (op_id/generation_id, ACTIVATION_STATUS) — загружен на :8091

## Проблема

Self-hosting сейчас требует рестарта сервера после активации:
```
PIA пишет код → activate → ok → [требуется restart] → новый код работает
```

Если PIA модифицирует свой executor — она не может использовать новую версию
до перезапуска. Нет механизма:
- Сохранить состояние диалога перед перезапуском
- Восстановить контекст после перезапуска
- Отслеживать какая генерация сейчас живая

## Решение: Checkpoint/Resume

### 1. Checkpoint (сохранение)

```abap
" zcl_pia_00_session — добавить сериализацию
METHODS to_json RETURNING VALUE(rv_) TYPE string.
  " { messages: [...], trace: [...], events: [...], task: "..." }
METHODS from_json IMPORTING iv_json TYPE string.
```

### 2. Resume Token (в A2A/чат)

```json
// Ответ A2A после активации:
{
  "answer": "...",
  "checkpoint": "eyJtZXNzYWdlcyI6W119...",  // base64(to_json(session))
  "activation": {
    "op_id": "e33fdb6f-...",
    "state": "published",
    "generation_id": "bcb90e37..."
  }
}
```

### 3. Resume (следующий запрос)

```json
// Следующий A2A запрос с checkpoint:
{
  "message": { "role": "user", "parts": [...] },
  "checkpoint": "eyJtZXNzYWdlcyI6W...",  // восстановить сессию
  "expected_generation": "bcb90e37..."    // проверить поколение
}
```

### 4. Executor: прерывание на активации

```abap
" В executor loop, после activate:
IF ls_result-activation_state = 'pending'.
  " Сохранить checkpoint, выйти из цикла
  rs_-checkpoint = mo_session->to_json( ).
  rs_-needs_resume = abap_true.
  RETURN.
ENDIF
```

### 5. Backend v2: op_id tracking

```abap
INTERFACE zif_pia_20_dev_backend.
  METHODS activate
    RETURNING VALUE(rs_) TYPE ts_activate_result.
    " ts_activate_result: { state, op_id, generation_id, issues[] }

  METHODS get_activation_status
    IMPORTING iv_op_id TYPE string
    RETURNING VALUE(rs_) TYPE ts_activate_result.
ENDINTERFACE.
```

## Сценарий устойчивого self-hosting

```
1. PIA получает задачу: "Fix bug in zcl_pia_00_executor"
2. read_object → видит баг
3. write_source → пишет фикс
4. activate → op_id=pending
5. CHECKPOINT: сериализует сессию + op_id
6. [публикация — OSG делает после шага]
7. Следующий запрос: resume из checkpoint
8. get_activation_status(op_id) → published, generation_id=X
9. verify: код в generation X работает?
10. Если нет → повторить цикл
```

## Файлы для изменения

| Файл | Что |
|---|---|
| `zcl_pia_00_session` | +to_json/from_json |
| `zcl_pia_00_executor` | +checkpoint на pending activate |
| `zif_pia_20_dev_backend` | +get_activation_status, ts_activate_result |
| `zcl_pia_20_b_osg_store` | +op_id/generation_id parsing (P3a EV_JSON) |
| `zcl_pia_30_f_a2a` | +checkpoint/resume в API |
| `zcl_pia_30_f_chat` | +checkpoint/resume |

## Оценка

1-2 сессии фокусной работы после загрузки P3a на :8020.
