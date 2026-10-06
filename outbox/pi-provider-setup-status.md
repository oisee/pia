# Локальный Pi: подключения и проверка

Дата: 2026-10-06. Машина: текущая рабочая среда Alice. Pi: 1.0.3.
Исходный отчёт прочитан из `/mnt/safe/lean_ai/pi-provider-launch-guide.md`.

Настройки сохранены в `/home/alice/.pi/agent/models.json` и
`/home/alice/.pi/agent/settings.json`.
В `/home/alice/.bashrc` исправлен `AZURE_OPENAI_BASE_URL`: теперь это
`https://aicaster.openai.azure.com/openai/v1`, а не полный URL запроса.
Ключи в новых файлах не записаны: используются ссылки на переменные окружения.
Существующий `auth.json` сохранён; его credentials имеют приоритет над переменными.

Резервные копии до изменения:
`/home/alice/.pi/agent/backups/providers-20261006T044739444819Z/`.

| Провайдер | Endpoint | Запуск | Проверка через Pi |
|---|---|---|---|
| Azure | `https://aicaster.openai.azure.com/openai/v1` | `pi --model azure/gpt-6.1-sol --thinking medium` | Ответ `OK`, exit 0 |
| Z.ai | `https://api.z.ai/api/v1` | `pi --model zai/glm-5.3 --thinking high` | Ответ `OK`, exit 0 |
| Ollama | `http://192.168.8.107:11434/v1` | `pi --model ollama/ornith:latest` | Ответ `OK`, exit 0 |

Обычный `pi` выбирает Azure GPT-6.1 Sol с thinking `medium`.
Внутри Pi: `/model` выбирает модель, `Ctrl+P` переключает три выбранные модели,
`/thinking` меняет уровень reasoning. Продолжение сессии: `pi --continue` или
`pi --resume`; сохранённая сессия может восстановить прежнюю модель.

Для уже открытого терминала перед запуском:

```bash
export AZURE_OPENAI_BASE_URL='https://aicaster.openai.azure.com/openai/v1'
pi
```

Новый терминал получает исправленный адрес из `.bashrc`.
Для запуска исходников из checkout `/home/alice/dev/pia/pi` используется тот же
каталог конфигурации `~/.pi/agent`; зависимости checkout пока не установлены,
поэтому реальные проверки выполнены установленной командой `pi`.

Все три credentials-проверки вернули `ready`, все модели появились в списке.
Реальные запросы отправлялись без инструментов, контекстных файлов и сохранения
сессии. Сервер Ollama подтвердил наличие Ornith 9B и объявил capabilities
`completion`, `tools`, `thinking`; фактические вызовы инструментов не проверялись.
Клиентские лимиты Ornith оставлены 32768/8192; для него настроен резерв
compaction 8192 и сохранение последних 12000 токенов, чтобы настройки по
умолчанию не занимали почти весь небольшой контекст.
