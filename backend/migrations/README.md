# Smoke test Migrations

```bash
export DATABASE_URL="postgres://app:app@localhost:5432/app?sslmode=disable"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f backend/migrations/00_extensions.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f backend/migrations/01_enums.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f backend/migrations/10_users.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f backend/migrations/11_sessions.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f backend/migrations/20_follows.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f backend/migrations/21_follow_functions.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f backend/migrations/22_follow_reads.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f backend/migrations/23_follow_reads_indexes.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f backend/migrations/30_folders.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f backend/migrations/40_videos.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f backend/migrations/41_folder_video_items.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f backend/migrations/42_transcoding_jobs.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f backend/migrations/43_video_assets.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f backend/migrations/50_reactions.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f backend/migrations/60_comments.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f backend/migrations/70_views.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f backend/migrations/80_purchases.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f backend/migrations/81_download_tokens.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f backend/migrations/90_feed.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f backend/migrations/100_auth_functions.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f backend/migrations/101_video_access_functions.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f backend/migrations/102_video_core_functions.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f backend/migrations/110_folder_functions.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f backend/migrations/111_folder_reads.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f backend/migrations/112_folder_reads_indexes.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f backend/migrations/120_social_functions.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f backend/migrations/121_social_reads.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f backend/migrations/122_social_reads_indexes.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f backend/migrations/130_purchases_functions.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f backend/migrations/131_download_tokens_maintenance.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f backend/migrations/140_transcoding_functions.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f backend/migrations/150_feed_functions.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f backend/migrations/160_folder_write_functions.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f backend/migrations/161_favorites_functions.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f backend/migrations/162_video_library_functions.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f backend/migrations/163_transcoding_assets_functions.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f backend/migrations/164_social_write_extras.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f backend/migrations/165_feed_hot_functions.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f backend/migrations/166_video_stream_access_functions.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f backend/migrations/167_additional_read_functions.sql
```

```bash
while IFS= read -r line; do echo "=====================================> cat $line"; cat backend/migrations/$line; done <<< $(ls -la backend/migrations/ | awk '{print $9}')
```
