<template>
  <div class="page-container">
    <h1 class="page-title">My Videos</h1>

    <!-- Loading -->
    <div v-if="loading" class="status-message">
      Loading your media…
    </div>

    <!-- Error OR empty response -->
    <div v-else-if="videos.length === 0" class="status-message">
      No videos available.
    </div>

    <!-- Videos Grid -->
    <div v-else class="video-grid">
      <div v-for="video in videos" :key="video.id" class="video-card">

        <img
          class="video-thumb"
          :src="video.preview"
          alt="Preview"
        />

        <div class="video-info">
          <h2 class="video-title">{{ video.title }}</h2>
          <p class="video-description">{{ video.description }}</p>

          <div class="video-actions">
            <button class="btn" @click="goPlay(video)">Play</button>

            <a class="btn" :href="downloadUrl(video)" target="_blank">
              Download
            </a>
          </div>
        </div>

      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from "vue";
import http from "../lib/http";

// State
const videos = ref([]);
const loading = ref(true);

// Optional backend base url (.env support)
const apiBase = import.meta.env.VITE_API_BASE || "/api";

// Load videos from backend
async function loadVideos() {
  try {
    const res = await http.get("/media");

    // ensure safe fallback
    if (!res || !res.data || !Array.isArray(res.data)) {
      videos.value = [];
    } else {
      videos.value = res.data;
    }

  } catch (err) {
    console.error("Gallery load error:", err);
    // gracefully fallback to empty list
    videos.value = [];
  }

  loading.value = false;
}

function downloadUrl(video) {
  return `${apiBase}/media/download/${video.id}`;
}

function goPlay(video) {
  // If using Vue Router
  window.location.href = `/player/${video.id}`;
}

onMounted(() => loadVideos());
</script>

<style scoped>
.page-container {
  max-width: 900px;
  margin: 0 auto;
  padding: 24px;
}

.page-title {
  font-size: 28px;
  font-weight: bold;
  margin-bottom: 20px;
}

.status-message {
  color: #666;
  font-size: 16px;
  padding: 12px 0;
}

.video-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
  gap: 20px;
}

.video-card {
  background: #1f1f1f;
  border-radius: 8px;
  overflow: hidden;
  border: 1px solid #333;
}

.video-thumb {
  width: 100%;
  height: 160px;
  object-fit: cover;
  background: #000;
}

.video-info {
  padding: 12px;
}

.video-title {
  font-size: 18px;
  margin-bottom: 6px;
  color: #fff;
}

.video-description {
  font-size: 14px;
  color: #ccc;
  margin-bottom: 12px;
  min-height: 40px;
}

.video-actions {
  display: flex;
  gap: 10px;
}

.btn {
  padding: 6px 12px;
  font-size: 14px;
  background: #3a82f7;
  color: white;
  border: none;
  cursor: pointer;
  text-decoration: none;
  border-radius: 4px;
}

.btn:hover {
  background: #2467d6;
}
</style>
