<script setup>
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import PageLayout from '../components/PageLayout.vue'
import homeCover from '@/assets/images/homeCover.png'
import videosService from '../services/videosService'
import usersService from '../services/usersService'
import { useAuthStore } from '../stores/auth'

const PAGE_SIZE = 24

const router = useRouter()
const auth = useAuthStore()

const apiBase = (import.meta.env.VITE_API_BASE || 'http://localhost:8080').replace(/\/+$/, '')
const fallbackPoster = 'https://placehold.co/640x360?text=No+Poster'

const feedType = ref('combined')
const feedWindow = ref('48 hours')
const errorText = ref('')

const combinedItems = ref([])
const hotItems = ref([])
const followingItems = ref([])

const combinedOffset = ref(0)
const hotOffset = ref(0)
const followingOffset = ref(0)

const combinedHasMore = ref(true)
const hotHasMore = ref(true)
const followingHasMore = ref(true)

const combinedLoading = ref(false)
const hotLoading = ref(false)
const followingLoading = ref(false)

const feedSentinel = ref(null)
const observer = ref(null)
const ownerNameByID = ref({})

const isLoggedIn = computed(() => !!auth.user)

const currentItems = computed(() => {
  if (feedType.value === 'hot') return hotItems.value
  if (feedType.value === 'following') return followingItems.value
  return combinedItems.value
})

const currentLoading = computed(() => {
  if (feedType.value === 'hot') return hotLoading.value
  if (feedType.value === 'following') return followingLoading.value
  return combinedLoading.value
})

const currentHasMore = computed(() => {
  if (feedType.value === 'hot') return hotHasMore.value
  if (feedType.value === 'following') return followingHasMore.value
  return combinedHasMore.value
})

const currentTitle = computed(() => {
  if (feedType.value === 'hot') return 'Hot'
  if (feedType.value === 'following') return 'Following'
  return 'Combined'
})

const currentNote = computed(() => {
  if (feedType.value === 'hot') return 'Trending videos by weighted score in selected time window.'
  if (feedType.value === 'following') return 'Latest posts from creators you follow.'
  return 'Unified stream with deduplication (`following` first, then `hot`).'
})

function toVideoID(item) {
  return item?.video_id || item?.id || null
}

function itemKey(item) {
  return String(toVideoID(item) || '') + ':' + String(item?.source || '')
}

function mergeUnique(existing, incoming) {
  const seen = new Set(existing.map((x) => itemKey(x)))
  const merged = [...existing]
  for (const item of incoming) {
    const key = itemKey(item)
    if (!key || seen.has(key)) continue
    seen.add(key)
    merged.push(item)
  }
  return merged
}

function posterUrl(item) {
  if (!item?.poster_key) return fallbackPoster
  if (String(item.poster_key).startsWith('http')) return item.poster_key
  const id = toVideoID(item)
  if (!id) return fallbackPoster
  const name = String(item.poster_key).split('/').pop()
  return `${apiBase}/stream/hls/${id}/${name}`
}

function openVideo(item) {
  const id = toVideoID(item)
  if (!id) return
  router.push({ name: 'player', params: { id } })
}

function ownerLabel(item) {
  const ownerID = String(item?.owner_id || '')
  const owner = ownerNameByID.value[ownerID] || 'unknown'
  const src = item?.source ? ` · ${item.source}` : ''
  return `Owner: @${owner}${src}`
}

async function resolveOwnerNames(items) {
  const ids = [...new Set((items || []).map((x) => String(x?.owner_id || '')).filter(Boolean))]
  const missing = ids.filter((id) => !ownerNameByID.value[id])
  if (missing.length === 0) return

  const loaded = await Promise.all(
    missing.map(async (id) => {
      try {
        const p = await usersService.getProfile(id)
        return [id, String(p?.username || '').trim() || null]
      } catch {
        return [id, null]
      }
    })
  )
  const next = { ...ownerNameByID.value }
  for (const [id, username] of loaded) next[id] = username || 'unknown'
  ownerNameByID.value = next
}

async function loadCombined(reset = false) {
  if (combinedLoading.value) return
  if (!reset && !combinedHasMore.value) return
  combinedLoading.value = true
  try {
    const offset = reset ? 0 : combinedOffset.value
    const items = await videosService.listCombined(PAGE_SIZE, offset, feedWindow.value)
    await resolveOwnerNames(items)
    combinedItems.value = reset ? items : mergeUnique(combinedItems.value, items)
    combinedOffset.value = offset + items.length
    combinedHasMore.value = items.length === PAGE_SIZE
  } finally {
    combinedLoading.value = false
  }
}

async function loadHot(reset = false) {
  if (hotLoading.value) return
  if (!reset && !hotHasMore.value) return
  hotLoading.value = true
  try {
    const offset = reset ? 0 : hotOffset.value
    const items = await videosService.listHot(PAGE_SIZE, offset, feedWindow.value)
    await resolveOwnerNames(items)
    hotItems.value = reset ? items : mergeUnique(hotItems.value, items)
    hotOffset.value = offset + items.length
    hotHasMore.value = items.length === PAGE_SIZE
  } finally {
    hotLoading.value = false
  }
}

async function loadFollowing(reset = false) {
  if (!isLoggedIn.value) {
    followingItems.value = []
    followingOffset.value = 0
    followingHasMore.value = false
    followingLoading.value = false
    return
  }
  if (followingLoading.value) return
  if (!reset && !followingHasMore.value) return
  followingLoading.value = true
  try {
    const offset = reset ? 0 : followingOffset.value
    const items = await videosService.listFollowing(PAGE_SIZE, offset)
    await resolveOwnerNames(items)
    followingItems.value = reset ? items : mergeUnique(followingItems.value, items)
    followingOffset.value = offset + items.length
    followingHasMore.value = items.length === PAGE_SIZE
  } finally {
    followingLoading.value = false
  }
}

function resetType(type) {
  if (type === 'hot') {
    hotItems.value = []
    hotOffset.value = 0
    hotHasMore.value = true
    return
  }
  if (type === 'following') {
    followingItems.value = []
    followingOffset.value = 0
    followingHasMore.value = true
    return
  }
  combinedItems.value = []
  combinedOffset.value = 0
  combinedHasMore.value = true
}

async function ensureCurrentLoaded(reset = false) {
  errorText.value = ''
  try {
    if (feedType.value === 'hot') {
      if (reset) resetType('hot')
      await loadHot(reset)
      return
    }
    if (feedType.value === 'following') {
      if (reset) resetType('following')
      await loadFollowing(reset)
      return
    }
    if (reset) resetType('combined')
    await loadCombined(reset)
  } catch (err) {
    errorText.value = err?.response?.data?.message || 'Failed to load feed'
  }
}

async function refreshCurrent() {
  await ensureCurrentLoaded(true)
  await nextTick()
  setupObserver()
}

async function onFeedTypeChange(nextType) {
  if (feedType.value === nextType) return
  feedType.value = nextType
  if (currentItems.value.length === 0) {
    await ensureCurrentLoaded(false)
  }
  await nextTick()
  setupObserver()
}

function setupObserver() {
  if (observer.value) {
    observer.value.disconnect()
    observer.value = null
  }

  observer.value = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return
        ensureCurrentLoaded(false)
      })
    },
    {
      root: null,
      rootMargin: '260px 0px',
      threshold: 0.01
    }
  )

  if (feedSentinel.value) observer.value.observe(feedSentinel.value)
}

watch(
  () => auth.user,
  async () => {
    if (!isLoggedIn.value) {
      resetType('following')
      followingHasMore.value = false
    } else {
      followingHasMore.value = true
    }

    if (feedType.value === 'following' || feedType.value === 'combined') {
      await refreshCurrent()
    }
  }
)

watch(feedWindow, async () => {
  // window влияет на hot и combined
  if (feedType.value === 'hot' || feedType.value === 'combined') {
    await refreshCurrent()
  }
})

onMounted(async () => {
  await ensureCurrentLoaded(true)
  await nextTick()
  setupObserver()
})

onBeforeUnmount(() => {
  if (observer.value) observer.value.disconnect()
})
</script>

<template>
  <div class="home">
    <section class="cover">
      <img
        :src="homeCover"
        alt="Movie scenes collage"
        class="cover-img"
      />
      <div class="cover-overlay">
        <div class="cover-inner">
          <h1 class="cover-title">StreamSpace</h1>
          <p class="cover-subtitle">Welcome to your Movies Vault — store, stream, and download videos</p>
        </div>
      </div>
    </section>

    <PageLayout>
      <section class="panel features">
        <header class="features-header">
          <h2 class="features-title">Platform Feed</h2>
          <p class="features-desc">Following + Hot + Combined feed available from Home for everyone.</p>
          <div class="grid features-grid">
            <div class="feature-card">
              <h3>Latest Releases</h3>
              <p>Discover trending content and updates</p>
            </div>

            <div class="feature-card">
              <h3>Your own Movie Storage</h3>
              <p>Store your videos privately or shared</p>
            </div>

            <div class="feature-card">
              <h3>Online or Transfer</h3>
              <p>Watch online or download</p>
            </div>
          </div>

          <div class="feed-controls">
            <div class="feed-selector" role="tablist" aria-label="Feed type selector">
              <button class="feed-pill" :class="{ active: feedType === 'combined' }" @click="onFeedTypeChange('combined')">Combined</button>
              <button class="feed-pill" :class="{ active: feedType === 'hot' }" @click="onFeedTypeChange('hot')">Hot</button>
              <button class="feed-pill" :class="{ active: feedType === 'following' }" @click="onFeedTypeChange('following')">Following</button>
            </div>

            <select v-model="feedWindow" class="input feed-window" :disabled="currentLoading">
              <option value="24 hours">Hot window: 24 hours</option>
              <option value="48 hours">Hot window: 48 hours</option>
              <option value="72 hours">Hot window: 72 hours</option>
            </select>

            <button class="btn btn-secondary" :disabled="currentLoading" @click="refreshCurrent">↻ Refresh</button>
          </div>
        </header>

        <p v-if="errorText" class="status status-error">{{ errorText }}</p>

        <section class="feed-section">
          <h3 class="feed-title">{{ currentTitle }}</h3>
          <p class="feed-note">{{ currentNote }}</p>

          <div v-if="feedType === 'following' && !isLoggedIn" class="status status-empty">Login to see Following feed.</div>
          <template v-else>
            <div v-if="currentLoading && currentItems.length === 0" class="status">Loading feed…</div>
            <div v-else-if="currentItems.length === 0" class="status status-empty">No items yet.</div>
            <div v-else class="grid feed-grid">
              <article v-for="item in currentItems" :key="`${feedType}:${toVideoID(item)}:${item.source || ''}`" class="feed-card">
                <button class="thumb" type="button" @click="openVideo(item)">
                  <img class="thumb-img" :src="posterUrl(item)" alt="Preview" loading="lazy" />
                  <span class="thumb-play">▶</span>
                </button>
                <div class="feed-card-body">
                  <h4 class="feed-card-title">{{ item.title }}</h4>
                  <p class="feed-card-meta">{{ ownerLabel(item) }}</p>
                </div>
              </article>
            </div>

            <div v-if="currentHasMore && currentItems.length > 0" ref="feedSentinel" class="feed-sentinel">
              <span v-if="currentLoading">Loading more…</span>
            </div>
            <p v-else-if="currentItems.length > 0" class="feed-end">End of {{ currentTitle.toLowerCase() }} feed.</p>
          </template>
        </section>
      </section>
    </PageLayout>
  </div>
</template>

<style scoped>
.home {
  width: 100%;
}

.cover {
  position: relative;
  width: 100%;
  height: 380px;
  overflow: hidden;
  border-bottom: 1px solid var(--border);
}

.cover-img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  filter: brightness(0.55);
  transform: scale(1.02);
}

.cover-overlay {
  position: absolute;
  inset: 0;
  display: grid;
  place-items: center;
  padding: 16px;
  background:
    radial-gradient(circle at 50% 40%, var(--accent-1), transparent 55%),
    radial-gradient(circle at 70% 70%, var(--accent-2), transparent 60%);
}

.cover-inner {
  text-align: center;
  max-width: 980px;
}

.cover-title {
  margin: 0 0 10px;
  font-size: 52px;
  font-weight: 800;
  letter-spacing: 0.3px;
  background: linear-gradient(to right, var(--title-grad-1), var(--title-grad-2));
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  text-shadow: 0 0 18px var(--shadow-color);
}

.cover-subtitle {
  margin: 0;
  font-size: 18px;
  color: var(--ui-fg-1);
  text-shadow: 0 0 10px rgba(0, 0, 0, 0.35);
}

.features {
  padding: 28px;
  margin-top: 28px;
}

.features-header {
  margin-bottom: 18px;
}

.features-title {
  margin: 0 0 6px;
  font-size: 22px;
  font-weight: 800;
  color: var(--text);
}

.features-desc {
  margin: 0;
  color: var(--ui-fg-1);
  font-size: 14px;
  opacity: 0.9;
}

.features-grid {
  grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
  gap: 18px;
  margin-top: 16px;
}

.feature-card {
  background: linear-gradient(145deg, var(--glass-1), var(--glass-2));
  border: 1px solid var(--glass-border);
  border-radius: var(--r-md);
  padding: 18px;
  box-shadow: var(--shadow-md);
  backdrop-filter: blur(14px);
  -webkit-backdrop-filter: blur(14px);
  transition: transform 0.25s, box-shadow 0.25s, border-color 0.25s;
}

.feature-card:hover {
  transform: translateY(-4px);
  box-shadow: var(--shadow-lg);
  border-color: var(--ui-border-med);
}

.feature-card h3 {
  margin: 0 0 8px;
  font-size: 16px;
  color: var(--primary);
}

.feature-card p {
  margin: 0;
  color: var(--ui-fg-1);
  font-size: 14px;
}

.feed-controls {
  display: flex;
  gap: 10px;
  align-items: center;
  justify-content: center;
  margin-top: 16px;
  flex-wrap: wrap;
}

.feed-selector {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px;
  border-radius: 999px;
  background: linear-gradient(120deg, rgba(0, 168, 255, 0.16), rgba(255, 155, 40, 0.16));
  border: 1px solid rgba(255, 255, 255, 0.15);
}

.feed-pill {
  border: 0;
  border-radius: 999px;
  padding: 10px 18px;
  font-size: 14px;
  font-weight: 700;
  color: var(--ui-fg-1);
  cursor: pointer;
  background: rgba(0, 0, 0, 0.18);
  transition: transform 0.2s, background 0.2s, color 0.2s;
}

.feed-pill:hover {
  transform: translateY(-1px);
}

.feed-pill.active {
  color: var(--text-on-accent);
  background: linear-gradient(90deg, var(--primary), var(--primary-2));
  box-shadow: 0 0 10px rgba(79, 138, 255, 0.35);
}

.feed-window {
  min-width: 220px;
}

.status {
  color: var(--ui-fg-2);
  padding: 10px 0;
}

.status-empty {
  opacity: 0.85;
}

.status-error {
  color: var(--text-error);
}

.feed-section {
  border-top: 1px solid var(--border);
  padding-top: 14px;
}

.feed-title {
  margin: 0;
  font-size: 18px;
  color: var(--ui-fg-1);
}

.feed-note {
  margin: 6px 0 12px;
  color: var(--ui-fg-2);
  font-size: 13px;
}

.feed-grid {
  grid-template-columns: repeat(auto-fill, minmax(240px, 1fr));
  gap: 14px;
}

.feed-card {
  background: linear-gradient(145deg, var(--glass-1), var(--glass-2));
  border: 1px solid var(--glass-border);
  border-radius: var(--r-md);
  overflow: hidden;
}

.thumb {
  width: 100%;
  border: 0;
  padding: 0;
  display: block;
  background: #000;
  cursor: pointer;
  position: relative;
}

.thumb-img {
  width: 100%;
  aspect-ratio: 16 / 9;
  object-fit: cover;
  display: block;
}

.thumb-play {
  position: absolute;
  left: 12px;
  bottom: 10px;
  padding: 4px 8px;
  border-radius: 999px;
  color: var(--text-on-accent);
  background: rgba(0, 0, 0, 0.55);
  border: 1px solid rgba(255, 255, 255, 0.12);
}

.feed-card-body {
  padding: 10px 12px 12px;
}

.feed-card-title {
  margin: 0 0 6px;
  font-size: 15px;
  color: var(--ui-fg-1);
}

.feed-card-meta {
  margin: 0;
  color: var(--ui-fg-2);
  font-size: 12px;
}

.feed-sentinel {
  min-height: 24px;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-top: 8px;
  color: var(--ui-fg-2);
  font-size: 13px;
}

.feed-end {
  margin: 10px 0 0;
  color: var(--ui-fg-2);
  font-size: 12px;
}

@media (max-width: 768px) {
  .cover {
    height: 320px;
  }

  .cover-title {
    font-size: 38px;
  }

  .cover-subtitle {
    font-size: 15px;
  }

  .features {
    padding: 20px;
    margin-top: 20px;
  }

  .feed-window {
    min-width: 100%;
  }

  .feed-selector {
    width: 100%;
    justify-content: space-between;
  }

  .feed-pill {
    flex: 1;
    text-align: center;
  }
}
</style>
