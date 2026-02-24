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
      <section ref="playerShell" class="player-shell" :class="{ 'is-half': playerSize === 'half' }">
        <div class="player-toolbar">
          <button class="btn btn-secondary" type="button" @click="toggleHalfSize">
            {{ playerSize === 'half' ? 'Fixed size' : '50% width' }}
          </button>
          <button class="btn btn-secondary" type="button" @click="enterFullscreen">
            Fullscreen
          </button>
        </div>

        <VideoPlayer
          v-if="manifestUrl"
          :src="manifestUrl"
          :poster="posterUrl"
          :autoplay="true"
          :muted="false"
          @error="onPlayerError"
        />
      </section>
      <div v-if="!manifestUrl" class="status">Playback is not ready yet.</div>

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
const playerSize = ref('fixed')
const playerShell = ref(null)

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

function toggleHalfSize() {
  playerSize.value = playerSize.value === 'half' ? 'fixed' : 'half'
}

async function enterFullscreen() {
  const el = playerShell.value
  if (!el?.requestFullscreen) return
  try {
    await el.requestFullscreen()
  } catch (err) {
    console.error('fullscreen error', err)
  }
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
  grid-template-columns: 1fr;
}

.player-shell {
  width: min(760px, 100%);
  margin: 0 auto;
}

.player-shell.is-half {
  width: min(50vw, 100%);
}

.player-toolbar {
  display: flex;
  gap: 8px;
  justify-content: flex-end;
  margin-bottom: 10px;
}

.player-shell :deep(.video-player) {
  max-height: 72vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #000;
}

.player-shell :deep(.video-player__el) {
  width: auto;
  height: auto;
  max-width: 100%;
  max-height: 72vh;
  object-fit: contain;
}

.player-shell:fullscreen {
  width: 100vw;
  max-width: none;
  height: 100vh;
  margin: 0;
  padding: 12px;
  box-sizing: border-box;
  background: #000;
  display: flex;
  flex-direction: column;
}

.player-shell:fullscreen .player-toolbar {
  margin-bottom: 8px;
}

.player-shell:fullscreen :deep(.video-player) {
  flex: 1 1 auto;
  height: 100%;
  max-height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #000;
}

.player-shell:fullscreen :deep(.video-player__el) {
  width: 100%;
  height: 100%;
  max-width: 100%;
  max-height: 100%;
  min-height: 0;
  object-fit: contain;
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

@media (max-width: 900px) {
  .player-shell,
  .player-shell.is-half {
    width: 100%;
  }
}
</style>
