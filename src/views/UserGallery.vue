<template>
  <div class="page panel gallery">
    <header class="gallery-header">
      <div>
        <h1 class="title">{{ pageTitle }}</h1>
        <p class="subtitle">{{ pageSubtitle }}</p>
      </div>
      <div class="header-actions">
        <button v-if="isManagedView" class="btn btn-secondary" @click="openCreateFolder(null)">＋ Create Root Folder</button>
        <button v-if="isManagedView" class="btn btn-primary btn-lg" @click="openQuickUpload(null)">⬆ Quick Upload</button>
        <button v-if="isManagedView" class="btn btn-secondary btn-lg" @click="goUpload">Open Upload Page</button>
      </div>
    </header>

    <div v-if="loading" class="status">{{ loadingText }}</div>
    <div v-else-if="!hasAnyVideos && folderGroups.length === 0" class="status status-empty">No videos available.</div>
    <div v-if="errorText" class="status status-error">{{ errorText }}</div>

    <template v-if="isGroupedView && folderGroups.length > 0">
      <section
        v-for="group in folderGroups"
        :key="group.id"
        class="folder-section"
        :class="{ 'is-drop-target': dragOverFolderId === group.id }"
        @dragover.prevent="onFolderDragOver(group, $event)"
        @dragleave="onFolderDragLeave(group)"
        @drop.prevent="onFolderDrop(group)"
      >
        <header class="folder-header" :style="{ paddingLeft: `${Math.max(0, group.depth) * 14}px` }">
          <h3 class="folder-title">
            {{ group.fullName || group.name }}
            <small>({{ group.items.length }})</small>
          </h3>
          <div v-if="canManageFolder(group)" class="folder-actions">
            <button class="btn btn-primary" @click="openQuickUpload(group)">Upload here</button>
            <button class="btn btn-secondary" @click="openCreateFolder(group)">Create folder</button>
            <button class="btn btn-secondary" @click="openFolderUpdate(group)">Update</button>
          </div>
        </header>

        <div v-if="group.items.length > 0" class="grid gallery-grid">
          <article
            v-for="video in group.items"
            :key="`${group.id}:${video.id}`"
            class="video-card"
            :draggable="isManagedView"
            @dragstart="onVideoDragStart(video, group)"
            @dragend="onVideoDragEnd"
          >
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
                <p class="video-desc">{{ videoMeta(video) }}</p>
              </template>

              <div class="video-actions">
                <button class="btn btn-primary" @click="goPlay(video)">▶ Play</button>
                <template v-if="canManage(video)">
                  <button
                    v-if="editingId !== video.id"
                    class="btn btn-secondary"
                    :disabled="busyVideoId === video.id"
                    @click="startEdit(video)"
                  >
                    ✎ Edit
                  </button>
                  <button v-else class="btn btn-secondary" :disabled="busyVideoId === video.id" @click="cancelEdit">Cancel</button>
                  <button
                    v-if="editingId === video.id"
                    class="btn btn-primary"
                    :disabled="busyVideoId === video.id"
                    @click="saveEdit(video)"
                  >
                    Save
                  </button>
                  <button
                    v-if="editingId !== video.id"
                    class="btn btn-secondary"
                    :disabled="busyVideoId === video.id || video.status !== 'ready'"
                    @click="togglePublish(video)"
                  >
                    {{ video.published_at ? 'Unpublish' : 'Publish' }}
                  </button>
                  <button class="btn btn-danger" :disabled="busyVideoId === video.id" @click="confirmDelete(video)">Delete</button>
                </template>
              </div>
            </div>
          </article>
        </div>

        <div v-else class="folder-empty">No videos in this folder yet.</div>
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
            <p class="video-desc">{{ videoMeta(video) }}</p>
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
              <button class="btn btn-danger" :disabled="busyVideoId === video.id" @click="confirmDelete(video)">Delete</button>
            </template>
          </div>
        </div>
      </article>
    </div>

    <div v-if="createModal.open" class="overlay" @click.self="closeCreateModal">
      <div class="panel modal-card">
        <h3 class="modal-title">Create Folder</h3>
        <p class="modal-subtitle">
          Parent: <strong>{{ createModal.parentName || 'Root' }}</strong>
        </p>
        <div class="form-stack create-folder-form">
          <input v-model="createModal.name" class="input" placeholder="Folder name" />
        </div>
        <div class="modal-actions">
          <button class="btn btn-secondary" :disabled="folderBusy" @click="closeCreateModal">Cancel</button>
          <button class="btn btn-primary" :disabled="folderBusy || !createModal.name.trim()" @click="submitCreateFolder">Create</button>
        </div>
      </div>
    </div>

    <div v-if="quickUpload.open" class="overlay" @click.self="closeQuickUpload">
      <div class="panel modal-card">
        <h3 class="modal-title">Quick Upload</h3>
        <p class="modal-subtitle">
          Target folder: <strong>{{ quickUpload.folderName || 'Unplaced' }}</strong>
        </p>
        <div class="form-stack">
          <label class="field-label">Title</label>
          <input v-model="quickUpload.title" class="input" placeholder="Video title" />

          <label class="field-label">Description</label>
          <textarea v-model="quickUpload.description" class="input edit-textarea" placeholder="Description" />

          <label class="field-label">Visibility</label>
          <select v-model="quickUpload.visibility" class="input">
            <option value="private">private</option>
            <option value="protected">protected</option>
            <option value="public">public</option>
          </select>

          <label class="field-label">File</label>
          <input class="input" type="file" accept="video/*" @change="onQuickFileChange" />
          <small v-if="quickUpload.fileName" class="hint">Selected: {{ quickUpload.fileName }}</small>
        </div>
        <div class="modal-actions">
          <button class="btn btn-secondary" :disabled="uploadBusy" @click="closeQuickUpload">Cancel</button>
          <button
            class="btn btn-primary"
            :disabled="uploadBusy || !quickUpload.title.trim() || !quickUpload.file"
            @click="submitQuickUpload"
          >
            {{ uploadBusy ? 'Uploading...' : 'Upload' }}
          </button>
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
            <button class="btn btn-secondary" :disabled="folderBusy || !folderModal.rename.trim()" @click="renameFolder">Save name</button>
          </section>

          <section class="form-stack">
            <label class="field-label">Move under</label>
            <select v-model="folderModal.moveParentId" class="input">
              <option value="">Root</option>
              <option v-for="opt in folderMoveOptions" :key="opt.id" :value="opt.id">{{ opt.label }}</option>
            </select>
            <button class="btn btn-secondary" :disabled="folderBusy" @click="moveFolder">Move</button>
          </section>

          <section class="form-stack">
            <label class="field-label">Danger zone</label>
            <div class="control-spacer" aria-hidden="true" />
            <button class="btn btn-danger" :disabled="folderBusy" @click="deleteFolder">Delete folder</button>
          </section>
        </div>

        <div class="divider" />

        <section class="form-stack folder-modal-block">
          <label class="field-label">Add video to folder</label>
          <div class="inline-row">
            <select v-model="folderModal.addVideoId" class="input">
              <option value="">Select video</option>
              <option v-for="v in candidateVideos" :key="v.id" :value="v.id">{{ v.title }}</option>
            </select>
            <button class="btn btn-primary" :disabled="folderBusy || !folderModal.addVideoId" @click="addVideoToFolder">Add</button>
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
                <button class="btn btn-danger" :disabled="folderBusy" @click="removeVideoFromFolder(v.video_id)">Remove</button>
              </div>
            </article>
          </div>
        </section>

        <div class="modal-actions">
          <button class="btn btn-secondary" :disabled="folderBusy" @click="closeFolderModal">Close</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed, onMounted, onUnmounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import foldersService from '../services/foldersService'
import videosService from '../services/videosService'
import usersService from '../services/usersService'

const props = defineProps({
  mode: {
    type: String,
    default: 'library' // 'library' | 'discover'
  }
})

const auth = useAuthStore()
const router = useRouter()

const videos = ref([])
const folderGroups = ref([])
const foldersTree = ref([])
const isGroupedView = ref(false)
const loading = ref(true)
const editingId = ref(null)
const editForm = ref({ title: '', description: '', visibility: 'private' })
const busyVideoId = ref(null)
const folderBusy = ref(false)
const uploadBusy = ref(false)
const errorText = ref('')
const dragOverFolderId = ref(null)
const dragState = ref({ videoId: null, fromFolderId: null })
const ownerNameByID = ref({})
let pollTimer = null

const createModal = ref({ open: false, parentId: null, parentName: 'Root', name: '' })
const quickUpload = ref({
  open: false,
  folderId: null,
  folderName: 'Unplaced',
  title: '',
  description: '',
  visibility: 'private',
  file: null,
  fileName: ''
})
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
const hasAnyVideos = computed(() => videos.value.length > 0 || folderGroups.value.some((g) => g.items.length > 0))
const isDiscoverView = computed(() => props.mode === 'discover')
const isManagedView = computed(() => props.mode === 'library' && auth.isAuthenticated)
const pageTitle = computed(() => (isDiscoverView.value ? 'Gallery' : 'Library & Videos'))
const pageSubtitle = computed(() =>
  isDiscoverView.value
    ? 'Public and accessible protected videos.'
    : 'Videos are grouped by folders, including nested structure and Unplaced.'
)
const loadingText = computed(() => (isDiscoverView.value ? 'Loading gallery…' : 'Loading your media…'))

const candidateVideos = computed(() => videos.value.map((v) => ({ id: v.id, title: v.title || `Video ${v.id}` })))

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

function videoMeta(video) {
  if (isDiscoverView.value) {
    const src = video?.source ? ` · ${video.source}` : ''
    const ownerID = String(video?.owner_id || '')
    const username = ownerNameByID.value[ownerID] || 'unknown'
    const owner = `Owner: @${username}`
    return `${owner}${src}`
  }
  return `Visibility: ${video.visibility} · Status: ${video.status} · ${video.published_at ? 'published' : 'unpublished'}`
}

async function resolveOwnerNames(items) {
  const ids = [...new Set((items || []).map((x) => String(x?.owner_id || '')).filter(Boolean))]
  const missing = ids.filter((id) => !ownerNameByID.value[id])
  if (missing.length === 0) return

  const loaded = await Promise.all(
    missing.map(async (id) => {
      try {
        const p = await usersService.getProfile(id)
        return [id, String(p?.username || '').trim() || null]
      } catch {
        return [id, null]
      }
    })
  )
  const next = { ...ownerNameByID.value }
  for (const [id, username] of loaded) next[id] = username || 'unknown'
  ownerNameByID.value = next
}

function canManage(video) {
  return isManagedView.value && !!video?.created_at
}

function canManageFolder(group) {
  return isManagedView.value && group.id !== 'unplaced'
}

function asFolderID(groupID) {
  return groupID === 'unplaced' ? null : groupID
}

function onVideoDragStart(video, group) {
  if (!isManagedView.value) return
  dragState.value = {
    videoId: video.id,
    fromFolderId: asFolderID(group.id)
  }
}

function onVideoDragEnd() {
  dragOverFolderId.value = null
  dragState.value = { videoId: null, fromFolderId: null }
}

function onFolderDragOver(group, e) {
  if (!isManagedView.value) return
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
  if (!isManagedView.value) return
  const videoID = dragState.value.videoId
  const fromFolderID = dragState.value.fromFolderId
  const toFolderID = asFolderID(group.id)
  onVideoDragEnd()
  if (!videoID) return
  if (fromFolderID === toFolderID) return

  folderBusy.value = true
  errorText.value = ''
  try {
    if (fromFolderID && toFolderID) {
      await foldersService.moveVideo(fromFolderID, videoID, toFolderID)
    } else if (!fromFolderID && toFolderID) {
      await foldersService.addVideo(toFolderID, videoID)
    } else if (fromFolderID && !toFolderID) {
      await foldersService.removeVideo(fromFolderID, videoID)
    }
    await loadVideos()
  } catch (err) {
    errorText.value = err?.response?.data?.message || 'Failed to move video'
  } finally {
    folderBusy.value = false
  }
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

async function buildFolderGroups(myVideos, tree) {
  const byId = new Map(myVideos.map((v) => [v.id, v]))
  const folderNameByID = new Map(tree.map((f) => [f.id, f.name]))

  const groups = await Promise.all(
    tree.map(async (folder) => {
      const items = await foldersService.listFolderVideos(folder.id, { limit: 300 })
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

  const placedIDs = new Set(groups.flatMap((g) => g.items.map((i) => i.id)))
  const unplaced = myVideos.filter((v) => !placedIDs.has(v.id))
  if (unplaced.length > 0 || groups.length > 0) {
    groups.unshift({
      id: 'unplaced',
      depth: 0,
      name: 'Unplaced',
      fullName: 'Unplaced',
      items: unplaced
    })
  }
  return groups
}

async function loadVideos() {
  loading.value = true
  errorText.value = ''
  try {
    if (isManagedView.value) {
      const [myVideos, tree] = await Promise.all([
        videosService.listMyVideos(300, 0),
        foldersService.listTree('library')
      ])
      videos.value = myVideos
      foldersTree.value = tree
      folderGroups.value = await buildFolderGroups(myVideos, tree)
      isGroupedView.value = folderGroups.value.length > 0
      if (folderModal.value.open && folderModal.value.folder) {
        const refreshed = tree.find((f) => f.id === folderModal.value.folder.id)
        if (refreshed) {
          folderModal.value.folder = refreshed
          folderModal.value.rename = refreshed.name
        }
      }
    } else {
      const items = await videosService.listCombined(200, 0, '48 hours')
      const mapped = items.map((v) => ({
        id: v.video_id,
        title: v.title,
        poster_key: v.poster_key,
        owner_id: v.owner_id,
        source: v.source,
        published_at: v.published_at,
        visibility: v.visibility || null,
        status: 'ready'
      }))
      await resolveOwnerNames(mapped)
      videos.value = mapped
      foldersTree.value = []
      folderGroups.value = []
      isGroupedView.value = false
    }
  } catch (err) {
    console.error('Gallery load error:', err)
    errorText.value = err?.response?.data?.message || 'Failed to load videos'
    videos.value = []
    folderGroups.value = []
  } finally {
    loading.value = false
    setupPolling()
  }
}

function openCreateFolder(parentFolder) {
  if (!isManagedView.value) return
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

function openQuickUpload(folder) {
  if (!isManagedView.value) return
  quickUpload.value = {
    open: true,
    folderId: folder?.id && folder.id !== 'unplaced' ? folder.id : null,
    folderName: folder?.fullName || folder?.name || 'Unplaced',
    title: '',
    description: '',
    visibility: 'private',
    file: null,
    fileName: ''
  }
}

function closeQuickUpload() {
  quickUpload.value = {
    open: false,
    folderId: null,
    folderName: 'Unplaced',
    title: '',
    description: '',
    visibility: 'private',
    file: null,
    fileName: ''
  }
}

function onQuickFileChange(e) {
  const file = e.target.files?.[0] || null
  quickUpload.value.file = file
  quickUpload.value.fileName = file?.name || ''
}

async function submitQuickUpload() {
  const title = quickUpload.value.title.trim()
  if (!title || !quickUpload.value.file) return
  uploadBusy.value = true
  errorText.value = ''
  try {
    const form = new FormData()
    form.append('title', title)
    form.append('description', quickUpload.value.description?.trim() || '')
    form.append('visibility', quickUpload.value.visibility || 'private')
    form.append('file', quickUpload.value.file)
    const created = await videosService.uploadVideo(form)
    const videoId = created?.videoId
    if (quickUpload.value.folderId && videoId) {
      await foldersService.addVideo(quickUpload.value.folderId, videoId)
    }
    closeQuickUpload()
    await loadVideos()
  } catch (err) {
    errorText.value = err?.response?.data?.message || 'Upload failed'
  } finally {
    uploadBusy.value = false
  }
}

async function submitCreateFolder() {
  const name = createModal.value.name.trim()
  if (!name) return
  folderBusy.value = true
  errorText.value = ''
  try {
    await foldersService.createFolder({
      type: 'library',
      name,
      parentId: createModal.value.parentId || null
    })
    closeCreateModal()
    await loadVideos()
  } catch (err) {
    errorText.value = err?.response?.data?.message || 'Create folder failed'
  } finally {
    folderBusy.value = false
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
  folderBusy.value = true
  errorText.value = ''
  try {
    await foldersService.patchFolder(folder.id, { name })
    await loadVideos()
  } catch (err) {
    errorText.value = err?.response?.data?.message || 'Rename failed'
  } finally {
    folderBusy.value = false
  }
}

async function moveFolder() {
  const folder = folderModal.value.folder
  if (!folder) return
  folderBusy.value = true
  errorText.value = ''
  try {
    await foldersService.patchFolder(folder.id, { parentId: folderModal.value.moveParentId || null })
    await loadVideos()
  } catch (err) {
    errorText.value = err?.response?.data?.message || 'Move folder failed'
  } finally {
    folderBusy.value = false
  }
}

async function deleteFolder() {
  const folder = folderModal.value.folder
  if (!folder) return
  if (!confirm(`Delete folder "${folder.name}"?`)) return
  folderBusy.value = true
  errorText.value = ''
  try {
    await foldersService.deleteFolder(folder.id)
    closeFolderModal()
    await loadVideos()
  } catch (err) {
    errorText.value = err?.response?.data?.message || 'Delete folder failed'
  } finally {
    folderBusy.value = false
  }
}

async function addVideoToFolder() {
  const folder = folderModal.value.folder
  if (!folder || !folderModal.value.addVideoId) return
  folderBusy.value = true
  errorText.value = ''
  try {
    await foldersService.addVideo(folder.id, folderModal.value.addVideoId)
    folderModal.value.addVideoId = ''
    await Promise.all([loadFolderModalVideos(), loadVideos()])
  } catch (err) {
    errorText.value = err?.response?.data?.message || 'Add video failed'
  } finally {
    folderBusy.value = false
  }
}

async function removeVideoFromFolder(videoId) {
  const folder = folderModal.value.folder
  if (!folder) return
  folderBusy.value = true
  errorText.value = ''
  try {
    await foldersService.removeVideo(folder.id, videoId)
    await Promise.all([loadFolderModalVideos(), loadVideos()])
  } catch (err) {
    errorText.value = err?.response?.data?.message || 'Remove video failed'
  } finally {
    folderBusy.value = false
  }
}

async function moveVideoFromFolder(videoId, toFolderId) {
  const folder = folderModal.value.folder
  if (!folder || !toFolderId || folder.id === toFolderId) return
  folderBusy.value = true
  errorText.value = ''
  try {
    await foldersService.moveVideo(folder.id, videoId, toFolderId)
    await Promise.all([loadFolderModalVideos(), loadVideos()])
  } catch (err) {
    errorText.value = err?.response?.data?.message || 'Move video failed'
  } finally {
    folderBusy.value = false
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
  align-items: flex-start;
  justify-content: space-between;
  gap: var(--space-4);
  margin-bottom: var(--space-5);
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
  justify-content: flex-end;
}

.status {
  text-align: center;
  font-size: 16px;
  color: var(--ui-fg-2);
  padding: var(--space-6) 0;
}

.status-empty {
  opacity: 0.7;
}

.status-error {
  color: var(--text-error);
  padding-top: 0;
}

.folder-section {
  margin-bottom: 28px;
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
  line-height: 1.35;
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
  padding: 10px 2px;
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
  color: var(--text-on-accent);
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
  color: var(--text-on-accent);
}

.video-desc {
  margin: 0 0 14px;
  font-size: 14px;
  color: var(--text-soft);
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

.create-folder-form {
  margin-top: 12px;
}

.hint {
  color: var(--ui-fg-2);
}

.folder-modal-block + .folder-modal-block {
  margin-top: 12px;
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
    justify-content: flex-start;
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
