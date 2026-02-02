<script setup>
import { ref, onMounted } from 'vue'
import http from '../../lib/http'

const stats = ref({
  videos: 0,
  storage: '—',
  lastUpload: '—'
})

onMounted(async () => {
  try {
    const res = await http.get('/media')
    const media = res.data || []

    stats.value.videos = media.length

    if (media.length) {
      const last = media[media.length - 1]
      stats.value.lastUpload = new Date(last.createdAt).toLocaleDateString()
    }

    // Заглушка под будущее (когда появится backend-статистика)
    stats.value.storage = `${(media.length * 42).toFixed(1)} MB`
  } catch (e) {
    console.error('Failed to load dashboard stats', e)
  }
})

function addToFavourites(video) {
  if (!favourites.value.find(v => v.id === video.id)) {
    favourites.value.push(video)
  }
}

const favourites = ref([
  { id: 1, title: 'My Travel Vlog', thumbnail: 'https://placehold.co/320x180?text=Video+1' },
  { id: 2, title: 'Vue Upload Demo', thumbnail: 'https://placehold.co/320x180?text=Video+2' }
])

const recommendations = ref([
  { id: 101, title: 'Top Vue Tips', thumbnail: 'https://placehold.co/320x180?text=Recommended+1' },
  { id: 102, title: 'Express Upload Guide', thumbnail: 'https://placehold.co/320x180?text=Recommended+2' },
  { id: 103, title: 'Streaming Architecture', thumbnail: 'https://placehold.co/320x180?text=Recommended+3' }
])
</script>

<template>
  <section class="overview">
    <header class="overview-header">
      <h1 class="overview-title">Dashboard</h1>
      <p class="overview-subtitle">Your content at a glance</p>
    </header>

    <!-- STATS -->
    <div class="grid stats-grid">
      <div class="panel stat-card">
        <span class="stat-icon">🎞</span>
        <div>
          <p class="stat-label">Videos</p>
          <p class="stat-value">{{ stats.videos }}</p>
        </div>
      </div>

      <div class="panel stat-card">
        <span class="stat-icon">💾</span>
        <div>
          <p class="stat-label">Storage used</p>
          <p class="stat-value">{{ stats.storage }}</p>
        </div>
      </div>

      <div class="panel stat-card">
        <span class="stat-icon">⏱</span>
        <div>
          <p class="stat-label">Last upload</p>
          <p class="stat-value">{{ stats.lastUpload }}</p>
        </div>
      </div>
    </div>

    <!-- EXTRAS -->
    <div class="grid extras-grid">
      <!-- FAVOURITES -->
      <section class="panel extra-card">
        <h3 class="extra-title">⭐ Favourites</h3>

        <div v-if="favourites.length" class="grid thumbs-grid">
          <article v-for="v in favourites" :key="v.id" class="thumb-card">
            <img class="thumb-img" :src="v.thumbnail" alt="thumbnail" loading="lazy" />
            <div class="thumb-title" :title="v.title">{{ v.title }}</div>
          </article>
        </div>

        <p v-else class="muted">No favourites yet</p>
      </section>

      <!-- RECOMMENDATIONS -->
      <section class="panel extra-card">
        <h3 class="extra-title">🔥 Recommendations</h3>

        <div v-if="recommendations.length" class="grid thumbs-grid">
          <article v-for="v in recommendations" :key="v.id" class="thumb-card">
            <div class="thumb-wrap">
              <img class="thumb-img" :src="v.thumbnail" alt="thumbnail" loading="lazy" />

              <button
                class="btn fav-btn"
                type="button"
                @click.stop="addToFavourites(v)"
                title="Add to favourites"
              >
                ❤️
              </button>
            </div>

            <div class="thumb-title" :title="v.title">{{ v.title }}</div>
          </article>
        </div>

        <p v-else class="muted">No recommendations yet</p>
      </section>
    </div>
  </section>
</template>

<style scoped>
/* page-specific only */

.overview {
  padding: var(--space-6);
}

/* header */
.overview-title {
  margin: 0 0 6px;
  font-size: 28px;
  font-weight: 800;
  color: #cfe8ff;
}

.overview-subtitle {
  margin: 0 0 var(--space-6);
  color: var(--muted);
  font-size: 14px;
  opacity: 0.9;
}

/* stats */
.stats-grid {
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: 18px;
}

.stat-card {
  padding: 18px;
  display: flex;
  align-items: center;
  gap: 14px;
  box-shadow: var(--shadow-blue);
  transition: transform 0.25s, box-shadow 0.25s;
}

.stat-card:hover {
  transform: translateY(-3px);
  box-shadow: var(--shadow-blue-hover);
}

.stat-icon {
  font-size: 26px;
}

.stat-label {
  margin: 0 0 4px;
  font-size: 13px;
  color: var(--muted);
  opacity: 0.95;
}

.stat-value {
  margin: 0;
  font-size: 22px;
  font-weight: 800;
  color: var(--text);
}

/* extras */
.extras-grid {
  margin-top: var(--space-7);
  grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
  gap: 18px;
}

.extra-card {
  padding: 20px;
  box-shadow: var(--shadow-blue);
}

.extra-title {
  margin: 0 0 14px;
  font-size: 16px;
  color: #9fcff7;
  display: flex;
  align-items: center;
  gap: 8px;
}

.muted {
  margin: 0;
  font-size: 14px;
  opacity: 0.65;
}

/* thumbs */
.thumbs-grid {
  grid-template-columns: repeat(auto-fill, minmax(160px, 1fr));
  gap: 14px;
}

.thumb-card {
  border-radius: var(--r-md);
  overflow: hidden;
  background: rgba(0, 0, 0, 0.18);
  border: 1px solid rgba(30, 144, 255, 0.12);
  transition: transform 0.25s, box-shadow 0.25s;
  cursor: pointer;
}

.thumb-card:hover {
  transform: translateY(-3px);
  box-shadow: var(--shadow-blue-hover);
}

.thumb-wrap {
  position: relative;
}

.thumb-img {
  width: 100%;
  aspect-ratio: 16 / 9;
  object-fit: cover;
  display: block;
  filter: brightness(0.9);
}

.thumb-title {
  padding: 10px;
  font-size: 13px;
  color: #cfe8ff;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

/* fav button */
.fav-btn {
  position: absolute;
  top: 8px;
  right: 8px;
  width: 34px;
  height: 34px;
  border-radius: 999px;
  border: 1px solid rgba(255, 255, 255, 0.12);
  background: rgba(0, 0, 0, 0.55);
  display: grid;
  place-items: center;
  padding: 0;
  opacity: 0;
  transition: opacity 0.2s, transform 0.2s;
}

.thumb-card:hover .fav-btn {
  opacity: 1;
  transform: scale(1.06);
}
</style>
