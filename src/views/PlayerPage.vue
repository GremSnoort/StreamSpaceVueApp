<template>
  <div class="page panel player">
    <header class="player-header">
      <button class="btn btn-secondary" type="button" @click="goBack">
        ← Back
      </button>

      <h1 class="player-title">{{ media?.title || 'Playing' }}</h1>
    </header>

    <div v-if="loading" class="status">
      Loading media…
    </div>

    <div v-else-if="!media" class="status status-empty">
      Media not found.
    </div>

    <div v-else class="grid player-grid">
      <VideoPlayer
        :src="absUrl(media.playUrl)"
        :poster="absUrl(media.preview)"
        :autoplay="true"
        :muted="false"
        @error="onPlayerError"
      />

      <section class="meta">
        <h2 class="meta-title">{{ media.title }}</h2>
        <p class="meta-desc">{{ media.description }}</p>

        <div class="meta-actions">
          <!-- download: лучше без target=_blank, иначе download может игнорироваться -->
          <a class="btn btn-secondary" :href="downloadUrl" download>
            ⬇ Download
          </a>
        </div>
      </section>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import http from '../lib/http'
import VideoPlayer from '../components/VideoPlayer.vue'

const route = useRoute()
const router = useRouter()

const id = route.params.id
const media = ref(null)
const loading = ref(true)

const apiBase = import.meta.env.VITE_API_BASE || '/api'

function absUrl(path) {
  if (!path) return ''
  if (path.startsWith('http')) return path
  return apiBase.replace(/\/+$/, '') + '/' + path.replace(/^\/+/, '')
}

async function loadMedia() {
  loading.value = true
  try {
    const res = await http.get(`/media/${id}`)
    media.value = res.data || null
  } catch (err) {
    console.error('Media load error:', err)

    // fallback — список
    try {
      const resList = await http.get('/media')
      const arr = Array.isArray(resList.data) ? resList.data : []
      media.value = arr.find(i => String(i.id) === String(id)) || null
    } catch {
      media.value = null
    }
  } finally {
    loading.value = false
  }
}

function goBack() {
  router.back()
}

function onPlayerError(e) {
  console.error('player error', e)
}

const downloadUrl = computed(() => (media.value ? absUrl(media.value.url) : ''))

onMounted(loadMedia)
</script>

<style scoped>
/* page-specific only */

.player {
  padding: 28px;
}

.player-header {
  display: flex;
  align-items: center;
  gap: var(--space-4);
  margin-bottom: var(--space-5);
}

.player-title {
  margin: 0;
  font-size: 18px;
  font-weight: 800;
  color: #cfe8ff;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

/* states */
.status {
  text-align: center;
  font-size: 16px;
  color: rgba(255, 255, 255, 0.75);
  padding: var(--space-6) 0;
}
.status-empty {
  opacity: 0.7;
}

/* layout */
.player-grid {
  gap: 18px;
}

/* meta block */
.meta {
  padding: 6px 2px;
}

.meta-title {
  margin: 0 0 8px;
  font-size: 18px;
  font-weight: 800;
  color: #fff;
}

.meta-desc {
  margin: 0;
  color: rgba(255, 255, 255, 0.72);
  line-height: 1.45;
}

.meta-actions {
  margin-top: 14px;
  display: flex;
  gap: 10px;
  flex-wrap: wrap;
}
</style>
