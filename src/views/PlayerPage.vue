<template>
  <div class="player-page">
    <div class="player-header">
      <button class="back-btn" @click="goBack">← Back</button>
      <h1 class="player-title">{{ media?.title || 'Playing' }}</h1>
    </div>

    <div v-if="loading" class="player-loading">Loading media…</div>

    <div v-else-if="!media" class="player-error">Media not found.</div>

    <div v-else class="player-body">
      <VideoPlayer
        :src="media.playUrl"
        :poster="media.preview"
        :autoplay="true"
        :muted="false"
        @error="onPlayerError"
      />

      <div class="meta">
        <h2>{{ media.title }}</h2>
        <p class="desc">{{ media.description }}</p>
        <a :href="downloadUrl" class="download-link" target="_blank">⬇ Download</a>
      </div>
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

async function loadMedia() {
  loading.value = true
  try {
    // правильный источник данных
    const res = await http.get(`/media/${id}`)
    media.value = res.data || null
  } catch (err) {
    console.error("Media load error:", err)

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

function onPlayerError(e){
  console.error('player error', e)
}

const downloadUrl = computed(() => media.value ? `${media.value.url}` : '#')

onMounted(() => loadMedia())
</script>

<style scoped>
.player-page {
  width: 80%;
  height: 100%;
  margin: 24px auto;
  padding: 18px;
  background: linear-gradient(145deg,#0d0d0f,#111);
  border-radius: 12px;
  color: #fff;
  box-sizing: border-box;
}

.player-header {
  display:flex;
  align-items:center;
  gap: 14px;
  margin-bottom: 14px;
}

.back-btn {
  background: transparent;
  color: #bfe1ff;
  border: 1px solid rgba(120,170,255,0.15);
  padding: 8px 12px;
  border-radius: 8px;
  cursor: pointer;
}

.player-title {
  font-size: 20px;
  font-weight: 700;
  background: linear-gradient(90deg,#9ec7ff,#d8e9ff);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
}

.player-body {
  display: grid;
  grid-template-columns: 1fr;
  gap: 20px;
  box-sizing: border-box;
}

video {
  width: 100%;
  max-height: 70vh;
  border-radius: 12px;
}

.meta {
  padding: 8px 4px;
}

.meta .desc {
  color: #cfd9e6;
  margin-top: 6px;
}

.download-link {
  display:inline-block;
  margin-top: 10px;
  background: linear-gradient(90deg,#4f8aff,#306dff);
  color: #fff;
  padding: 8px 12px;
  border-radius: 8px;
  text-decoration: none;
}
</style>
