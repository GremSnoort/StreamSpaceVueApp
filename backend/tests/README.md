# Backend E2E Tests

Отдельная папка для e2e/smoke тестов backend.

## `e2e_smoke.sh`

Покрывает:

- поднятие чистого временного Postgres;
- прогон всех SQL миграций;
- старт Go backend;
- базовый auth/follow/video flow;
- регрессии:
  - favorites put/list consistency;
  - `download_token_issue` ambiguity fix;
  - transcode enqueue after publish.

## Запуск

```bash
bash backend/tests/e2e_smoke.sh
```

Опциональные env:

- `PG_BIN_DIR` (по умолчанию `~/ARENADATA/github/orioledb/output_bin/bin`)
- `PGDATA` (по умолчанию `/tmp/pgdata-demo`)
- `API_PORT` (по умолчанию `18084`)
- `STORAGE_ROOT` (по умолчанию `/tmp/storage-e2e`)
- `INTERNAL_API_TOKEN` (по умолчанию `test-internal-token`)
- `DATABASE_URL` (по умолчанию `postgres://app@localhost:5432/app?sslmode=disable`)
