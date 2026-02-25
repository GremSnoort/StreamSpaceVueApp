# StreamSpace Backend (Go + Fat DB)

This service is a thin HTTP API over PostgreSQL functions from `backend/migrations/`.

## Runtime

- Go 1.22+
- PostgreSQL with all migrations applied

## Configuration

- `DATABASE_URL` (default: `postgres://app@localhost:5432/app?sslmode=disable`)
- `PORT` (default: `8080`)
- `CORS_ALLOWED_ORIGINS` (default: `http://localhost:5173,http://127.0.0.1:5173`)
- `COOKIE_SECURE` (default: `false`)
- `RATE_LIMIT_PER_MINUTE` (default: `240`)
- `UPLOAD_MAX_BYTES` (default: `536870912`, i.e. `512MB`)
- `STORAGE_ROOT` (default: `../uploads`)
- `TRANSCODE_WORKER_ENABLED` (default: `true`)
- `TRANSCODE_WORKER_ID` (default: `api-worker-1`)
- `FFMPEG_BIN` (default: `ffmpeg`)
- `FFPROBE_BIN` (default: `ffprobe`)
- `INTERNAL_API_TOKEN` (optional, protects `/internal/*`)

## Database setup

Apply migrations before starting backend.

Use:

- `backend/migrations/README.md` for full migration order and local PostgreSQL bootstrap.

## Run

```bash
cd backend
go run ./cmd/api
```

## API

### Health

- `GET /healthz`

### Auth / Session

- `GET /auth/me`
- `GET /api/me` (legacy alias)

Auth token sources:

- `Authorization: Bearer <session_token>`
- `X-Session-Token: <session_token>`
- cookie `session_token`

For browser cookie sessions, mutating methods also require CSRF header:

- Header: `X-CSRF-Token`
- Cookie: `csrf_token`

### Universal Fat DB RPC

- `POST /api/v1/rpc/{function}`
- Body: `{"args": [ ... ]}`

The backend exposes a whitelist of DB functions and executes them with policy checks.

#### Important behavior

- For protected functions, auth is required.
- For many functions, caller `user_id` is injected server-side into specific argument positions.
  Client-supplied value at that position is ignored.

#### Example: create follow

```bash
curl -X POST \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer <session_token>' \
  localhost:8080/api/v1/rpc/follow_create \
  -d '{"args": [null, "1e11631a-8b8a-4d2c-8917-9a2d8896d13f"]}'
```

#### Example: list hot feed (guest)

```bash
curl -X POST \
  -H 'Content-Type: application/json' \
  localhost:8080/api/v1/rpc/feed_hot \
  -d '{"args": [null, 20, 0, "48 hours"]}'
```

#### Example: add comment

```bash
curl -X POST \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer <session_token>' \
  localhost:8080/api/v1/rpc/video_add_comment \
  -d '{"args": ["<video_uuid>", null, "great video"]}'
```

## Notes

- Service intentionally keeps business logic in DB functions (Fat DB).
- HTTP layer is transport/auth/validation glue.
- Function whitelist is in `cmd/api/main.go` (`buildFunctionRegistry`).

### REST (coexists with RPC)

Implemented first wave:

- `GET /users/{userId}`
- `POST|DELETE /users/{userId}/follow`
- `GET /me/following`
- `GET /me/followers`
- `GET|POST /me/folders`
- `GET /me/folders/tree`
- `GET|PATCH|DELETE /me/folders/{folderId}`
- `GET|POST /me/folders/{folderId}/videos`
- `DELETE /me/folders/{folderId}/videos/{videoId}`
- `POST /me/folders/{folderId}/videos/{videoId}/move`
- `GET /me/favorites/all`
- `POST /videos`
- `POST /videos/upload`
- `GET|PATCH|DELETE /videos/{videoId}`
- `POST /videos/{videoId}/publish`
- `POST /videos/{videoId}/unpublish`
- `GET /videos/{videoId}/playback`
- `GET /videos/{videoId}/download`
- `GET /me/videos`
- `GET /users/{userId}/videos`
- `GET|PUT /videos/{videoId}/reaction`
- `GET|POST /videos/{videoId}/comments`
- `PATCH|DELETE /videos/{videoId}/comments/{commentId}`
- `GET /me/favorites`
- `PUT|DELETE /me/favorites/{videoId}`
- `GET /me/favorites/{videoId}`
- `POST /videos/{videoId}/purchase-download`
- `GET /me/purchases`
- `GET /me/purchases/{purchaseId}`
- `POST /videos/{videoId}/download-token`
- `GET /feed/following`
- `GET /feed/hot`
- `GET /feed`
