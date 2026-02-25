#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT_DIR="$ROOT_DIR"
BACKEND_DIR="$PROJECT_DIR/backend"
MIGRATIONS_DIR="$BACKEND_DIR/migrations"

PG_BIN_DIR="${PG_BIN_DIR:-$HOME/ARENADATA/github/orioledb/output_bin/bin}"
PGDATA="${PGDATA:-/tmp/pgdata-demo}"
API_PORT="${API_PORT:-18084}"
STORAGE_ROOT="${STORAGE_ROOT:-/tmp/storage-e2e}"
INTERNAL_API_TOKEN="${INTERNAL_API_TOKEN:-test-internal-token}"
DATABASE_URL="${DATABASE_URL:-postgres://app@localhost:5432/app?sslmode=disable}"

export PATH="$PG_BIN_DIR:$PATH"
export DATABASE_URL

API_PID=""

cleanup() {
  set +e
  if [[ -n "$API_PID" ]] && kill -0 "$API_PID" >/dev/null 2>&1; then
    kill "$API_PID" >/dev/null 2>&1 || true
    wait "$API_PID" >/dev/null 2>&1 || true
  fi
  if [[ -f "$PGDATA/postmaster.pid" ]]; then
    pg_ctl -D "$PGDATA" stop -m fast >/tmp/pg-stop.log 2>&1 || true
  fi
  rm -rf "$PGDATA" "$STORAGE_ROOT"
}
trap cleanup EXIT

log() {
  printf "[e2e] %s\n" "$*"
}

fail() {
  printf "[e2e][FAIL] %s\n" "$*" >&2
  exit 1
}

json_field() {
  local key="$1"
  sed -n "s/.*\"$key\":\"\([^\"]*\)\".*/\1/p" | head -n1
}

request() {
  local method="$1"
  local url="$2"
  local body="${3:-}"
  shift 3 || true

  local tmp
  tmp="$(mktemp)"
  local status

  if [[ -n "$body" ]]; then
    status=$(curl -sS -o "$tmp" -w "%{http_code}" -X "$method" -H 'Content-Type: application/json' "$@" "$url" -d "$body")
  else
    status=$(curl -sS -o "$tmp" -w "%{http_code}" -X "$method" "$@" "$url")
  fi

  REQUEST_STATUS="$status"
  REQUEST_BODY="$(cat "$tmp")"
  rm -f "$tmp"
}

assert_status() {
  local expected="$1"
  local label="$2"
  if [[ "$REQUEST_STATUS" != "$expected" ]]; then
    printf "[e2e][FAIL] %s: expected HTTP %s, got %s\nBody: %s\n" "$label" "$expected" "$REQUEST_STATUS" "$REQUEST_BODY" >&2
    exit 1
  fi
  printf "[e2e][OK] %s -> HTTP %s\n" "$label" "$REQUEST_STATUS"
}

psql_uuid() {
  psql "$DATABASE_URL" -t -A -q -c "$1" | head -n1 | tr -d '[:space:]'
}

apply_migrations() {
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f "$PROJECT_DIR/$f" >/tmp/pg-migrate-last.log 2>&1
  done <<'MIGS'
backend/migrations/00_extensions.sql
backend/migrations/01_enums.sql
backend/migrations/10_users.sql
backend/migrations/11_sessions.sql
backend/migrations/20_follows.sql
backend/migrations/21_follow_functions.sql
backend/migrations/22_follow_reads.sql
backend/migrations/23_follow_reads_indexes.sql
backend/migrations/30_folders.sql
backend/migrations/40_videos.sql
backend/migrations/41_folder_video_items.sql
backend/migrations/42_transcoding_jobs.sql
backend/migrations/43_video_assets.sql
backend/migrations/50_reactions.sql
backend/migrations/60_comments.sql
backend/migrations/70_views.sql
backend/migrations/80_purchases.sql
backend/migrations/81_download_tokens.sql
backend/migrations/90_feed.sql
backend/migrations/100_auth_functions.sql
backend/migrations/101_video_access_functions.sql
backend/migrations/102_video_core_functions.sql
backend/migrations/110_folder_functions.sql
backend/migrations/111_folder_reads.sql
backend/migrations/112_folder_reads_indexes.sql
backend/migrations/120_social_functions.sql
backend/migrations/121_social_reads.sql
backend/migrations/122_social_reads_indexes.sql
backend/migrations/130_purchases_functions.sql
backend/migrations/131_download_tokens_maintenance.sql
backend/migrations/140_transcoding_functions.sql
backend/migrations/150_feed_functions.sql
backend/migrations/160_folder_write_functions.sql
backend/migrations/161_favorites_functions.sql
backend/migrations/162_video_library_functions.sql
backend/migrations/163_transcoding_assets_functions.sql
backend/migrations/164_social_write_extras.sql
backend/migrations/165_feed_hot_functions.sql
backend/migrations/166_video_stream_access_functions.sql
backend/migrations/167_additional_read_functions.sql
backend/migrations/168_favorites_list_all.sql
MIGS
}

start_postgres() {
  rm -rf "$PGDATA"
  initdb -D "$PGDATA" --encoding=UTF8 --locale=C.UTF-8 >/tmp/pg-initdb.log 2>&1
  pg_ctl -D "$PGDATA" -l "$PGDATA/server.log" start >/tmp/pg-start.log 2>&1
  createuser -h localhost -p 5432 app
  createdb -h localhost -p 5432 -O app app
}

start_backend() {
  rm -rf "$STORAGE_ROOT"
  mkdir -p "$STORAGE_ROOT"

  (
    cd "$BACKEND_DIR"
    PORT="$API_PORT" \
    DATABASE_URL="$DATABASE_URL" \
    STORAGE_ROOT="$STORAGE_ROOT" \
    INTERNAL_API_TOKEN="$INTERNAL_API_TOKEN" \
    GOCACHE=/tmp/go-build GOPATH=/tmp/go \
    go run ./cmd/api >/tmp/backend-e2e.log 2>&1
  ) &
  API_PID="$!"

  for _ in $(seq 1 60); do
    if curl -sS "http://127.0.0.1:$API_PORT/healthz" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.2
  done
  fail "backend did not start in time"
}

log "starting postgres"
start_postgres

log "applying migrations"
apply_migrations

log "starting backend"
start_backend

BASE="http://127.0.0.1:$API_PORT"
CJ1="$(mktemp)"
CJ2="$(mktemp)"
trap 'rm -f "$CJ1" "$CJ2"; cleanup' EXIT

log "auth register/login flow"
request POST "$BASE/auth/register" '{"email":"a@a.com","username":"alice","password":"secret12"}' -c "$CJ1"
assert_status 201 "register alice"
ALICE_ID="$(printf '%s' "$REQUEST_BODY" | json_field user_id)"

request POST "$BASE/auth/register" '{"email":"b@b.com","username":"bob","password":"secret12"}' -c "$CJ2"
assert_status 201 "register bob"
BOB_ID="$(printf '%s' "$REQUEST_BODY" | json_field user_id)"

request GET "$BASE/auth/me" '' -b "$CJ1"
assert_status 200 "auth me alice"

log "follow"
request POST "$BASE/users/$ALICE_ID/follow" '' -b "$CJ2"
assert_status 200 "bob follows alice"

log "create and publish video"
request POST "$BASE/me/folders" '{"type":"library","name":"lib","parentId":null}' -b "$CJ1"
assert_status 201 "create alice library folder"
LIB_ID="$(printf '%s' "$REQUEST_BODY" | json_field folderId)"

request POST "$BASE/videos" "{\"title\":\"demo\",\"visibility\":\"public\",\"folderIds\":[\"$LIB_ID\"]}" -b "$CJ1"
assert_status 201 "create video"
VIDEO_ID="$(printf '%s' "$REQUEST_BODY" | json_field videoId)"

mkdir -p "$STORAGE_ROOT/videos/$VIDEO_ID"
echo '#EXTM3U' > "$STORAGE_ROOT/videos/$VIDEO_ID/master.m3u8"

request POST "$BASE/api/v1/rpc/transcode_finalize_video" "{\"args\":[\"$VIDEO_ID\",\"videos/$VIDEO_ID/master.m3u8\",\"videos/$VIDEO_ID/poster.jpg\",10,1280,720]}" -b "$CJ1"
assert_status 200 "transcode finalize"

request POST "$BASE/videos/$VIDEO_ID/publish" '' -b "$CJ1"
assert_status 200 "publish video"

log "regression #1: favorites put/list consistency"
request POST "$BASE/me/folders" '{"type":"favorites","name":"custom-root","parentId":null}' -b "$CJ2"
assert_status 201 "create bob custom favorites root"

request PUT "$BASE/me/favorites/$VIDEO_ID" '{}' -b "$CJ2"
assert_status 200 "put favorite"

request GET "$BASE/me/favorites" '' -b "$CJ2"
assert_status 200 "list favorites"
printf '%s' "$REQUEST_BODY" | grep -q "$VIDEO_ID" || fail "favorites list does not contain video $VIDEO_ID"

log "regression #2: download_token_issue ambiguity"
request POST "$BASE/videos/$VIDEO_ID/purchase-download" '{"provider":"stripe","providerPaymentId":"pi1","amountCents":100,"currency":"USD"}' -b "$CJ2"
assert_status 201 "create purchase"
PURCHASE_ID="$(printf '%s' "$REQUEST_BODY" | json_field purchaseId)"

request POST "$BASE/api/v1/rpc/purchase_set_status" "{\"args\":[\"$PURCHASE_ID\",\"paid\"]}" -b "$CJ2"
assert_status 200 "set purchase paid"

request POST "$BASE/videos/$VIDEO_ID/download-token" "{\"purchaseId\":\"$PURCHASE_ID\",\"ttl\":\"15 minutes\"}" -b "$CJ2"
assert_status 200 "issue download token"
printf '%s' "$REQUEST_BODY" | grep -q '"token"' || fail "download token response has no token"

log "regression #3: enqueue after publish"
request POST "$BASE/internal/transcode/enqueue" "{\"videoId\":\"$VIDEO_ID\",\"priority\":10}" -H "X-Internal-Token: $INTERNAL_API_TOKEN"
assert_status 200 "internal enqueue after publish"

log "playback/stream sanity"
request GET "$BASE/videos/$VIDEO_ID/playback" '' -b "$CJ2"
assert_status 200 "playback endpoint"
request GET "$BASE/stream/hls/$VIDEO_ID/master.m3u8" '' -b "$CJ2"
assert_status 200 "stream endpoint"

log "ALL TESTS PASSED"
