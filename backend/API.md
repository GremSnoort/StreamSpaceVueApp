# Backend API (MVP) over Fat DB

Этот документ задает рациональный REST-контракт поверх текущей схемы `backend/migrations/*`.

## 1. Базовые принципы

- Бизнес-логика и ACL живут в PostgreSQL функциях.
- Backend слой: auth/cookie, HTTP-контракты, orchestration нескольких SQL-функций, формат ответов.
- Все id: UUID.
- Пагинация: cursor-based там, где уже есть keyset-функции в БД; иначе `limit/offset`.

## 2. Auth

## POST `/auth/register`

Создать пользователя + сессию.

- body: `{ "email": "...", "username": "...", "password": "..." }`
- response 201: `{ "user": {...} }`
- set-cookie: `session_token` (httpOnly)

DB:

- `INSERT INTO users ...`
- `auth_create_session(user_id, user_agent, ip)`

Notes:

- Проверка пароля делается в backend (hashing).

## POST `/auth/login`

- body: `{ "login": "email_or_username", "password": "..." }`
- response 200: `{ "user": {...} }`
- set-cookie: `session_token`

DB:

- `SELECT users...` + проверка hash в backend
- `auth_create_session(...)`

## POST `/auth/logout`

- response 204

DB:

- `auth_delete_session(session_token)`

## GET `/auth/me`

- response 200: `{ "user": {...} }`
- response 401 если нет валидной сессии

DB:

- `auth_get_user_by_session(session_token)`

## 3. Users / Follow

## GET `/users/{userId}`

Публичный профиль пользователя.

- response 200: `{ "id", "username", "displayName", "avatarUrl", "bio", "followersCount", "followingCount", "isFollowing" }`

DB:

- `user_get_profile(meOrNull, userId)`

## POST `/users/{userId}/follow`

- response 200: `{ "following": true }`

DB:

- `follow_create(me, userId)`

## DELETE `/users/{userId}/follow`

- response 200: `{ "following": false }`

DB:

- `follow_delete(me, userId)`

## GET `/me/following`

- query: `limit`, `cursorCreatedAt`, `cursorUserId`

DB:

- `follow_list_following(me, ...)`

## GET `/me/followers`

- query: `limit`, `cursorCreatedAt`, `cursorUserId`

DB:

- `follow_list_followers(me, ...)`

## 4. Folders

## GET `/me/folders`

- query: `type=library|favorites`, `parentId`, `limit`, `cursorCreatedAt`, `cursorFolderId`

DB:

- `folder_list_children(me, type, parentId, ...)`

## GET `/me/folders/tree`

- query: `type=library|favorites`

DB:

- `folder_list_tree(me, type)`

## GET `/me/folders/{folderId}`

DB:

- `folder_get(folderId, me)`

## POST `/me/folders`

- body: `{ "type": "library|favorites", "name": "...", "parentId": null|uuid }`

DB:

- `folder_create(me, type, parentId, name)`

## PATCH `/me/folders/{folderId}`

- body: `{ "name"?: "...", "parentId"?: null|uuid }`

DB orchestration:

- если `name` передан: `folder_rename(folderId, me, name)`
- если `parentId` передан: `folder_move(folderId, me, parentId)`

## DELETE `/me/folders/{folderId}`

DB:

- `folder_delete(folderId, me)`

## GET `/me/folders/{folderId}/videos`

- query: `limit`, `cursorOrderIndex`, `cursorAddedAt`, `cursorVideoId`

DB:

- `folder_list_videos(folderId, me, ...)`

## POST `/me/folders/{folderId}/videos`

- body: `{ "videoId": "...", "orderIndex"?: int }`

DB:

- `folder_add_video(folderId, videoId, me, orderIndex)`

## DELETE `/me/folders/{folderId}/videos/{videoId}`

DB:

- `folder_remove_video(folderId, videoId, me)`

## POST `/me/folders/{folderId}/videos/{videoId}/move`

- body: `{ "toFolderId": "...", "toOrderIndex"?: int }`

DB:

- `folder_move_video(folderId, toFolderId, videoId, me, toOrderIndex)`

## 5. Videos

## POST `/videos`

Создать карточку видео (MVP upload init).

- body: `{ "title", "description"?, "visibility", "folderIds"?: [uuid] }`
- response 201: `{ "videoId": "..." }`

DB orchestration:

- `video_create(me, title, description, visibility, ...)`
- для каждого `folderId`: `folder_add_video(folderId, videoId, me, null)`

## GET `/videos/{videoId}`

DB:

- `video_get(meOrNull, videoId)`

## PATCH `/videos/{videoId}`

- body: `{ "title"?, "description"?, "visibility"? }`

DB:

- `video_update_metadata(me, videoId, ...)`

## POST `/videos/{videoId}/publish`

DB:

- `video_publish(me, videoId)`

## POST `/videos/{videoId}/unpublish`

DB:

- `video_unpublish(me, videoId)`

## DELETE `/videos/{videoId}`

DB:

- `video_delete(me, videoId)`

## GET `/me/videos`

- query: `limit`, `offset`

DB:

- `video_list_owner(me, limit, offset)`

## GET `/users/{userId}/videos`

- query: `limit`, `offset`

DB:

- `video_list_user_visible(meOrNull, userId, limit, offset)`

## 6. Playback / HLS

## GET `/videos/{videoId}/playback`

- response 200: `{ "type": "hls", "manifestUrl": "/stream/hls/{videoId}/master.m3u8" }`

DB:

- `video_get_hls_master_for_viewer(meOrNull, videoId)`

## GET `/stream/hls/{videoId}/master.m3u8`

## GET `/stream/hls/{videoId}/variant/{name}.m3u8`

## GET `/stream/hls/{videoId}/segments/{name}.ts`

Proxy слой backend со storage reads.

DB checks:

- `can_view_video(meOrNull, videoId)`
- `video_get_hls_master_for_viewer(...)`
- `video_list_hls_variants_for_viewer(...)`

## 7. Reactions

## PUT `/videos/{videoId}/reaction`

- body: `{ "value": "like|dislike|none" }`

DB:

- `like|dislike` -> `video_set_reaction(videoId, me, value)`
- `none` -> `video_remove_reaction(videoId, me)`

## GET `/videos/{videoId}/reaction`

DB:

- `video_get_user_reaction(videoId, me)`
- `video_get_social_summary(videoId, meOrNull)`

## GET `/videos/{videoId}/reactions`

- query: `value?`, `limit`, `cursorCreatedAt`, `cursorUserId`

DB:

- `video_list_reactions(videoId, meOrNull, value, ...)`

## 8. Comments

## GET `/videos/{videoId}/comments`

- query: `limit`, `cursorCreatedAt`, `cursorCommentId`

DB:

- `video_list_comments(videoId, meOrNull, false, ...)`

## POST `/videos/{videoId}/comments`

- body: `{ "text": "..." }`

DB:

- `video_add_comment(videoId, me, text)`

## PATCH `/videos/{videoId}/comments/{commentId}`

- body: `{ "text": "..." }`

DB:

- `video_update_comment(commentId, me, text)`

## DELETE `/videos/{videoId}/comments/{commentId}`

DB:

- `video_delete_comment(commentId, me)`

## 9. Favorites shortcuts

## GET `/me/favorites`

- query: `folderId?`, `limit`, `cursorAddedAt`, `cursorVideoId`

DB:

- если `folderId` есть: `folder_list_videos(folderId, me, ...)`
- иначе: `favorites_list_videos(me, ...)`

## GET `/me/favorites/all`

- query: `limit`, `cursorAddedAt`, `cursorVideoId`
- purpose: единый список favorites по всему дереву favorites (без N вызовов по папкам)

DB:

- `favorites_list_all(me, limit, cursorAddedAt, cursorVideoId)`

## PUT `/me/favorites/{videoId}`

- body: `{ "folderId"?: uuid, "orderIndex"?: int }`

DB:

- `favorites_add_video(me, videoId, folderIdOrNull, orderIndex)`

## DELETE `/me/favorites/{videoId}`

- query: `folderId?`

DB:

- `favorites_remove_video(me, videoId, folderIdOrNull)`

## GET `/me/favorites/{videoId}`

DB:

- `favorites_is_video_saved(me, videoId)`

## 10. Purchases / Downloads

## POST `/videos/{videoId}/purchase-download`

- body: `{ "provider": "stripe", "providerPaymentId": "...", "amountCents": 100, "currency": "USD" }`
- note: для локального smoke/demo можно передать `provider: "demo"`; backend сразу ставит покупку в `paid`.

DB:

- `purchase_create(me, videoId, amountCents, currency, provider, providerPaymentId)`

## GET `/me/purchases`

- query: `status?`, `limit`, `offset`

DB:

- `purchase_list_my(me, statusOrNull, limit, offset)`

## GET `/me/purchases/{purchaseId}`

DB:

- `purchase_get(me, purchaseId)`

## POST `/purchases/{purchaseId}/status`

(обычно webhook/internal)

- body: `{ "status": "pending|paid|failed|refunded|canceled" }`

DB:

- `purchase_set_status(purchaseId, status)`

## POST `/videos/{videoId}/download-token`

- body: `{ "purchaseId"?: uuid, "ttl"?: "15 minutes" }`

DB:

- `download_token_issue(me, videoId, purchaseIdOrNull, ttl)`

## GET `/videos/{videoId}/download`

- query:
  - `token=...` (one-time flow)
  - `mode=file` (вернуть файл как attachment; без `mode=file` возвращается JSON c `sourceKey`)

DB orchestration:

- `download_token_consume(token)`
- `video_get_download_source_for_user(me, videoId)`

## 11. Feed

## GET `/feed/following`

- query: `limit`, `offset`

DB:

- `feed_following(me, limit, offset)`

## GET `/feed/hot`

- query: `limit`, `offset`, `window` (например `48 hours`)

DB:

- `feed_hot(meOrNull, limit, offset, window)`

## GET `/feed`

Комбинированная лента.

Backend orchestration:

- `feed_following(...)`
- `feed_hot(...)`
- merge/interleave policy в приложении

## 12. Internal (worker/transcoding)

## POST `/internal/transcode/enqueue`

- body: `{ "videoId": "...", "priority"?: 100 }`

DB:

- `transcode_enqueue(videoId, priority)`

## POST `/internal/transcode/claim`

- body: `{ "workerId": "..." }`

DB:

- `transcode_claim_next(workerId)`

## POST `/internal/transcode/finish`

- body: `{ "jobId", "status", "errorMessage"?, "hlsMasterKey"?, "posterKey"? }`

DB:

- `transcode_finish(...)`

## POST `/internal/transcode/assets`

- body: `{ "videoId", "durationSeconds"?, "width"?, "height"?, "variants"?: [...] }`

DB orchestration:

- `transcode_set_video_media_info(...)`
- `transcode_replace_hls_variants(...)` или `transcode_add_hls_variant(...)`
- `transcode_finalize_video(...)` когда master готов

## 13. Error model

- `400`: invalid payload / DB business error (`RAISE EXCEPTION`)
- `401`: missing/invalid session
- `403`: forbidden by policy
- `404`: not found
- `409`: conflict (optional mapping from DB unique violations)
- `500`: unexpected error
