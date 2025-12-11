<template>
  <div class="gallery-wrapper">

    <div class="header-bar">
    <h1 class="page-title">My Videos</h1>

    <button class="upload-btn" @click="goUpload">
        ⬆ Upload
    </button>
    </div>

    <div v-if="loading" class="status-message">
      Loading your media…
    </div>

    <div v-else-if="videos.length === 0" class="status-message empty">
      No videos available.
    </div>

    <div v-else class="video-grid">
      <div
        v-for="video in videos"
        :key="video.id"
        class="video-card"
      >
        <div class="thumb-wrap">
          <img
            class="video-thumb"
            :src="previewUrl(video)"
            alt="Preview"
          />
        </div>

        <div class="video-info">
          <h2 class="video-title">{{ video.title }}</h2>
          <p class="video-description">{{ video.description }}</p>

          <div class="video-actions">
            <button class="btn btn-primary" @click="goPlay(video)">▶ Play</button>
          
            <a class="btn btn-secondary" :href="downloadUrl(video)" target="_blank">
              ⬇ Download
            </a>
          
            <button class="btn btn-danger" @click="confirmDelete(video)">
              🗑 Delete
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from "vue";
import { useRouter } from "vue-router";
import http from "../lib/http";

const videos = ref([]);
const loading = ref(true);

const apiBase = import.meta.env.VITE_API_BASE || "/api";

async function loadVideos() {
  try {
    const res = await http.get("/media");
    videos.value = Array.isArray(res.data) ? res.data : [];
  } catch (err) {
    console.error("Gallery load error:", err);
    videos.value = [];
  }
  loading.value = false;
}

function previewUrl(video) {
  if (!video.preview) return "";  

  // absolute URL → return as-is
  if (video.preview.startsWith("http")) return video.preview;

  // ensure single `/`
  return apiBase.replace(/\/+$/, "") + "/" + video.preview.replace(/^\/+/, "");
}

function downloadUrl(video) {
  if (!video.url) return "";

  if (video.url.startsWith("http")) return video.url;

  return apiBase.replace(/\/+$/, "") + "/" + video.url.replace(/^\/+/, "");
}

async function confirmDelete(video) {
  if (!confirm(`Delete "${video.title}"? This cannot be undone.`)) return;

  try {
    await http.delete(`/media/${video.id}`);
    await loadVideos(); // refresh list
  } catch (err) {
    alert("Delete failed.");
    console.error(err);
  }
}

const router = useRouter();
function goPlay(video) {
  router.push({ name: 'player', params: { id: video.id } });
}

function goUpload() {
  router.push({ name: "upload" });
}

onMounted(loadVideos);
</script>

<style scoped>
/* page wrapper */
.gallery-wrapper {
  padding: 30px;
  max-width: 1100px;
  margin: 0 auto;
  color: white;

  /* subtle top diagonal gradient */
  background: linear-gradient(145deg, #0f0f0f 0%, #151515 40%, #0d0d0d 100%);
  border-radius: 16px;
}

/* page title */
.page-title {
  font-size: 34px;
  font-weight: 700;
  margin-bottom: 30px;

  background: linear-gradient(to right, #6aa8ff, #b1d1ff);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;

  text-shadow: 0px 0px 25px rgba(122, 165, 255, 0.28);
}

/* loading + empty */
.status-message {
  text-align: center;
  font-size: 18px;
  color: #bbb;
  padding: 20px 0;
}
.status-message.empty {
  opacity: 0.6;
}

/* grid */
.video-grid {
  display: grid;
  gap: 28px;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
}

/* card */
.video-card {
  background: linear-gradient(145deg, #1c1c1c, #1a1a1a);
  border-radius: 14px;
  overflow: hidden;
  padding-bottom: 12px;

  border: 1px solid #292929;
  box-shadow: 0 0 18px rgba(0, 0, 0, 0.45),
              0 0 25px rgba(75, 115, 255, 0.09);

  transition: transform 0.25s ease, box-shadow 0.25s ease;
}

.video-card:hover {
  transform: translateY(-4px);
  box-shadow: 0 0 22px rgba(98, 142, 255, 0.20),
              0 0 40px rgba(26, 78, 255, 0.14);
}

/* thumbnail */
.thumb-wrap {
  height: 170px;
  overflow: hidden;
  border-bottom: 1px solid #2d2d2d;
}

.video-thumb {
  width: 100%;
  height: 100%;
  object-fit: cover;
  transition: transform 0.4s ease;
}
.video-card:hover .video-thumb {
  transform: scale(1.08);
}

/* text area */
.video-info {
  padding: 14px 16px;
}

.video-title {
  font-size: 19px;
  font-weight: 600;
  margin-bottom: 6px;
}

.video-description {
  color: #bbb;
  font-size: 14px;
  margin-bottom: 14px;
  min-height: 40px;
}

/* buttons */
.video-actions {
  display: flex;
  gap: 10px;
}

.btn {
  padding: 8px 14px;
  font-size: 14px;
  border-radius: 6px;
  cursor: pointer;
  border: none;
  text-decoration: none;
  transition: 0.25s;
  display: inline-flex;
  align-items: center;
  gap: 4px;
}

.btn-primary {
  background: linear-gradient(to right, #4f8aff, #306dff);
  color: white;
  box-shadow: 0 0 12px rgba(71, 125, 255, 0.35);
}
.btn-primary:hover {
  background: linear-gradient(to right, #6aa4ff, #3a7aff);
}

.btn-secondary {
  background: #2a2a2a;
  color: #d6d6d6;
  border: 1px solid #3a3a3a;
}
.btn-secondary:hover {
  background: #353535;
}

.header-bar {
  display: flex;
  justify-content: space-between;
  align-items: center;   /* 🔥 keeps title + button on same line */
  gap: 20px;
  margin-bottom: 22px;
}

.upload-btn {
  padding: 12px 26px;
  font-size: 18px;
  font-weight: 700;

  background: linear-gradient(135deg, #1e3cff, #0b1a88);
  color: white;

  border: none;
  border-radius: 10px;

  /* Glow */
  box-shadow: 0 4px 14px rgba(40, 60, 255, 0.55);

  cursor: pointer;
  transition: 0.25s ease;

  /* ensures alignment with title */
  line-height: 1;
}

.upload-btn:hover {
  background: linear-gradient(135deg, #304eff, #1526a3);
  transform: translateY(-2px);
  box-shadow: 0 6px 18px rgba(60, 90, 255, 0.65);
}

.btn-danger {
  background: #8d1a1a;
  color: #fff;
  border: 1px solid #aa2b2b;
}
.btn-danger:hover {
  background: #a32222;
}

</style>
