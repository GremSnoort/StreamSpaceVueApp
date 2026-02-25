<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import http from '../../lib/http'
import videosService from '../../services/videosService'
import foldersService from '../../services/foldersService'
import usersService from '../../services/usersService'

const router = useRouter()

const loading = ref(true)
const errorText = ref('')

const myVideos = ref([])
const favoriteItems = ref([])
const favoritesTree = ref([])
const following = ref([])
const followers = ref([])
const purchases = ref([])

const apiBase = (import.meta.env.VITE_API_BASE || 'http://localhost:8080').replace(/\/+$/, '')
const fallbackPoster = 'https://placehold.co/640x360?text=No+Poster'

const videoSummary = computed(() => {
  const list = myVideos.value
  return {
    total: list.length,
    ready: list.filter((v) => v.status === 'ready').length,
    processing: list.filter((v) => v.status === 'processing' || v.status === 'uploading').length,
    failed: list.filter((v) => v.status === 'failed').length,
    published: list.filter((v) => !!v.published_at).length,
    privateCount: list.filter((v) => v.visibility === 'private').length,
    protectedCount: list.filter((v) => v.visibility === 'protected').length,
    publicCount: list.filter((v) => v.visibility === 'public').length
  }
})

const favoritesSummary = computed(() => {
  const unique = new Set(
    favoriteItems.value
      .map((v) => String(v.video_id || v.id || '').trim())
      .filter(Boolean)
  )
  return {
    folders: favoritesTree.value.length,
    items: unique.size,
    withVideos: favoritesTree.value.filter((f) => Number(f.videos_count || 0) > 0).length
  }
})

const recentUploads = computed(() => myVideos.value.slice(0, 8))
const recentFavorites = computed(() => favoriteItems.value.slice(0, 6))
const recentPurchases = computed(() => purchases.value.slice(0, 8))

function posterUrl(video) {
  const key = video?.poster_key
  const id = video?.id || video?.video_id
  if (!key || !id) return fallbackPoster
  if (String(key).startsWith('http')) return key
  const name = String(key).split('/').pop()
  return `${apiBase}/stream/hls/${id}/${name}`
}

function goPlay(videoId) {
  router.push({ name: 'player', params: { id: videoId } })
}

async function loadOverview() {
  loading.value = true
  errorText.value = ''
  try {
    const [videos, favAllRes, favTree, fwing, fwers, purchasesRes] = await Promise.all([
      videosService.listMyVideos(300, 0),
      http.get('/me/favorites/all', { params: { limit: 300 } }),
      foldersService.listTree('favorites'),
      usersService.listFollowing(200),
      usersService.listFollowers(200),
      http.get('/me/purchases', { params: { limit: 100, offset: 0 } })
    ])

    myVideos.value = videos
    favoritesTree.value = favTree
    favoriteItems.value = Array.isArray(favAllRes.data?.items) ? favAllRes.data.items : []
    following.value = fwing
    followers.value = fwers
    purchases.value = Array.isArray(purchasesRes.data?.items) ? purchasesRes.data.items : []
  } catch (err) {
    errorText.value = err?.response?.data?.message || 'Failed to load dashboard overview'
    myVideos.value = []
    favoriteItems.value = []
    favoritesTree.value = []
    following.value = []
    followers.value = []
    purchases.value = []
  } finally {
    loading.value = false
  }
}

onMounted(loadOverview)
</script>

<template>
  <section class="overview">
    <header class="overview-header">
      <h1 class="overview-title">Dashboard</h1>
      <p class="overview-subtitle">Operational snapshot from live data.</p>
      <button class="btn btn-secondary" :disabled="loading" @click="loadOverview">↻ Refresh</button>
    </header>

    <p v-if="errorText" class="error">{{ errorText }}</p>

    <div v-if="loading" class="muted">Loading overview…</div>

    <div v-else class="grid sections-grid">
      <section class="panel section-card">
        <h3 class="section-title">My Videos Summary</h3>
        <div class="summary-grid">
          <div class="summary-cell"><span>Total</span><strong>{{ videoSummary.total }}</strong></div>
          <div class="summary-cell"><span>Ready</span><strong>{{ videoSummary.ready }}</strong></div>
          <div class="summary-cell"><span>Processing</span><strong>{{ videoSummary.processing }}</strong></div>
          <div class="summary-cell"><span>Failed</span><strong>{{ videoSummary.failed }}</strong></div>
          <div class="summary-cell"><span>Published</span><strong>{{ videoSummary.published }}</strong></div>
          <div class="summary-cell"><span>Private</span><strong>{{ videoSummary.privateCount }}</strong></div>
          <div class="summary-cell"><span>Protected</span><strong>{{ videoSummary.protectedCount }}</strong></div>
          <div class="summary-cell"><span>Public</span><strong>{{ videoSummary.publicCount }}</strong></div>
        </div>
      </section>

      <section class="panel section-card">
        <h3 class="section-title">Favorites Summary</h3>
        <div class="summary-grid">
          <div class="summary-cell"><span>Folders</span><strong>{{ favoritesSummary.folders }}</strong></div>
          <div class="summary-cell"><span>Items</span><strong>{{ favoritesSummary.items }}</strong></div>
          <div class="summary-cell"><span>Non-empty folders</span><strong>{{ favoritesSummary.withVideos }}</strong></div>
        </div>
        <div v-if="recentFavorites.length > 0" class="chips-row">
          <button
            v-for="v in recentFavorites"
            :key="`fav:${v.video_id}`"
            class="chip"
            type="button"
            @click="goPlay(v.video_id)"
          >
            {{ v.title || `Video ${v.video_id}` }}
          </button>
        </div>
      </section>

      <section class="panel section-card section-wide">
        <h3 class="section-title">Recent Uploads</h3>
        <div v-if="recentUploads.length === 0" class="muted">No uploads yet.</div>
        <div v-else class="grid uploads-grid">
          <article v-for="v in recentUploads" :key="v.id" class="upload-card">
            <button class="thumb" type="button" @click="goPlay(v.id)">
              <img class="thumb-img" :src="posterUrl(v)" alt="Preview" loading="lazy" />
            </button>
            <div class="upload-body">
              <strong>{{ v.title }}</strong>
              <small>{{ v.visibility }} · {{ v.status }} · {{ v.published_at ? 'published' : 'unpublished' }}</small>
            </div>
          </article>
        </div>
      </section>

      <section class="panel section-card">
        <h3 class="section-title">Subscriptions</h3>
        <div class="summary-grid">
          <div class="summary-cell"><span>Following</span><strong>{{ following.length }}</strong></div>
          <div class="summary-cell"><span>Followers</span><strong>{{ followers.length }}</strong></div>
        </div>
        <div class="subs-columns">
          <div>
            <p class="mini-title">Following</p>
            <ul class="mini-list">
              <li v-for="u in following.slice(0, 5)" :key="`fwing:${u.user_id}`">
                <RouterLink :to="`/users/${u.user_id}`">@{{ u.username }}</RouterLink>
              </li>
            </ul>
          </div>
          <div>
            <p class="mini-title">Followers</p>
            <ul class="mini-list">
              <li v-for="u in followers.slice(0, 5)" :key="`fwers:${u.user_id}`">
                <RouterLink :to="`/users/${u.user_id}`">@{{ u.username }}</RouterLink>
              </li>
            </ul>
          </div>
        </div>
      </section>

      <section class="panel section-card section-wide">
        <h3 class="section-title">Purchases</h3>
        <div v-if="recentPurchases.length === 0" class="muted">No purchases yet.</div>
        <div v-else class="purchases-list">
          <div v-for="p in recentPurchases" :key="p.purchase_id" class="purchase-row">
            <div>
              <strong>{{ p.video_title || `Video ${p.video_id}` }}</strong>
              <small>
                {{ p.status }} · {{ p.amount_cents }} {{ p.currency }} · {{ new Date(p.created_at).toLocaleString() }}
              </small>
            </div>
            <button class="btn btn-secondary" type="button" @click="goPlay(p.video_id)">Open video</button>
          </div>
        </div>
      </section>
    </div>
  </section>
</template>

<style scoped>
.overview {
  padding: var(--space-6);
}

.overview-header {
  display: grid;
  gap: 8px;
  margin-bottom: var(--space-5);
}

.overview-title {
  margin: 0;
  font-size: 28px;
  font-weight: 800;
  color: var(--text);
}

.overview-subtitle,
.muted {
  margin: 0;
  color: var(--muted);
  font-size: 14px;
  opacity: 0.9;
}

.sections-grid {
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 16px;
}

.section-card {
  padding: 16px;
}

.section-wide {
  grid-column: span 2;
}

.section-title {
  margin: 0 0 12px;
  color: var(--ui-fg-1);
}

.summary-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 8px;
}

.summary-cell {
  border: 1px solid var(--border);
  border-radius: 10px;
  padding: 10px;
  display: grid;
  gap: 4px;
}

.summary-cell span {
  color: var(--ui-fg-2);
  font-size: 12px;
}

.summary-cell strong {
  color: var(--ui-fg-1);
  font-size: 18px;
}

.chips-row {
  margin-top: 12px;
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.chip {
  border: 1px solid var(--border);
  background: rgba(255, 255, 255, 0.04);
  color: var(--ui-fg-1);
  border-radius: 999px;
  padding: 6px 10px;
  cursor: pointer;
}

.uploads-grid {
  grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
  gap: 12px;
}

.upload-card {
  border: 1px solid var(--border);
  border-radius: 10px;
  overflow: hidden;
}

.thumb {
  width: 100%;
  border: 0;
  padding: 0;
  background: #000;
  cursor: pointer;
}

.thumb-img {
  width: 100%;
  aspect-ratio: 16 / 9;
  object-fit: cover;
  display: block;
}

.upload-body {
  padding: 10px;
  display: grid;
  gap: 4px;
}

.upload-body strong {
  color: var(--ui-fg-1);
}

.upload-body small {
  color: var(--ui-fg-2);
}

.subs-columns {
  margin-top: 12px;
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
}

.mini-title {
  margin: 0 0 6px;
  color: var(--ui-fg-2);
  font-size: 12px;
}

.mini-list {
  margin: 0;
  padding-left: 18px;
}

.mini-list a {
  color: var(--ui-fg-1);
  text-decoration: none;
}

.mini-list a:hover {
  text-decoration: underline;
}

.purchases-list {
  display: grid;
  gap: 8px;
}

.purchase-row {
  border: 1px solid var(--border);
  border-radius: 10px;
  padding: 10px 12px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
}

.purchase-row strong {
  display: block;
  color: var(--ui-fg-1);
}

.purchase-row small {
  color: var(--ui-fg-2);
}

.error {
  color: var(--text-error);
  margin: 0 0 12px;
}

@media (max-width: 1100px) {
  .sections-grid {
    grid-template-columns: 1fr;
  }

  .section-wide {
    grid-column: span 1;
  }

  .summary-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .subs-columns {
    grid-template-columns: 1fr;
  }

  .purchase-row {
    flex-direction: column;
    align-items: flex-start;
  }
}
</style>
