# Backend API (REST + RPC) over Fat DB

Актуальный контракт backend API на основе реализации в `backend/cmd/api/main.go`.
Документ синхронизирован с `backend/README.md`.

## 1. Принципы

- Бизнес-логика и ACL вынесены в PostgreSQL функции (`backend/migrations/*`).
- HTTP backend отвечает за auth/session, transport-контракты, валидацию и orchestration вызовов SQL-функций.
- Идентификаторы сущностей: UUID.
- Пагинация:
  - cursor-based для follow/folders/comments/reactions/favorites,
  - `limit/offset` для части списков (videos/feed/purchases).

## 2. Security и middleware

### 2.1 Session token источники

Проверяются в таком порядке:

- `Authorization: Bearer <session_token>`
- `X-Session-Token: <session_token>`
- cookie `session_token`

### 2.2 CSRF

Для cookie-сессии mutating методов (`POST/PUT/PATCH/DELETE`) обязателен `X-CSRF-Token`, совпадающий со значением cookie `csrf_token`.

- Для token-based запросов (`Authorization` или `X-Session-Token`) CSRF-проверка пропускается.
- Для `/internal/*` CSRF не применяется.

### 2.3 CORS

`Origin` должен входить в `CORS_ALLOWED_ORIGINS`.

### 2.4 Rate limit

Per-IP limit на уровне middleware (`RATE_LIMIT_PER_MINUTE`).

- Не применяется к `OPTIONS`, `/healthz`, `/internal/*`.

### 2.5 Internal auth

Если задан `INTERNAL_API_TOKEN`, то internal-роуты требуют:

- `X-Internal-Token: <INTERNAL_API_TOKEN>`

## 3. Форматы ответов и ошибок

### 3.1 Ошибка (базовая)

```json
{"error":"message","ok":false}
```

### 3.2 Ошибка БД

```json
{"error":"database error","code":"...","message":"...","ok":false}
```

### 3.3 Базовые HTTP статусы

- `200`: успешный GET/POST/PUT/PATCH
- `201`: создан ресурс
- `204`: успешное удаление/logout без body
- `400`: invalid payload / DB business error
- `401`: unauthorized
- `403`: forbidden
- `404`: not found
- `409`: unique conflict (например `23505`)
- `429`: rate limit exceeded
- `500`: internal error

## 4. REST API

## 4.1 Health

### `GET /healthz`

- response: `200 {"status":"ok"}`

## 4.2 Auth

### `POST /auth/register`

- body: `{"email","username","password"}`
- ограничения: `password` минимум 6 символов
- response: `201 {"user": {...}}`
- side effects: выставляет cookies `session_token`, `csrf_token`

### `POST /auth/login`

- body: `{"login","password"}` (`login` = email или username)
- response: `200 {"user": {...}}`
- side effects: выставляет cookies `session_token`, `csrf_token`

### `POST /auth/logout`

- response: `204`
- side effects: чистит cookies `session_token`, `csrf_token`

### `GET /auth/me`
### `GET /api/me` (legacy alias)

- response: `200` с объектом пользователя напрямую:

```json
{
  "user_id":"...",
  "email":"...",
  "username":"...",
  "display_name":"...",
  "avatar_url":"...",
  "is_active":true
}
```

- response: `401` если сессия невалидна/отсутствует

## 4.3 Users / Follow

### `GET /users/{userId}`

- публичный профиль

### `POST /users/{userId}/follow` (auth)

- response: `200 {"following": <bool>}`

### `DELETE /users/{userId}/follow` (auth)

- response: `200 {"following": false, "deleted": <bool>}`

### `GET /me/following` (auth)

- query: `limit=50`, `cursorCreatedAt`, `cursorUserId`
- response: `200 {"items":[...]}`

### `GET /me/followers` (auth)

- query: `limit=50`, `cursorCreatedAt`, `cursorUserId`
- response: `200 {"items":[...]}`

## 4.4 Folders (auth)

### `GET /me/folders`

- query: `type=<required>`, `parentId`, `limit=50`, `cursorCreatedAt`, `cursorFolderId`
- response: `200 {"items":[...]}`

### `GET /me/folders/tree`

- query: `type=<required>`
- response: `200 {"items":[...]}`

### `POST /me/folders`

- body: `{"type","name","parentId"}`
- response: `201 {"folderId":"..."}`

### `GET /me/folders/{folderId}`

- response: `200 {...}`

### `PATCH /me/folders/{folderId}`

- body: `{"name"?,"parentId"?}` (минимум одно поле)
- response: `200 {"ok":true}`

### `DELETE /me/folders/{folderId}`

- response: `204`

### `GET /me/folders/{folderId}/videos`

- query: `limit=50`, `cursorOrderIndex`, `cursorAddedAt`, `cursorVideoId`
- response: `200 {"items":[...]}`

### `POST /me/folders/{folderId}/videos`

- body: `{"videoId","orderIndex"?}`
- response: `200 {"ok":true}`

### `DELETE /me/folders/{folderId}/videos/{videoId}`

- response: `204`

### `POST /me/folders/{folderId}/videos/{videoId}/move`

- body: `{"toFolderId","toOrderIndex"?}`
- response: `200 {"moved": <bool>}`

## 4.5 Videos

### `POST /videos/` (auth)

- body: `{"title","description"?,"visibility","folderIds"?}`
- response: `201 {"videoId":"..."}`

### `POST /videos/upload` (auth, multipart/form-data)

- fields:
  - `file` (required)
  - `title` (required)
  - `description` (optional)
  - `visibility` (optional, default `private`)
- лимит body: `UPLOAD_MAX_BYTES` (по умолчанию `512MB`)
- разрешённые расширения: `.mp4`, `.mov`, `.m4v`, `.webm`
- разрешённые MIME: `video/mp4`, `video/quicktime`, `video/webm`
- response: `201 {"videoId":"...","status":"processing"}`

### `GET /videos/{videoId}`

### `PATCH /videos/{videoId}` (auth)

- body: `{"title"?,"description"?,"visibility"?}`
- response: `200 {"ok":true}`

### `DELETE /videos/{videoId}` (auth)

- response: `204`

### `POST /videos/{videoId}/publish` (auth)

- response: `200 {"published": <bool>}`

### `POST /videos/{videoId}/unpublish` (auth)

- response: `200 {"unpublished": <bool>}`

### `GET /me/videos` (auth)

- query: `limit=50`, `offset=0`
- response: `200 {"items":[...]}`

### `GET /users/{userId}/videos`

- query: `limit=50`, `offset=0`
- response: `200 {"items":[...]}`

## 4.6 Playback / Stream

### `GET /videos/{videoId}/playback`

- response: `200`

```json
{
  "type":"hls",
  "manifestUrl":"/stream/hls/{videoId}/{master}.m3u8",
  "meta": {...}
}
```

### `GET /stream/hls/{videoId}/*`

- выдача HLS-манифестов и сегментов из `STORAGE_ROOT`
- доступ проверяется через DB (`video_get_hls_master_for_viewer`)

## 4.7 Reactions

### `PUT /videos/{videoId}/reaction` (auth)

- body: `{"value":"like|dislike|none"}`
- response: `200 {"ok":true}`

### `GET /videos/{videoId}/reaction`

- response: `200 {"myReaction":...,"likes":...,"dislikes":...}`

### `GET /videos/{videoId}/reactions`

- query: `value`, `limit=50`, `cursorCreatedAt`, `cursorUserId`
- response: `200 {"items":[...]}`

## 4.8 Comments

### `GET /videos/{videoId}/comments`

- query: `limit=50`, `cursorCreatedAt`, `cursorCommentId`
- response: `200 {"items":[...]}`

### `POST /videos/{videoId}/comments` (auth)

- body: `{"text":"..."}`
- response: `201 {"commentId":"..."}`

### `PATCH /videos/{videoId}/comments/{commentId}` (auth)

- body: `{"text":"..."}`
- response: `200 {"ok":true}`

### `DELETE /videos/{videoId}/comments/{commentId}` (auth)

- response: `204`

## 4.9 Favorites (auth)

### `GET /me/favorites`

- query: `folderId`, `limit=50`, `cursorAddedAt`, `cursorVideoId`
- response: `200 {"items":[...]}`

### `GET /me/favorites/all`

- query: `limit=50`, `cursorAddedAt`, `cursorVideoId`
- response: `200 {"items":[...]}`

### `PUT /me/favorites/{videoId}`

- body: `{"folderId"?,"orderIndex"?}`
- response: `200 {"saved":true,"folderId":"..."}`

### `DELETE /me/favorites/{videoId}`

- query: `folderId`
- response: `200 {"removedCount": <number>}`

### `GET /me/favorites/{videoId}`

- response: `200 {"saved": <bool>}`

## 4.10 Purchases / Download

### `POST /videos/{videoId}/purchase-download` (auth)

- body: `{"provider","providerPaymentId","amountCents","currency"}`
- response: `201 {"purchaseId":"..."}`
- note: при `provider="demo"` backend сразу переводит покупку в `paid`

### `GET /me/purchases` (auth)

- query: `status`, `limit=50`, `offset=0`
- response: `200 {"items":[...]}`

### `GET /me/purchases/{purchaseId}` (auth)

- response: `200 {...}`

### `POST /videos/{videoId}/download-token` (auth)

- body: `{"purchaseId"?,"ttl"?}`
- response: `200 {...}` (объект токена)

### `GET /videos/{videoId}/download` (auth)

- query:
  - `token` (optional one-time token)
  - `mode=file` (если нужен сразу файл)
- поведение:
  - без `mode=file` -> `200 {"sourceKey":"...","downloadUrl":"...","downloadMode":"file"}`
  - с `mode=file` -> file attachment

### `POST /purchases/{purchaseId}/status` (internal token)

- body: `{"status":"..."}`
- response: `200 {"ok":true}`

## 4.11 Feed

### `GET /feed/following` (auth)

- query: `limit=50`, `offset=0`
- response: `200 {"items":[...]}`

### `GET /feed/hot`

- query: `limit=50`, `offset=0`, `window=48 hours`
- response: `200 {"items":[...]}`

### `GET /feed`

- query: `limit=50`, `offset=0`, `window=48 hours`
- response: `200 {"items":[...]}`
- backend объединяет `following` + `hot` и добавляет поле `source`.

## 4.12 Internal transcoding

Все эндпоинты ниже требуют internal token (если `INTERNAL_API_TOKEN` задан).

### `POST /internal/transcode/enqueue`

- body: `{"videoId":"...","priority"?}`
- response: `200 {"jobId":"..."}`

### `POST /internal/transcode/claim`

- body: `{"workerId":"..."}`
- response:
  - `200 {"job": null}` если задач нет
  - `200 {"job": {...}}` если задача выдана

### `POST /internal/transcode/finish`

- body: `{"jobId","status","errorMessage"?,"hlsMasterKey"?,"posterKey"?}`
- response: `200 {"ok":true}`

### `POST /internal/transcode/assets`

- body: `{"videoId","durationSeconds"?,"width"?,"height"?,"sourceSizeBytes"?,"variants"?,"hlsMasterKey"?,"posterKey"?}`
- response: `200 {"ok":true}`

## 5. RPC API (coexists with REST)

### `POST /api/v1/rpc/{function}`

- body: `{"args":[...]}`
- backend вызывает только whitelist из `buildFunctionRegistry()`
- для части функций `user_id` инжектится сервером в заданный аргумент

## 6. References

- `backend/README.md`
- `backend/cmd/api/main.go`
- `backend/migrations/`
