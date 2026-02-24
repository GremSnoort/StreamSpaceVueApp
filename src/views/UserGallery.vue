<template>
  <div class="page panel gallery">
    <header class="gallery-header">
      <h1 class="title">My Videos</h1>
      <button class="btn btn-primary btn-lg" @click="goUpload">⬆ Upload</button>
    </header>

    <div v-if="loading" class="status">Loading your media…</div>
    <div v-else-if="!hasAnyVideos" class="status status-empty">No videos available.</div>
    <div v-if="errorText" class="status status-error">{{ errorText }}</div>

    <template v-if="isGroupedView && folderGroups.length > 0">
      <section v-for="group in folderGroups" :key="group.id" class="folder-section">
        <h3 class="folder-title" :style="{ paddingLeft: `${group.depth * 14}px` }">
          {{ group.fullName || group.name }}
          <small>({{ group.items.length }})</small>
        </h3>

        <div class="grid gallery-grid">
          <article v-for="video in group.items" :key="`${group.id}:${video.id}`" class="video-card">
            <button class="thumb" type="button" @click="goPlay(video)" title="Play">
              <img class="thumb-img" :src="posterUrl(video)" alt="Preview" loading="lazy" />
              <span class="thumb-play">▶</span>
            </button>
            <div class="video-body">
              <template v-if="editingId === video.id">
                <div class="edit-form">
                  <input v-model="editForm.title" class="input" placeholder="Title" />
                  <textarea v-model="editForm.description" class="input edit-textarea" placeholder="Description" />
                  <select v-model="editForm.visibility" class="input edit-select">
                    <option value="private">private</option>
                    <option value="protected">protected</option>
                    <option value="public">public</option>
                  </select>
                </div>
              </template>
              <template v-else>
                <h2 class="video-title">{{ video.title }}</h2>
                <p class="video-desc">
                  Visibility: {{ video.visibility }} · Status: {{ video.status }} ·
                  {{ video.published_at ? 'published' : 'unpublished' }}
                </p>
              </template>

              <div class="video-actions">
                <button class="btn btn-primary" @click="goPlay(video)">▶ Play</button>
                <template v-if="canManage(video)">
                  <button v-if="editingId !== video.id" class="btn btn-secondary" :disabled="busyVideoId === video.id" @click="startEdit(video)">✎ Edit</button>
                  <button v-else class="btn btn-secondary" :disabled="busyVideoId === video.id" @click="cancelEdit">Cancel</button>
                  <button v-if="editingId === video.id" class="btn btn-primary" :disabled="busyVideoId === video.id" @click="saveEdit(video)">Save</button>
                  <button
                    v-if="editingId !== video.id"
                    class="btn btn-secondary"
                    :disabled="busyVideoId === video.id || video.status !== 'ready'"
                    @click="togglePublish(video)"
                  >
                    {{ video.published_at ? 'Unpublish' : 'Publish' }}
                  </button>
                  <button class="btn btn-danger" :disabled="busyVideoId === video.id" @click="confirmDelete(video)">🗑 Delete</button>
                </template>
              </div>
            </div>
          </article>
        </div>
      </section>
    </template>

    <div v-else-if="videos.length > 0" class="grid gallery-grid">
      <article v-for="video in videos" :key="video.id" class="video-card">
        <button class="thumb" type="button" @click="goPlay(video)" title="Play">
          <img class="thumb-img" :src="posterUrl(video)" alt="Preview" loading="lazy" />
          <span class="thumb-play">▶</span>
        </button>

        <div class="video-body">
          <template v-if="editingId === video.id">
            <div class="edit-form">
              <input v-model="editForm.title" class="input" placeholder="Title" />
              <textarea v-model="editForm.description" class="input edit-textarea" placeholder="Description" />
              <select v-model="editForm.visibility" class="input edit-select">
                <option value="private">private</option>
                <option value="protected">protected</option>
                <option value="public">public</option>
              </select>
            </div>
          </template>
          <template v-else>
            <h2 class="video-title">{{ video.title }}</h2>
            <p class="video-desc">
              Visibility: {{ video.visibility }} · Status: {{ video.status }} ·
              {{ video.published_at ? 'published' : 'unpublished' }}
            </p>
          </template>

          <div class="video-actions">
            <button class="btn btn-primary" @click="goPlay(video)">▶ Play</button>
            <template v-if="canManage(video)">
              <button v-if="editingId !== video.id" class="btn btn-secondary" :disabled="busyVideoId === video.id" @click="startEdit(video)">✎ Edit</button>
              <button v-else class="btn btn-secondary" :disabled="busyVideoId === video.id" @click="cancelEdit">Cancel</button>
              <button v-if="editingId === video.id" class="btn btn-primary" :disabled="busyVideoId === video.id" @click="saveEdit(video)">Save</button>
              <button
                v-if="editingId !== video.id"
                class="btn btn-secondary"
                :disabled="busyVideoId === video.id || video.status !== 'ready'"
                @click="togglePublish(video)"
              >
                {{ video.published_at ? 'Unpublish' : 'Publish' }}
              </button>
              <button class="btn btn-danger" :disabled="busyVideoId === video.id" @click="confirmDelete(video)">🗑 Delete</button>
            </template>
          </div>
        </div>
      </article>
    </div>
  </div>
</template>

<script setup>
import { computed, onMounted, onUnmounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import foldersService from '../services/foldersService'
import videosService from '../services/videosService'

const videos = ref([])
const folderGroups = ref([])
const isGroupedView = ref(false)
const loading = ref(true)
const editingId = ref(null)
const editForm = ref({ title: '', description: '', visibility: 'private' })
const busyVideoId = ref(null)
const errorText = ref('')
let pollTimer = null

const apiBase = (import.meta.env.VITE_API_BASE || 'http://localhost:8080').replace(/\/+$/, '')
const fallbackPoster = 'https://placehold.co/640x360?text=No+Poster'
const hasAnyVideos = computed(() => videos.value.length > 0 || folderGroups.value.some((g) => g.items.length > 0))

function posterUrl(video) {
  if (!video?.poster_key) return fallbackPoster
  if (String(video.poster_key).startsWith('http')) return video.poster_key
  const name = String(video.poster_key).split('/').pop()
  return `${apiBase}/stream/hls/${video.id}/${name}`
}

function canManage(video) {
  return !!video?.created_at
}

function setupPolling() {
  if (pollTimer) {
    clearInterval(pollTimer)
    pollTimer = null
  }
  const hasPendingFlat = videos.value.some((v) => v.status === 'uploading' || v.status === 'processing')
  const hasPendingGroups = folderGroups.value.some((g) => g.items.some((v) => v.status === 'uploading' || v.status === 'processing'))
  if (hasPendingFlat || hasPendingGroups) {
    pollTimer = setInterval(() => {
      loadVideos()
    }, 4000)
  }
}

async function loadVideos() {
  loading.value = true
  errorText.value = ''
  try {
    const myVideos = await videosService.listMyVideos(200, 0)
    videos.value = myVideos

    const tree = await foldersService.listTree('library')
    if (tree.length > 0) {
      const byId = new Map(myVideos.map((v) => [v.id, v]))
      const folderNameByID = new Map(tree.map((f) => [f.id, f.name]))
      const grouped = await Promise.all(
        tree.map(async (folder) => {
          const items = await foldersService.listFolderVideos(folder.id, { limit: 200 })
          const merged = items.map((item) => {
            const full = byId.get(item.video_id) || {}
            return {
              ...full,
              ...item,
              id: item.video_id,
              title: item.title || full.title || `Video ${item.video_id}`
            }
          })
          const fullName = Array.isArray(folder.path)
            ? folder.path.map((id) => folderNameByID.get(id) || id).join('/')
            : folder.name
          return { ...folder, fullName, items: merged }
        })
      )
      const nonEmpty = grouped.filter((g) => g.items.length > 0)
      const placedIDs = new Set(nonEmpty.flatMap((g) => g.items.map((i) => i.id)))
      const unplaced = myVideos.filter((v) => !placedIDs.has(v.id))
      if (unplaced.length > 0) {
        nonEmpty.unshift({
          id: 'unplaced',
          depth: 0,
          name: 'Unplaced',
          fullName: 'Unplaced',
          items: unplaced
        })
      }
      folderGroups.value = nonEmpty
      isGroupedView.value = folderGroups.value.length > 0
    } else {
      folderGroups.value = []
      isGroupedView.value = false
    }
  } catch (err) {
    if (err?.response?.status === 401) {
      try {
        const items = await videosService.listHot(100, 0, '48 hours')
        videos.value = items.map((v) => ({
          id: v.video_id,
          title: v.title,
          poster_key: v.poster_key,
          published_at: v.published_at,
          visibility: 'public',
          status: 'ready'
        }))
        folderGroups.value = []
        isGroupedView.value = false
      } catch (feedErr) {
        console.error('Public gallery load error:', feedErr)
        errorText.value = feedErr?.response?.data?.message || 'Failed to load gallery'
        videos.value = []
      }
    } else {
      console.error('Gallery load error:', err)
      errorText.value = err?.response?.data?.message || 'Failed to load videos'
      videos.value = []
    }
  } finally {
    loading.value = false
    setupPolling()
  }
}

async function startEdit(video) {
  if (!canManage(video)) return
  busyVideoId.value = video.id
  errorText.value = ''
  try {
    const full = await videosService.getVideo(video.id)
    editingId.value = video.id
    editForm.value = {
      title: full?.title || video.title || '',
      description: full?.description || '',
      visibility: full?.visibility || video.visibility || 'private'
    }
  } catch (err) {
    errorText.value = err?.response?.data?.message || 'Failed to load video details'
  } finally {
    busyVideoId.value = null
  }
}

function cancelEdit() {
  editingId.value = null
  editForm.value = { title: '', description: '', visibility: 'private' }
}

async function saveEdit(video) {
  if (!canManage(video) || editingId.value !== video.id) return
  const title = editForm.value.title.trim()
  if (!title) {
    alert('Title is required')
    return
  }
  busyVideoId.value = video.id
  errorText.value = ''
  try {
    await videosService.updateVideo(video.id, {
      title,
      description: editForm.value.description?.trim() || null,
      visibility: editForm.value.visibility
    })
    cancelEdit()
    await loadVideos()
  } catch (err) {
    errorText.value = err?.response?.data?.message || 'Update failed'
  } finally {
    busyVideoId.value = null
  }
}

async function togglePublish(video) {
  if (!canManage(video)) return
  busyVideoId.value = video.id
  errorText.value = ''
  try {
    if (video.published_at) await videosService.unpublishVideo(video.id)
    else await videosService.publishVideo(video.id)
    await loadVideos()
  } catch (err) {
    errorText.value = err?.response?.data?.message || 'Publish action failed'
  } finally {
    busyVideoId.value = null
  }
}

async function confirmDelete(video) {
  if (!canManage(video)) return
  if (!confirm(`Delete "${video.title}"? This cannot be undone.`)) return
  busyVideoId.value = video.id
  errorText.value = ''
  try {
    await videosService.deleteVideo(video.id)
    await loadVideos()
  } catch (err) {
    errorText.value = err?.response?.data?.message || 'Delete failed'
    console.error(err)
  } finally {
    busyVideoId.value = null
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
onUnmounted(() => {
  if (pollTimer) clearInterval(pollTimer)
})
</script>

<style scoped>
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

.status-error {
  color: #ff8f8f;
  padding-top: 0;
}

.folder-section {
  margin-bottom: 28px;
}

.folder-title {
  margin: 0 0 10px;
  color: var(--ui-fg-1);
}

.folder-title small {
  color: var(--ui-fg-2);
}

.gallery-grid {
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 22px;
}

.video-card {
  background: linear-gradient(145deg, rgba(255, 255, 255, 0.04), rgba(255, 255, 255, 0.02));
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
  border: 1px solid rgba(255, 255, 255, 0.12);
  backdrop-filter: blur(6px);
}

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

.video-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
}

.edit-form {
  display: grid;
  gap: 10px;
  margin-bottom: 10px;
}

.edit-textarea {
  min-height: 84px;
  resize: vertical;
}
</style>
