# Fat DB: Technical Overview

## 1. Scope

`backend/migrations/` defines a PostgreSQL-first backend (Fat DB):

- Data model and integrity constraints in DDL.
- Access-control predicates in SQL functions.
- Business operations as stored procedures (`CREATE OR REPLACE FUNCTION`).
- Read APIs as SQL functions with pagination/cursors.

The application layer is expected to call DB functions as the primary business API.

## 2. Migration Map

### 2.1 Foundation

- `00_extensions.sql`: `pgcrypto`, `citext`.
- `01_enums.sql`: `video_visibility`, `video_status`, `folder_tree_type`, `reaction_value`, `purchase_status`.

### 2.2 Core tables

- `10_users.sql`, `11_sessions.sql`
- `20_follows.sql`
- `30_folders.sql`
- `40_videos.sql`
- `41_folder_video_items.sql`
- `42_transcoding_jobs.sql`
- `43_video_assets.sql`
- `50_reactions.sql`
- `60_comments.sql`
- `70_views.sql`
- `80_purchases.sql`
- `81_download_tokens.sql`
- `90_feed.sql`

### 2.3 Function layers

- Auth: `100_auth_functions.sql`
- Video access: `101_video_access_functions.sql`
- Video core: `102_video_core_functions.sql`
- Folder writes/reads: `110_folder_functions.sql`, `111_folder_reads.sql`, `112_folder_reads_indexes.sql`, `160_folder_write_functions.sql`
- Follow writes/reads: `21_follow_functions.sql`, `22_follow_reads.sql`, `23_follow_reads_indexes.sql`
- Social writes/reads: `120_social_functions.sql`, `121_social_reads.sql`, `122_social_reads_indexes.sql`, `164_social_write_extras.sql`
- Purchases/tokens: `130_purchases_functions.sql`, `131_download_tokens_maintenance.sql`
- Transcoding: `140_transcoding_functions.sql`, `163_transcoding_assets_functions.sql`
- Feed: `150_feed_functions.sql`, `165_feed_hot_functions.sql`
- Favorites helpers: `161_favorites_functions.sql`
- Library wrappers: `162_video_library_functions.sql`
- Stream/download helpers: `166_video_stream_access_functions.sql`
- Favorites aggregated read: `168_favorites_list_all.sql`

## 3. Data Model and Invariants

### 3.1 Users and sessions

- `users`: unique `email`, `username` (case-insensitive via `citext`).
- `user_sessions`: only hashed tokens stored (`session_token_hash`), with expiry control.

### 3.2 Follow graph

- `user_follows(follower_id, following_id)` PK.
- `CHECK (follower_id <> following_id)` prevents self-follow.

### 3.3 Folder trees

- `folders`: owned hierarchy with `tree_type in ('library','favorites')`.
- Name uniqueness scoped by `(owner_id, tree_type, parent_id, name)`.
- Trigger `trg_folders_validate_parent_integrity` enforces parent owner/tree consistency.
- `folder_video_items`: M:N placement of videos in folders + optional `order_index`.

### 3.4 Videos

- `videos` tracks source, HLS keys, metadata, denormalized counters.
- Visibility: `public/private/protected`.
- Status lifecycle: `uploading -> processing -> ready/failed` (+ `deleted`).
- `published_at` is constrained to ready/non-private states.

### 3.5 Social

- `video_reactions`: one reaction per `(video_id, user_id)`.
- `video_comments`: soft delete via `is_deleted`.
- `video_views`: append-only view events.

### 3.6 Downloads and purchases

- `download_purchases`: purchase attempts with status machine (`pending/paid/...`).
- `video_download_tokens`: one-time token with hash storage, expiry, revocation.
- Partial unique index ensures one active token per `purchase_id`.

### 3.7 Feed and transcoding

- `feed_events`: event log (currently publication events).
- `video_transcode_jobs`: queue/claim/finish workflow with one active job per video.
- `video_hls_variants`: parsed HLS renditions.

## 4. Access Control Model

Central predicates:

- `can_view_video(viewer_id, video_id)`
- `can_download_video(user_id, video_id)`

Implemented semantics:

- View:
  - Owner: all non-deleted videos.
  - Others: only `status='ready'`, `published_at IS NOT NULL`.
  - `public`: everyone.
  - `protected`: only follower of owner.
  - `private`: owner only.

- Download:
  - Owner: own non-deleted video.
  - Others: must both
    - have view access now (`can_view_video = true`), and
    - have `paid` purchase record.

These predicates are reused by read/write functions for consistent policy.

## 5. Function Modules

### 5.1 Auth

- `auth_create_session`, `auth_delete_session`, `auth_get_user_by_session`, `auth_cleanup_expired_sessions`.

### 5.2 Follows

Writes:

- `follow_create`, `follow_delete`.

Reads:

- `follow_is_following`, `follow_list_following`, `follow_list_followers`.

### 5.3 Videos (core)

- `video_create`, `video_update_metadata`, `video_publish`, `video_unpublish`, `video_delete`.
- `video_get`, `video_list_public_feed`, `video_list_owner`, `video_list_user_visible`.

### 5.4 Library/Folders

Base writes:

- `folder_create`, `folder_add_video`.
- `folder_rename`, `folder_move`, `folder_delete`.
- `folder_remove_video`, `folder_set_video_order`, `folder_move_video`.

Reads:

- `folder_get`, `folder_list_children`, `folder_list_videos`.

Library wrappers:

- `video_create_in_library`, `video_place_in_library_folder`, `video_move_between_library_folders`.

### 5.5 Favorites

- `favorites_get_or_create_root`
- `favorites_add_video`, `favorites_remove_video`, `favorites_move_video`
- `favorites_is_video_saved`, `favorites_list_videos`
- `favorites_list_all`

### 5.6 Social

Writes:

- `video_set_reaction`, `video_remove_reaction`
- `video_add_comment`, `video_update_comment`, `video_delete_comment`
- `video_record_view`

Reads:

- `video_get_user_reaction`
- `video_list_reactions`
- `video_list_comments`, `video_get_comment`
- `video_list_views`
- `video_get_social_summary`

### 5.7 Purchases and download tokens

- `purchase_create`, `purchase_set_status`
- `download_token_issue`, `download_token_consume`
- `download_tokens_cleanup_expired`

### 5.8 Transcoding and HLS assets

Queue control:

- `transcode_enqueue`, `transcode_claim_next`, `transcode_finish`

Assets/metadata:

- `transcode_set_video_media_info`
- `transcode_add_hls_variant`, `transcode_replace_hls_variants`
- `transcode_finalize_video`

Stream/read helpers:

- `video_get_hls_master_for_viewer`
- `video_list_hls_variants_for_viewer`
- `video_get_download_source_for_user`

### 5.9 Feed

- `feed_video_published`
- `feed_following`
- `feed_hot` (weighted score from views/likes/comments in rolling window + recency bonus)

## 6. Pagination and Read Patterns

Used patterns:

- Keyset pagination with tuple-like ordering in most read-heavy lists.
- Offset pagination for simple feed endpoints (`feed_following`, `feed_hot`, public feed helper).
- Dedicated composite indexes for keyset tie-breakers.

## 7. Typical End-to-End Flows

### 7.1 Upload and publish

1. `video_create[_in_library]`
2. `transcode_enqueue`
3. Worker: `transcode_claim_next`
4. Worker writes outputs: `transcode_set_video_media_info`, `transcode_replace_hls_variants`, `transcode_finalize_video`
5. `video_publish`

### 7.2 Playback

1. Resolve card/details: `video_get`
2. Resolve HLS master/variants: `video_get_hls_master_for_viewer`, `video_list_hls_variants_for_viewer`
3. Track watch: `video_record_view`

### 7.3 Social interaction

- Reaction set/remove: `video_set_reaction` / `video_remove_reaction`
- Comment add/edit/delete: `video_add_comment`, `video_update_comment`, `video_delete_comment`

### 7.4 Favorites

- Add: `favorites_add_video`
- Remove: `favorites_remove_video`
- Move: `favorites_move_video`
- Read: `favorites_list_videos`
- Read (aggregated across whole favorites tree): `favorites_list_all`

### 7.5 Paid download

1. `purchase_create` -> pending
2. Payment webhook/service -> `purchase_set_status(..., 'paid')`
3. `download_token_issue`
4. `download_token_consume` -> resolve `video_id`
5. `video_get_download_source_for_user` (or service-side source resolution)

## 8. Operational Notes

- Migrations are idempotent-friendly (`IF NOT EXISTS`, `CREATE OR REPLACE`).
- Business constraints are mostly fail-fast via `RAISE EXCEPTION` with explicit messages.
- Denormalized counters (`views_count`, `likes_count`, `comments_count`) are maintained in write functions.
- Some feed APIs use offset pagination; if datasets grow significantly, consider keyset variants.
