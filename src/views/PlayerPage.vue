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
        v-if="manifestUrl"
        :src="manifestUrl"
        :poster="posterUrl"
        :autoplay="true"
        :muted="false"
        @error="onPlayerError"
      />
      <div v-else class="status">Playback is not ready yet.</div>

      <section class="meta">
        <h2 class="meta-title">{{ media.title }}</h2>
        <p class="meta-desc">{{ media.description }}</p>

        <div class="meta-actions">
          <button class="btn btn-secondary" type="button" @click="requestDownloadSource">
            ⬇ Get Download Source
          </button>
          <code v-if="downloadSourceKey">{{ downloadSourceKey }}</code>
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
const manifestPath = ref('')
const downloadSourceKey = ref('')

const apiBase = (import.meta.env.VITE_API_BASE || 'http://localhost:8080').replace(/\/+$/, '')

function absUrl(path) {
  if (!path) return ''
  if (path.startsWith('http')) return path
  return `${apiBase}/${path.replace(/^\/+/, '')}`
}

async function loadMedia() {
  loading.value = true
  try {
    const [videoRes, playbackRes] = await Promise.all([
      http.get(`/videos/${id}`),
      http.get(`/videos/${id}/playback`)
    ])
    media.value = videoRes.data || null
    manifestPath.value = playbackRes.data?.manifestUrl || ''
  } catch (err) {
    console.error('Media load error:', err)
    media.value = null
    manifestPath.value = ''
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

async function requestDownloadSource() {
  try {
    const { data } = await http.get(`/videos/${id}/download`)
    downloadSourceKey.value = data?.sourceKey || ''
  } catch (err) {
    downloadSourceKey.value = ''
    alert(err?.response?.data?.message || 'No download rights')
  }
}

const manifestUrl = computed(() => absUrl(manifestPath.value))
const posterUrl = computed(() => {
  const key = media.value?.poster_key
  if (!key) return ''
  if (String(key).startsWith('http')) return key
  const name = String(key).split('/').pop()
  return `${apiBase}/stream/hls/${id}/${name}`
})

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
