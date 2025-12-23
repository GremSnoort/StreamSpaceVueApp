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
  // пока просто добавляем локально
  if (!favourites.value.find(v => v.id === video.id)) {
    favourites.value.push(video)
  }
}

const favourites = ref([
  {
    id: 1,
    title: 'My Travel Vlog',
    thumbnail: 'https://placehold.co/320x180?text=Video+1'
  },
  {
    id: 2,
    title: 'Vue Upload Demo',
    thumbnail: 'https://placehold.co/320x180?text=Video+2'
  }
])

const recommendations = ref([
  {
    id: 101,
    title: 'Top Vue Tips',
    thumbnail: 'https://placehold.co/320x180?text=Recommended+1'
  },
  {
    id: 102,
    title: 'Express Upload Guide',
    thumbnail: 'https://placehold.co/320x180?text=Recommended+2'
  },
  {
    id: 103,
    title: 'Streaming Architecture',
    thumbnail: 'https://placehold.co/320x180?text=Recommended+3'
  }
])
</script>

<template>
  <section class="overview">
    <header class="overview-header">
      <h1>Dashboard</h1>
      <p>Your content at a glance</p>
    </header>

    <div class="stats-grid">
      <div class="stat-card">
        <span class="icon">🎞</span>
        <div>
          <p class="label">Videos</p>
          <p class="value">{{ stats.videos }}</p>
        </div>
      </div>

      <div class="stat-card">
        <span class="icon">💾</span>
        <div>
          <p class="label">Storage used</p>
          <p class="value">{{ stats.storage }}</p>
        </div>
      </div>

      <div class="stat-card">
        <span class="icon">⏱</span>
        <div>
          <p class="label">Last upload</p>
          <p class="value">{{ stats.lastUpload }}</p>
        </div>
      </div>
    </div>

    <!-- EXTRA SECTIONS -->
    <div class="extras-grid">
        <!-- FAVOURITES -->
        <section class="extra-card">
            <h3>⭐ Favourites</h3>

            <div v-if="favourites.length" class="fav-grid">
                <div
                v-for="v in favourites"
                :key="v.id"
                class="fav-card"
                >
                <img :src="v.thumbnail" alt="thumbnail" />
                <div class="fav-title">{{ v.title }}</div>
                </div>
            </div>

            <p v-else class="empty">No favourites yet</p>
        </section>


        <!-- RECOMMENDATIONS -->
        <section class="extra-card">
            <h3>🔥 Recommendations</h3>

            <div v-if="recommendations.length" class="fav-grid">
                <div
                v-for="v in recommendations"
                :key="v.id"
                class="fav-card"
                >
                <div class="thumb-wrapper">
                    <img :src="v.thumbnail" alt="thumbnail" />

                    <button
                    class="fav-btn"
                    @click.stop="addToFavourites(v)"
                    title="Add to favourites"
                    >
                    ❤️
                    </button>
                </div>

                <div class="fav-title">{{ v.title }}</div>
                </div>

            </div>

            <p v-else class="empty">No recommendations yet</p>
        </section>

    </div>
  </section>
</template>

<style scoped>
.overview {
  padding: 32px;
}

/* Header */
.overview-header h1 {
  font-size: 28px;
  font-weight: 600;
  margin-bottom: 6px;
}

.overview-header p {
  color: #8fbce6;
  font-size: 14px;
  margin-bottom: 32px;
}

/* Grid */
.stats-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: 20px;
}

/* Card */
.stat-card {
  background: linear-gradient(135deg, #0f1b2a, #0b1622);
  border: 1px solid #1c2a3a;
  border-radius: 14px;
  padding: 20px;

  display: flex;
  align-items: center;
  gap: 16px;

  box-shadow: 0 0 25px rgba(0, 140, 255, 0.08);
  transition: transform 0.25s, box-shadow 0.25s;
}

.stat-card:hover {
  transform: translateY(-4px);
  box-shadow: 0 0 35px rgba(0, 140, 255, 0.25);
}

.icon {
  font-size: 28px;
}

.label {
  font-size: 13px;
  color: #8fbce6;
}

.value {
  font-size: 22px;
  font-weight: 600;
  color: #ffffff;
}

/* EXTRA GRID */
.extras-grid {
  margin-top: 40px;
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
  gap: 24px;
}

/* EXTRA CARD */
.extra-card {
  background: linear-gradient(135deg, #0f1b2a, #0b1622);
  border: 1px solid #1c2a3a;
  border-radius: 16px;
  padding: 22px;

  box-shadow: 0 0 25px rgba(0, 140, 255, 0.08);
}

.extra-card h3 {
  margin-bottom: 14px;
  font-size: 16px;
  color: #9fcff7;
}

/* LIST */
.extra-card ul {
  list-style: none;
  padding: 0;
  margin: 0;
}

.extra-card li {
  padding: 8px 0;
  font-size: 14px;
  border-bottom: 1px dashed #23384f;
}

.extra-card li:last-child {
  border-bottom: none;
}

.empty {
  font-size: 14px;
  opacity: 0.6;
}

/* FAVOURITES GRID */
.fav-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(160px, 1fr));
  gap: 16px;
}

/* CARD */
.fav-card {
  background: #0a1624;
  border: 1px solid #1c2a3a;
  border-radius: 12px;
  overflow: hidden;
  cursor: pointer;

  transition: transform 0.25s, box-shadow 0.25s;
}

.fav-card:hover {
  transform: translateY(-4px);
  box-shadow: 0 0 18px rgba(0, 140, 255, 0.35);
}

/* THUMBNAIL */
.fav-card img {
  width: 100%;
  aspect-ratio: 16 / 9;
  object-fit: cover;
  display: block;
}

/* TITLE */
.fav-title {
  padding: 10px;
  font-size: 13px;
  color: #cfe8ff;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.extra-card h3 {
  display: flex;
  align-items: center;
  gap: 8px;
}

.thumb-wrapper {
  position: relative;
}

.fav-btn {
  position: absolute;
  top: 8px;
  right: 8px;

  background: rgba(0, 0, 0, 0.55);
  border: none;
  border-radius: 50%;
  width: 34px;
  height: 34px;

  cursor: pointer;
  font-size: 16px;
  color: #ff6b6b;

  display: flex;
  align-items: center;
  justify-content: center;

  opacity: 0;
  transition: opacity 0.25s, transform 0.25s;
}

.fav-card:hover .fav-btn {
  opacity: 1;
  transform: scale(1.05);
}

.fav-btn:hover {
  background: rgba(255, 80, 80, 0.25);
}
</style>
