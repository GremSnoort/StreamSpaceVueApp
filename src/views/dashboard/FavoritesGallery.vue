<template>
  <div class="page panel gallery favorites-view">
    <header class="gallery-header favorites-header">
      <div>
        <h1 class="title">Favorites</h1>
        <p class="subtitle">Favorites grouped by folders with drag & drop between folders.</p>
      </div>
      <div class="header-actions">
        <button class="btn btn-secondary" :disabled="busy || loading" @click="openCreateFolder(null)">＋ Create Root Folder</button>
        <button class="btn btn-secondary" :disabled="busy || loading" @click="loadFavorites">↻ Refresh</button>
      </div>
    </header>

    <div v-if="loading" class="status">Loading favorites…</div>
    <div v-else-if="groups.length === 0" class="status status-empty">No favorites yet.</div>
    <p v-if="errorText" class="status status-error">{{ errorText }}</p>

    <section
      v-for="group in groups"
      :key="group.id"
      class="folder-section"
      :class="{ 'is-drop-target': dragOverFolderId === group.id }"
      @dragover.prevent="onFolderDragOver(group, $event)"
      @dragleave="onFolderDragLeave(group)"
      @drop.prevent="onFolderDrop(group)"
    >
      <header class="folder-header" :style="{ paddingLeft: `${Math.max(0, group.depth) * 14}px` }">
        <h3 class="folder-title">{{ group.fullName || group.name }} <small>({{ group.items.length }})</small></h3>
        <div class="folder-actions">
          <button class="btn btn-secondary" @click="openCreateFolder(group)">Create folder</button>
          <button class="btn btn-secondary" @click="openFolderUpdate(group)">Update</button>
        </div>
      </header>

      <div v-if="group.items.length === 0" class="folder-empty">No videos in folder.</div>
      <div v-else class="grid gallery-grid">
        <article
          v-for="video in group.items"
          :key="`${group.id}:${video.id}`"
          class="video-card"
          draggable="true"
          @dragstart="onVideoDragStart(video, group)"
          @dragend="onVideoDragEnd"
        >
          <button class="thumb" type="button" @click="goPlay(video)" title="Play">
            <img class="thumb-img" :src="posterUrl(video)" alt="Preview" loading="lazy" />
            <span class="thumb-play">▶</span>
          </button>

          <div class="video-body">
            <h2 class="video-title">{{ video.title }}</h2>
            <p class="video-desc">{{ video.visibility }} · {{ video.status }}</p>
            <div class="video-actions">
              <button class="btn btn-primary" @click="goPlay(video)">▶ Play</button>
              <button class="btn btn-danger" :disabled="busy" @click="removeFromFolder(group.id, video.id)">Remove</button>
            </div>
          </div>
        </article>
      </div>
    </section>

    <div v-if="createModal.open" class="overlay" @click.self="closeCreateModal">
      <div class="panel modal-card">
        <h3 class="modal-title">Create Folder</h3>
        <p class="modal-subtitle">Parent: <strong>{{ createModal.parentName || 'Root' }}</strong></p>
        <div class="form-stack">
          <input v-model="createModal.name" class="input" placeholder="Folder name" />
        </div>
        <div class="modal-actions">
          <button class="btn btn-secondary" :disabled="busy" @click="closeCreateModal">Cancel</button>
          <button class="btn btn-primary" :disabled="busy || !createModal.name.trim()" @click="submitCreateFolder">Create</button>
        </div>
      </div>
    </div>

    <div v-if="folderModal.open && folderModal.folder" class="overlay" @click.self="closeFolderModal">
      <div class="panel modal-card modal-wide">
        <h3 class="modal-title">Update Folder: {{ folderModal.folder.name }}</h3>

        <div class="folder-grid">
          <section class="form-stack">
            <label class="field-label">Rename</label>
            <input v-model="folderModal.rename" class="input" />
            <button class="btn btn-secondary" :disabled="busy || !folderModal.rename.trim()" @click="renameFolder">Save name</button>
          </section>

          <section class="form-stack">
            <label class="field-label">Move under</label>
            <select v-model="folderModal.moveParentId" class="input">
              <option value="">Root</option>
              <option v-for="opt in folderMoveOptions" :key="opt.id" :value="opt.id">{{ opt.label }}</option>
            </select>
            <button class="btn btn-secondary" :disabled="busy" @click="moveFolder">Move</button>
          </section>

          <section class="form-stack">
            <label class="field-label">Danger zone</label>
            <div class="control-spacer" aria-hidden="true" />
            <button class="btn btn-danger" :disabled="busy" @click="deleteFolder">Delete folder</button>
          </section>
        </div>

        <div class="divider" />

        <section class="form-stack folder-modal-block">
          <label class="field-label">Add saved favorite to folder</label>
          <div class="inline-row">
            <select v-model="folderModal.addVideoId" class="input">
              <option value="">Select favorite video</option>
              <option v-for="v in candidateFavorites" :key="v.id" :value="v.id">{{ v.title }}</option>
            </select>
            <button class="btn btn-primary" :disabled="busy || !folderModal.addVideoId" @click="addFavoriteToFolder">Add</button>
          </div>
        </section>

        <section class="form-stack folder-modal-block">
          <label class="field-label">Videos in folder</label>
          <div v-if="folderModal.videos.length === 0" class="folder-empty">No videos in folder.</div>
          <div v-else class="video-list">
            <article v-for="v in folderModal.videos" :key="v.video_id" class="video-row">
              <div>
                <strong>{{ v.title }}</strong>
                <small>{{ v.visibility }} · {{ v.status }}</small>
              </div>
              <div class="inline-row inline-row-tight">
                <select class="input small" @change="moveVideoFromFolder(v.video_id, $event.target.value)">
                  <option value="">Move to...</option>
                  <option v-for="opt in folderVideoMoveOptions" :key="opt.id" :value="opt.id">{{ opt.label }}</option>
                </select>
                <button class="btn btn-danger" :disabled="busy" @click="removeFromFolder(folderModal.folder.id, v.video_id)">Remove</button>
              </div>
            </article>
          </div>
        </section>

        <div class="modal-actions">
          <button class="btn btn-secondary" :disabled="busy" @click="closeFolderModal">Close</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import http from '../../lib/http'
import foldersService from '../../services/foldersService'

const router = useRouter()
const groups = ref([])
const foldersTree = ref([])
const allFavorites = ref([])
const loading = ref(true)
const busy = ref(false)
const errorText = ref('')
const dragOverFolderId = ref(null)
const dragState = ref({ videoId: null, fromFolderId: null })

const createModal = ref({ open: false, parentId: null, parentName: 'Root', name: '' })
const folderModal = ref({
  open: false,
  folder: null,
  rename: '',
  moveParentId: '',
  addVideoId: '',
  videos: []
})

const apiBase = (import.meta.env.VITE_API_BASE || 'http://localhost:8080').replace(/\/+$/, '')
const fallbackPoster = 'https://placehold.co/640x360?text=No+Poster'

const candidateFavorites = computed(() => {
  const map = new Map()
  allFavorites.value.forEach((v) => {
    map.set(v.id, { id: v.id, title: v.title || `Video ${v.id}` })
  })
  return Array.from(map.values())
})

const folderMoveOptions = computed(() => {
  const selected = folderModal.value.folder
  if (!selected) return []
  return foldersTree.value
    .filter((f) => {
      if (f.id === selected.id) return false
      if (!Array.isArray(f.path)) return true
      return !f.path.includes(selected.id)
    })
    .map((f) => ({ id: f.id, label: `${'  '.repeat(f.depth)}${f.name}` }))
})

const folderVideoMoveOptions = computed(() => {
  const selected = folderModal.value.folder
  if (!selected) return []
  return foldersTree.value
    .filter((f) => f.id !== selected.id)
    .map((f) => ({ id: f.id, label: `${'  '.repeat(f.depth)}${f.name}` }))
})

function posterUrl(video) {
  if (!video?.poster_key) return fallbackPoster
  if (String(video.poster_key).startsWith('http')) return video.poster_key
  const name = String(video.poster_key).split('/').pop()
  return `${apiBase}/stream/hls/${video.id}/${name}`
}

function goPlay(video) {
  router.push({ name: 'player', params: { id: video.id } })
}

function onVideoDragStart(video, group) {
  dragState.value = { videoId: video.id, fromFolderId: group.id }
}

function onVideoDragEnd() {
  dragOverFolderId.value = null
  dragState.value = { videoId: null, fromFolderId: null }
}

function onFolderDragOver(group, e) {
  if (!dragState.value.videoId) return
  dragOverFolderId.value = group.id
  if (e?.dataTransfer) e.dataTransfer.dropEffect = 'move'
}

function onFolderDragLeave(group) {
  if (dragOverFolderId.value === group.id) {
    dragOverFolderId.value = null
  }
}

async function onFolderDrop(group) {
  const videoID = dragState.value.videoId
  const fromFolderID = dragState.value.fromFolderId
  onVideoDragEnd()
  if (!videoID || !fromFolderID || fromFolderID === group.id) return
  busy.value = true
  errorText.value = ''
  try {
    await foldersService.moveVideo(fromFolderID, videoID, group.id)
    await loadFavorites()
  } catch (err) {
    errorText.value = err?.response?.data?.message || 'Move failed'
  } finally {
    busy.value = false
  }
}

function openCreateFolder(parentFolder) {
  createModal.value = {
    open: true,
    parentId: parentFolder?.id || null,
    parentName: parentFolder?.fullName || parentFolder?.name || 'Root',
    name: ''
  }
}

function closeCreateModal() {
  createModal.value = { open: false, parentId: null, parentName: 'Root', name: '' }
}

async function submitCreateFolder() {
  const name = createModal.value.name.trim()
  if (!name) return
  busy.value = true
  errorText.value = ''
  try {
    await foldersService.createFolder({
      type: 'favorites',
      name,
      parentId: createModal.value.parentId || null
    })
    closeCreateModal()
    await loadFavorites()
  } catch (err) {
    errorText.value = err?.response?.data?.message || 'Create folder failed'
  } finally {
    busy.value = false
  }
}

async function openFolderUpdate(folder) {
  folderModal.value = {
    open: true,
    folder,
    rename: folder.name,
    moveParentId: folder.parent_id || '',
    addVideoId: '',
    videos: []
  }
  await loadFolderModalVideos()
}

function closeFolderModal() {
  folderModal.value = {
    open: false,
    folder: null,
    rename: '',
    moveParentId: '',
    addVideoId: '',
    videos: []
  }
}

async function loadFolderModalVideos() {
  if (!folderModal.value.folder) return
  try {
    folderModal.value.videos = await foldersService.listFolderVideos(folderModal.value.folder.id, { limit: 300 })
  } catch (err) {
    errorText.value = err?.response?.data?.message || 'Failed to load folder videos'
  }
}

async function renameFolder() {
  const folder = folderModal.value.folder
  const name = folderModal.value.rename.trim()
  if (!folder || !name) return
  busy.value = true
  errorText.value = ''
  try {
    await foldersService.patchFolder(folder.id, { name })
    await loadFavorites()
  } catch (err) {
    errorText.value = err?.response?.data?.message || 'Rename failed'
  } finally {
    busy.value = false
  }
}

async function moveFolder() {
  const folder = folderModal.value.folder
  if (!folder) return
  busy.value = true
  errorText.value = ''
  try {
    await foldersService.patchFolder(folder.id, { parentId: folderModal.value.moveParentId || null })
    await loadFavorites()
  } catch (err) {
    errorText.value = err?.response?.data?.message || 'Move folder failed'
  } finally {
    busy.value = false
  }
}

async function deleteFolder() {
  const folder = folderModal.value.folder
  if (!folder) return
  if (!confirm(`Delete folder "${folder.name}"?`)) return
  busy.value = true
  errorText.value = ''
  try {
    await foldersService.deleteFolder(folder.id)
    closeFolderModal()
    await loadFavorites()
  } catch (err) {
    errorText.value = err?.response?.data?.message || 'Delete failed'
  } finally {
    busy.value = false
  }
}

async function addFavoriteToFolder() {
  const folder = folderModal.value.folder
  const videoID = folderModal.value.addVideoId
  if (!folder || !videoID) return
  busy.value = true
  errorText.value = ''
  try {
    await http.put(`/me/favorites/${videoID}`, { folderId: folder.id })
    folderModal.value.addVideoId = ''
    await Promise.all([loadFolderModalVideos(), loadFavorites()])
  } catch (err) {
    errorText.value = err?.response?.data?.message || 'Add favorite failed'
  } finally {
    busy.value = false
  }
}

async function removeFromFolder(folderId, videoId) {
  busy.value = true
  errorText.value = ''
  try {
    await http.delete(`/me/favorites/${videoId}`, { params: { folderId } })
    await Promise.all([loadFolderModalVideos(), loadFavorites()])
  } catch (err) {
    errorText.value = err?.response?.data?.message || 'Remove failed'
  } finally {
    busy.value = false
  }
}

async function moveVideoFromFolder(videoId, toFolderId) {
  const folder = folderModal.value.folder
  if (!folder || !toFolderId || folder.id === toFolderId) return
  busy.value = true
  errorText.value = ''
  try {
    await foldersService.moveVideo(folder.id, videoId, toFolderId)
    await Promise.all([loadFolderModalVideos(), loadFavorites()])
  } catch (err) {
    errorText.value = err?.response?.data?.message || 'Move failed'
  } finally {
    busy.value = false
  }
}

async function loadFavorites() {
  loading.value = true
  errorText.value = ''
  try {
    const [tree, favoritesRes] = await Promise.all([
      foldersService.listTree('favorites'),
      http.get('/me/favorites', { params: { limit: 400 } })
    ])

    foldersTree.value = tree
    allFavorites.value = (Array.isArray(favoritesRes.data?.items) ? favoritesRes.data.items : []).map((v) => ({
      ...v,
      id: v.video_id
    }))

    const nameById = new Map(tree.map((f) => [f.id, f.name]))
    const withItems = await Promise.all(
      tree.map(async (folder) => {
        const items = await foldersService.listFolderVideos(folder.id, { limit: 300 })
        const mapped = items.map((it) => ({
          ...it,
          id: it.video_id,
          title: it.title || `Video ${it.video_id}`
        }))
        const fullName = Array.isArray(folder.path)
          ? folder.path.map((id) => nameById.get(id) || id).join('/')
          : folder.name
        return { ...folder, fullName, items: mapped }
      })
    )
    groups.value = withItems

    if (folderModal.value.open && folderModal.value.folder) {
      const refreshed = tree.find((f) => f.id === folderModal.value.folder.id)
      if (refreshed) {
        folderModal.value.folder = refreshed
        folderModal.value.rename = refreshed.name
      }
    }
  } catch (err) {
    errorText.value = err?.response?.data?.message || 'Failed to load favorites'
    groups.value = []
  } finally {
    loading.value = false
  }
}

onMounted(loadFavorites)
</script>

<style scoped>
.favorites-view {
  width: 100%;
}

.gallery-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 12px;
  margin-bottom: 16px;
  position: sticky;
  top: 88px;
  z-index: 30;
  padding: 10px 0 12px;
  border-bottom: 1px solid var(--border);
  background:
    linear-gradient(
      to bottom,
      color-mix(in srgb, var(--panel) 96%, transparent) 0%,
      color-mix(in srgb, var(--panel) 84%, transparent) 72%,
      transparent 100%
    );
  backdrop-filter: blur(6px);
}

.subtitle {
  margin: 8px 0 0;
  color: var(--ui-fg-2);
}

.header-actions {
  display: flex;
  gap: 10px;
  flex-wrap: wrap;
}

.status {
  color: var(--ui-fg-2);
  padding: 10px 0;
}

.status-error {
  color: var(--text-error);
}

.folder-section {
  margin-bottom: 24px;
  border: 1px dashed transparent;
  border-radius: 12px;
  transition: border-color 0.2s, background-color 0.2s;
}

.folder-section.is-drop-target {
  border-color: var(--primary);
  background: rgba(80, 130, 255, 0.08);
}

.folder-header {
  margin: 0 0 10px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.folder-title {
  margin: 0;
  color: var(--ui-fg-1);
}

.folder-title small {
  color: var(--ui-fg-2);
}

.folder-actions {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}

.folder-empty {
  color: var(--ui-fg-2);
  padding: 8px 2px;
}

.gallery-grid {
  grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
  gap: 18px;
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
  left: 12px;
  bottom: 10px;
  padding: 4px 8px;
  border-radius: 999px;
  color: var(--text-on-accent);
  background: rgba(0, 0, 0, 0.55);
  border: 1px solid rgba(255, 255, 255, 0.12);
}

.video-body {
  padding: 12px 14px 14px;
}

.video-title {
  margin: 0 0 6px;
  font-size: 16px;
  color: var(--text-on-accent);
}

.video-desc {
  margin: 0 0 10px;
  color: var(--ui-fg-2);
  font-size: 13px;
}

.video-actions {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}

.overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.55);
  backdrop-filter: blur(2px);
  z-index: 200;
  display: grid;
  place-items: center;
  padding: 24px;
}

.modal-card {
  width: min(620px, calc(100vw - 32px));
  padding: 18px;
  border-radius: 14px;
}

.modal-wide {
  width: min(920px, calc(100vw - 32px));
}

.modal-title {
  margin: 0;
}

.modal-subtitle {
  margin: 6px 0 0;
  color: var(--ui-fg-2);
}

.form-stack {
  display: grid;
  gap: 10px;
}

.folder-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 12px;
  margin-top: 12px;
}

.control-spacer {
  height: 42px;
}

.inline-row {
  display: flex;
  align-items: center;
  gap: 8px;
}

.inline-row-tight {
  gap: 6px;
}

.small {
  min-width: 180px;
}

.video-list {
  display: grid;
  gap: 8px;
}

.video-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  border: 1px solid var(--border);
  border-radius: 10px;
  padding: 10px 12px;
}

.video-row small {
  display: block;
  color: var(--ui-fg-2);
}

.divider {
  height: 1px;
  background: var(--border);
  margin: 14px 0;
}

.folder-modal-block + .folder-modal-block {
  margin-top: 12px;
}

.modal-actions {
  display: flex;
  justify-content: flex-end;
  gap: 10px;
  margin-top: 14px;
}

@media (max-width: 1000px) {
  .gallery-header {
    flex-direction: column;
    position: static;
    top: auto;
    padding: 0;
    border-bottom: 0;
    background: transparent;
    backdrop-filter: none;
  }

  .header-actions {
    width: 100%;
  }

  .folder-grid {
    grid-template-columns: 1fr;
  }

  .video-row {
    flex-direction: column;
    align-items: flex-start;
    gap: 10px;
  }

  .inline-row {
    flex-direction: column;
    align-items: stretch;
  }

  .small {
    min-width: 100%;
  }
}
</style>
