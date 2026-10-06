# Следующий шаг PIA (обновлено 2026-10-06 04:00)
M2: checkpoint/resume под P3a (op_id/generation_id) — ядро для устойчивого self-hosting
## ✅ ЗАКРЫТО (эта сессия)
- M0: LLM из ABAP в OSG
- M1: Агентный цикл (read→write→activate→verify PASS)
- P2a: CREATE/DELETE через STORE (принята OSG)
- ЧАТ: HTML multi-turn (русский, thinking, EN-заголовок)
- TUI: WebSocket терминал (xterm.js, echo + post-fact стрим)
- A2A: PIA как сервер для внешних агентов
- MCP: Claude Code → PIA bridge
- SELF-HOSTING: PIA модифицирует свой код (полностью автономно)
- Activate false-negative: FIX (no-refusal = success)
- Репо: github.com/oisee/pia (MIT, скриншоты)

## 🔜 СЛЕДУЮЩИЕ ЦЕЛИ (по приоритету)
1. M2: checkpoint/resume под P3a контракт (op_id, ACTIVATION_STATUS, generation_id)
2. Реальный стриминг через AMC (ждать drain fix от коллеги или делать AMC push)
3. LLM таймауты (нужен shim fix от коллеги)
4. P3b: RUN_TESTS из ABAP (коллега работает)
5. Устойчивый self-hosting: PIA чинит реальный баг в себе (не добавление метода)
6. A2A multi-session + async tasks
7. MCP: больше тулов (read/write/activate как отдельные MCP tools)

## 🏗 Инфраструктура
- PIA сервер: :8020 (диапазон 20-29, heavy-wrapper, OSD_BIND=0.0.0.0)
- Коллега OSG: :8091 (диапазон 90-99, P3a EV_JSON готов, ждёт загрузки)
- Метроном: cron */9, herdr pane run
- Codex-approver: авто-approve read-only, уведомление на опасное
