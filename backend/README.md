# StreamSpace Backend (Go + PostgreSQL Fat DB)

Тонкий HTTP API-слой поверх PostgreSQL-функций из `backend/migrations/`.

## Runtime

- Go `1.22+`
- PostgreSQL с применёнными миграциями

## Конфигурация

- `DATABASE_URL` (default: `postgres://app@localhost:5432/app?sslmode=disable`)
- `PORT` (default: `8080`)
- `CORS_ALLOWED_ORIGINS` (default: `http://localhost:5173,http://127.0.0.1:5173`)
- `COOKIE_SECURE` (default: `false`)
- `RATE_LIMIT_PER_MINUTE` (default: `240`)
- `UPLOAD_MAX_BYTES` (default: `536870912` = `512MB`)
- `STORAGE_ROOT` (default: `../uploads`)
- `TRANSCODE_WORKER_ENABLED` (default: `true`)
- `TRANSCODE_WORKER_ID` (default: `api-worker-1`)
- `FFMPEG_BIN` (default: `ffmpeg`)
- `FFPROBE_BIN` (default: `ffprobe`)
- `INTERNAL_API_TOKEN` (optional, защита `/internal/*`)

## База данных

Перед запуском backend примените миграции.

- См. `backend/migrations/README.md`

## Запуск

```bash
cd backend
go run ./cmd/api
```

## Общие правила API

### Health

- `GET /healthz` -> `200 {"status":"ok"}`

### Аутентификация

Поддерживаемые источники сессии (в порядке проверки):

- `Authorization: Bearer <session_token>`
- `X-Session-Token: <session_token>`
- cookie `session_token`

`GET /auth/me` и `GET /api/me` возвращают объект пользователя напрямую:

```json
{
  "user_id": "...",
  "email": "...",
  "username": "...",
  "display_name": "...",
  "avatar_url": "...",
  "is_active": true
}
```

### CSRF

Для cookie-сессии mutating-запросы (`POST/PUT/PATCH/DELETE`) требуют `X-CSRF-Token`, совпадающий с cookie `csrf_token`.

- Для token-based запросов (`Authorization` / `X-Session-Token`) CSRF не требуется.
- Для `/internal/*` CSRF не применяется.

### Ошибки

Базовый формат ошибок:

```json
{"error":"message","ok":false}
```

Ошибки PostgreSQL возвращаются как:

```json
{"error":"database error","code":"...","message":"...","ok":false}
```

## REST API

Ниже перечислены актуальные роуты из `cmd/api/main.go`.

### Auth

- `POST /auth/register`
  - body: `{"email","username","password"}` (`password` минимум 6)
  - response: `201 {"user": {...}}` + cookies `session_token`, `csrf_token`
- `POST /auth/login`
  - body: `{"login","password"}`
  - response: `200 {"user": {...}}` + cookies `session_token`, `csrf_token`
- `POST /auth/logout`
  - response: `204` (очищает `session_token` и `csrf_token`)
- `GET /auth/me`
- `GET /api/me` (legacy alias)

### Users / Follow

- `GET /users/{userId}`
- `POST /users/{userId}/follow` (auth)
- `DELETE /users/{userId}/follow` (auth)
- `GET /users/{userId}/videos?limit=50&offset=0`
- `GET /me/following?limit=50&cursorCreatedAt&cursorUserId` (auth)
- `GET /me/followers?limit=50&cursorCreatedAt&cursorUserId` (auth)

### Folders (auth)

- `GET /me/folders?type=<required>&parentId&limit=50&cursorCreatedAt&cursorFolderId`
- `GET /me/folders/tree?type=<required>`
- `POST /me/folders`
  - body: `{"type","name","parentId"}`
  - response: `201 {"folderId":"..."}`
- `GET /me/folders/{folderId}`
- `PATCH /me/folders/{folderId}`
  - body: `{"name"?,"parentId"?}` (хотя бы одно поле)
- `DELETE /me/folders/{folderId}` -> `204`
- `GET /me/folders/{folderId}/videos?limit=50&cursorOrderIndex&cursorAddedAt&cursorVideoId`
- `POST /me/folders/{folderId}/videos`
  - body: `{"videoId","orderIndex"?}`
- `DELETE /me/folders/{folderId}/videos/{videoId}` -> `204`
- `POST /me/folders/{folderId}/videos/{videoId}/move`
  - body: `{"toFolderId","toOrderIndex"?}`

### Videos

- `POST /videos/` (auth)
  - body: `{"title","description"?,"visibility","folderIds"?}`
  - response: `201 {"videoId":"..."}`
- `POST /videos/upload` (auth, multipart)
  - fields: `file` (required), `title` (required), `description` (optional), `visibility` (optional, default `private`)
  - allowed extensions: `.mp4`, `.mov`, `.m4v`, `.webm`
  - allowed MIME: `video/mp4`, `video/quicktime`, `video/webm`
  - response: `201 {"videoId":"...","status":"processing"}`
- `GET /videos/{videoId}`
- `PATCH /videos/{videoId}` (auth)
  - body: `{"title"?,"description"?,"visibility"?}`
- `DELETE /videos/{videoId}` (auth) -> `204`
- `POST /videos/{videoId}/publish` (auth)
- `POST /videos/{videoId}/unpublish` (auth)
- `GET /me/videos?limit=50&offset=0` (auth)
- `GET /videos/{videoId}/playback`
  - response: `{"type":"hls","manifestUrl":"/stream/hls/{videoId}/{master}.m3u8","meta":...}`
- `GET /stream/hls/{videoId}/*` (streaming manifest/segments)

### Reactions / Comments

- `PUT /videos/{videoId}/reaction` (auth)
  - body: `{"value":"like|dislike|none"}`
- `GET /videos/{videoId}/reaction`
- `GET /videos/{videoId}/reactions?value&limit=50&cursorCreatedAt&cursorUserId`
- `GET /videos/{videoId}/comments?limit=50&cursorCreatedAt&cursorCommentId`
- `POST /videos/{videoId}/comments` (auth)
  - body: `{"text":"..."}` -> `201 {"commentId":"..."}`
- `PATCH /videos/{videoId}/comments/{commentId}` (auth)
  - body: `{"text":"..."}`
- `DELETE /videos/{videoId}/comments/{commentId}` (auth) -> `204`

### Favorites (auth)

- `GET /me/favorites?folderId&limit=50&cursorAddedAt&cursorVideoId`
- `GET /me/favorites/all?limit=50&cursorAddedAt&cursorVideoId`
- `PUT /me/favorites/{videoId}`
  - body: `{"folderId"?,"orderIndex"?}`
- `DELETE /me/favorites/{videoId}?folderId`
- `GET /me/favorites/{videoId}`

### Purchases / Download

- `POST /videos/{videoId}/purchase-download` (auth)
  - body: `{"provider","providerPaymentId","amountCents","currency"}`
  - response: `201 {"purchaseId":"..."}`
- `GET /me/purchases?status&limit=50&offset=0` (auth)
- `GET /me/purchases/{purchaseId}` (auth)
- `POST /videos/{videoId}/download-token` (auth)
  - body: `{"purchaseId"?,"ttl"?}`
- `GET /videos/{videoId}/download` (auth)
  - optional query: `token`, `mode=file`
  - без `mode=file` возвращает JSON с `downloadUrl`
  - с `mode=file` отдаёт файл как attachment

### Feed

- `GET /feed/following?limit=50&offset=0` (auth)
- `GET /feed/hot?limit=50&offset=0&window=48%20hours`
- `GET /feed?limit=50&offset=0&window=48%20hours`
  - объединяет `following` + `hot`, добавляет поле `source`

### Internal API

Если задан `INTERNAL_API_TOKEN`, нужен header `X-Internal-Token`.

- `POST /purchases/{purchaseId}/status`
  - body: `{"status":"..."}`
- `POST /internal/transcode/enqueue`
  - body: `{"videoId":"...","priority"?}`
- `POST /internal/transcode/claim`
  - body: `{"workerId":"..."}`
- `POST /internal/transcode/finish`
  - body: `{"jobId","status","errorMessage"?,"hlsMasterKey"?,"posterKey"?}`
- `POST /internal/transcode/assets`
  - body: `{"videoId", "durationSeconds"?, "width"?, "height"?, "sourceSizeBytes"?, "variants"?, "hlsMasterKey"?, "posterKey"?}`

## RPC API (параллельно с REST)

- `POST /api/v1/rpc/{function}`
- body: `{"args":[...]}`

Backend вызывает только whitelist функций из `buildFunctionRegistry()`.
Для части функций `user_id` принудительно инжектится из сессии.

## Примечания

- Бизнес-логика и ACL намеренно находятся в PostgreSQL.
- HTTP-слой отвечает за transport/auth/валидацию и orchestration.
- Более детальная рационализация контрактов: `backend/API.md`.
