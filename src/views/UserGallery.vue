<template>
  <div class="page panel gallery">
    <header class="gallery-header">
      <h1 class="title">My Videos</h1>

      <button class="btn btn-primary btn-lg" @click="goUpload">
        ⬆ Upload
      </button>
    </header>

    <div v-if="loading" class="status">
      Loading your media…
    </div>

    <div v-else-if="videos.length === 0" class="status status-empty">
      No videos available.
    </div>

    <div v-else class="grid gallery-grid">
      <article
        v-for="video in videos"
        :key="video.id"
        class="video-card"
      >
        <button class="thumb" type="button" @click="goPlay(video)" title="Play">
          <img
            class="thumb-img"
            :src="absUrl(video.preview)"
            alt="Preview"
            loading="lazy"
          />
          <span class="thumb-play">▶</span>
        </button>

        <div class="video-body">
          <h2 class="video-title">{{ video.title }}</h2>
          <p class="video-desc">{{ video.description }}</p>

          <div class="video-actions">
            <button class="btn btn-primary" @click="goPlay(video)">▶ Play</button>

            <a class="btn btn-secondary" :href="absUrl(video.url)" download>
              ⬇ Download
            </a>

            <button class="btn btn-danger" @click="confirmDelete(video)">
              🗑 Delete
            </button>
          </div>
        </div>
      </article>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import http from '../lib/http'

const videos = ref([])
const loading = ref(true)

const apiBase = import.meta.env.VITE_API_BASE || '/api'

function absUrl(path) {
  if (!path) return ''
  if (path.startsWith('http')) return path
  return apiBase.replace(/\/+$/, '') + '/' + path.replace(/^\/+/, '')
}

async function loadVideos() {
  loading.value = true
  try {
    const res = await http.get('/media')
    videos.value = Array.isArray(res.data) ? res.data : []
  } catch (err) {
    console.error('Gallery load error:', err)
    videos.value = []
  } finally {
    loading.value = false
  }
}

async function confirmDelete(video) {
  if (!confirm(`Delete "${video.title}"? This cannot be undone.`)) return

  try {
    await http.delete(`/media/${video.id}`)
    await loadVideos()
  } catch (err) {
    alert('Delete failed.')
    console.error(err)
  }
}

const router = useRouter()
function goPlay(video) {
  router.push({ name: 'player', params: { id: video.id } })
}

function goUpload() {
  router.push({ name: 'upload' })
}

onMounted(loadVideos)
</script>

<style scoped>
/* only page-specific styles remain (design system handles .page/.panel/.title/.btn/.grid) */

.gallery {
  padding: 28px;
}

.gallery-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-4);
  margin-bottom: var(--space-5);
}

.status {
  text-align: center;
  font-size: 16px;
  color: rgba(255, 255, 255, 0.75);
  padding: var(--space-6) 0;
}
.status-empty {
  opacity: 0.7;
}

/* grid */
.gallery-grid {
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 22px;
}

/* card */
.video-card {
  background: linear-gradient(145deg, rgba(255,255,255,0.04), rgba(255,255,255,0.02));
  border: 1px solid rgba(30, 144, 255, 0.12);
  border-radius: var(--r-lg);
  overflow: hidden;
  box-shadow: var(--shadow-soft);
  transition: transform 0.25s, box-shadow 0.25s;
}

.video-card:hover {
  transform: translateY(-4px);
  box-shadow: var(--shadow-lg);
}

/* thumbnail */
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
  filter: brightness(0.82);
  transition: transform 0.35s, filter 0.35s;
}

.video-card:hover .thumb-img {
  transform: scale(1.04);
  filter: brightness(0.95);
}

.thumb-play {
  position: absolute;
  left: 14px;
  bottom: 12px;
  padding: 6px 10px;
  border-radius: 999px;
  font-size: 13px;
  color: #fff;
  background: rgba(0, 0, 0, 0.55);
  border: 1px solid rgba(255,255,255,0.12);
  backdrop-filter: blur(6px);
}

/* body */
.video-body {
  padding: 14px 16px 16px;
}

.video-title {
  margin: 0 0 6px;
  font-size: 18px;
  font-weight: 700;
  color: #fff;
}

.video-desc {
  margin: 0 0 14px;
  font-size: 14px;
  color: rgba(255, 255, 255, 0.72);
  min-height: 40px;
}

/* actions */
.video-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
}
</style>
