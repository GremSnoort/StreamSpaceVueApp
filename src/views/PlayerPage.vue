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
        <div v-if="ownerProfile" class="owner-row">
          <RouterLink class="owner-link" :to="`/users/${ownerProfile.user_id}`">
            @{{ ownerProfile.username }}
          </RouterLink>
          <button
            v-if="isLoggedIn && !ownerProfile.is_me"
            class="btn"
            :class="ownerProfile.is_following ? 'btn-secondary' : 'btn-primary'"
            :disabled="ownerBusy"
            type="button"
            @click="toggleOwnerFollow"
          >
            {{ ownerProfile.is_following ? 'Unfollow' : 'Follow' }}
          </button>
        </div>

        <div class="meta-actions">
          <button
            class="btn"
            :class="reaction.myReaction === 'like' ? 'btn-primary' : 'btn-secondary'"
            type="button"
            @click="setReaction('like')"
          >
            👍 {{ reaction.likes }}
          </button>
          <button
            class="btn"
            :class="reaction.myReaction === 'dislike' ? 'btn-danger' : 'btn-secondary'"
            type="button"
            @click="setReaction('dislike')"
          >
            👎 {{ reaction.dislikes }}
          </button>
          <button
            class="btn"
            :class="favoriteSaved ? 'btn-primary' : 'btn-secondary'"
            type="button"
            @click="toggleFavorite"
          >
            {{ favoriteSaved ? '★ Saved' : '☆ Save to favorites' }}
          </button>
          <button class="btn btn-secondary" type="button" :disabled="downloadBusy" @click="startDownloadFlow">
            {{ downloadBusy ? 'Preparing download...' : '⬇ Download original' }}
          </button>
        </div>
        <p v-if="downloadInfo" class="download-info">{{ downloadInfo }}</p>

        <p v-if="socialError" class="social-error">{{ socialError }}</p>

        <div class="comments-box">
          <h3 class="comments-title">Comments ({{ comments.length }})</h3>
          <div v-if="socialLoading" class="comments-empty">Loading comments…</div>
          <div v-else-if="comments.length === 0" class="comments-empty">No comments yet</div>
          <div v-else class="comments-list">
            <article v-for="c in comments" :key="c.comment_id" class="comment-item">
              <div class="comment-head">
                <strong>{{ c.display_name || c.username }}</strong>
                <button
                  v-if="isLoggedIn && String(c.user_id) === String(auth.user?.user_id)"
                  class="btn btn-danger btn-sm"
                  type="button"
                  @click="deleteComment(c)"
                >
                  Delete
                </button>
              </div>
              <p class="comment-text">{{ c.text }}</p>
            </article>
          </div>

          <div class="comment-form">
            <textarea
              v-model="commentText"
              class="input"
              rows="3"
              :placeholder="isLoggedIn ? 'Write a comment…' : 'Login to comment'"
              :disabled="!isLoggedIn"
            />
            <button class="btn btn-primary" type="button" :disabled="!isLoggedIn || !commentText.trim()" @click="addComment">
              Add comment
            </button>
          </div>
        </div>
      </section>
    </div>

    <div v-if="favoriteModal.open" class="overlay" @click.self="closeFavoriteModal">
      <div class="panel modal-card">
        <h3 class="modal-title">Save to favorites</h3>
        <p class="modal-subtitle">Choose a folder or create a new one.</p>

        <div class="form-stack">
          <label class="field-label">Existing folder</label>
          <select v-model="favoriteModal.selectedFolderId" class="input" :disabled="favoriteModal.loading || favoriteModal.saving">
            <option value="">Default root</option>
            <option v-for="f in favoriteFolderOptions" :key="f.id" :value="f.id">{{ f.label }}</option>
          </select>

          <label class="field-label">Create new folder (optional)</label>
          <input
            v-model="favoriteModal.newFolderName"
            class="input"
            placeholder="New favorites folder name"
            :disabled="favoriteModal.loading || favoriteModal.saving"
          />
          <small class="hint">If provided, video will be saved to the new folder.</small>
        </div>

        <div class="modal-actions">
          <button class="btn btn-secondary" :disabled="favoriteModal.saving" @click="closeFavoriteModal">Cancel</button>
          <button class="btn btn-primary" :disabled="favoriteModal.loading || favoriteModal.saving" @click="saveFavoriteToFolder">
            {{ favoriteModal.saving ? 'Saving...' : 'Save' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import http from '../lib/http'
import VideoPlayer from '../components/VideoPlayer.vue'
import { useAuthStore } from '../stores/auth'
import foldersService from '../services/foldersService'
import usersService from '../services/usersService'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()

const id = route.params.id
const media = ref(null)
const loading = ref(true)
const manifestPath = ref('')
const downloadBusy = ref(false)
const downloadInfo = ref('')
const playerSize = ref('fixed')
const playerShell = ref(null)
const reaction = ref({ myReaction: null, likes: 0, dislikes: 0 })
const favoriteSaved = ref(false)
const comments = ref([])
const commentText = ref('')
const socialLoading = ref(false)
const socialError = ref('')
const ownerProfile = ref(null)
const ownerBusy = ref(false)
const favoriteModal = ref({
  open: false,
  loading: false,
  saving: false,
  folders: [],
  selectedFolderId: '',
  newFolderName: ''
})

const apiBase = (import.meta.env.VITE_API_BASE || 'http://localhost:8080').replace(/\/+$/, '')
const isLoggedIn = computed(() => !!auth.user)
const favoriteFolderOptions = computed(() => {
  const folders = favoriteModal.value.folders
  const nameByID = new Map(folders.map((f) => [f.id, f.name]))
  return folders.map((f) => {
    const fullName = Array.isArray(f.path) ? f.path.map((id) => nameByID.get(id) || id).join('/') : f.name
    return { id: f.id, label: fullName }
  })
})

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
    if (media.value?.owner_id) {
      try {
        ownerProfile.value = await usersService.getProfile(media.value.owner_id)
      } catch {
        ownerProfile.value = null
      }
    } else {
      ownerProfile.value = null
    }
  } catch (err) {
    console.error('Media load error:', err)
    media.value = null
    manifestPath.value = ''
    ownerProfile.value = null
  } finally {
    loading.value = false
  }
}

async function toggleOwnerFollow() {
  if (!isLoggedIn.value) {
    router.push({ name: 'login', query: { next: route.fullPath } })
    return
  }
  if (!ownerProfile.value || ownerProfile.value.is_me) return

  ownerBusy.value = true
  try {
    if (ownerProfile.value.is_following) {
      await usersService.unfollow(ownerProfile.value.user_id)
      ownerProfile.value.is_following = false
      ownerProfile.value.followers_count = Math.max(0, Number(ownerProfile.value.followers_count || 0) - 1)
    } else {
      await usersService.follow(ownerProfile.value.user_id)
      ownerProfile.value.is_following = true
      ownerProfile.value.followers_count = Number(ownerProfile.value.followers_count || 0) + 1
    }
  } catch (err) {
    alert(err?.response?.data?.message || 'Follow action failed')
  } finally {
    ownerBusy.value = false
  }
}

async function loadSocial() {
  socialLoading.value = true
  socialError.value = ''
  try {
    const [reactionRes, commentsRes] = await Promise.all([
      http.get(`/videos/${id}/reaction`),
      http.get(`/videos/${id}/comments`, { params: { limit: 100 } })
    ])
    reaction.value = {
      myReaction: reactionRes.data?.myReaction ?? null,
      likes: Number(reactionRes.data?.likes ?? 0),
      dislikes: Number(reactionRes.data?.dislikes ?? 0)
    }
    comments.value = Array.isArray(commentsRes.data?.items) ? commentsRes.data.items : []

    if (isLoggedIn.value) {
      try {
        const favRes = await http.get(`/me/favorites/${id}`)
        favoriteSaved.value = !!favRes.data?.saved
      } catch (favErr) {
        favoriteSaved.value = false
      }
    } else {
      favoriteSaved.value = false
    }
  } catch (err) {
    socialError.value = err?.response?.data?.message || 'Failed to load social data'
  } finally {
    socialLoading.value = false
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

async function tryIssueDownloadToken(purchaseId = null) {
  const payload = purchaseId ? { purchaseId } : {}
  const { data } = await http.post(`/videos/${id}/download-token`, payload)
  const token = data?.token
  if (!token) {
    throw new Error('Token not issued')
  }
  return token
}

async function findPaidPurchaseId() {
  const { data } = await http.get('/me/purchases', { params: { status: 'paid', limit: 100, offset: 0 } })
  const items = Array.isArray(data?.items) ? data.items : []
  const own = items.find((p) => String(p.video_id) === String(id))
  return own?.purchase_id || null
}

async function createDemoPurchase() {
  const { data } = await http.post(`/videos/${id}/purchase-download`, {
    provider: 'demo',
    providerPaymentId: `demo-${Date.now()}`,
    amountCents: 199,
    currency: 'USD'
  })
  return data?.purchaseId || null
}

function triggerDownload(url) {
  if (!url) return
  window.location.assign(url)
}

async function getDownloadUrl(token = '') {
  const params = {}
  if (token) params.token = token
  const { data } = await http.get(`/videos/${id}/download`, { params })
  const rel = data?.downloadUrl || `/videos/${id}/download?mode=file${token ? `&token=${encodeURIComponent(token)}` : ''}`
  return absUrl(rel)
}

async function startDownloadFlow() {
  if (!isLoggedIn.value) {
    alert('Login is required')
    return
  }

  downloadBusy.value = true
  downloadInfo.value = ''
  try {
    try {
      const directUrl = await getDownloadUrl()
      triggerDownload(directUrl)
      downloadInfo.value = 'Download started.'
      return
    } catch (_directErr) {
      // continue with purchase flow
    }

    let purchaseId = await findPaidPurchaseId()
    if (!purchaseId) {
      purchaseId = await createDemoPurchase()
      if (!purchaseId) throw new Error('Purchase was not created')
    }

    try {
      const purchasedUrl = await getDownloadUrl()
      triggerDownload(purchasedUrl)
      downloadInfo.value = 'Download started via purchase flow.'
      return
    } catch (_purchasedErr) {
      // Fallback for strict token-only mode
    }

    const token = await tryIssueDownloadToken(purchaseId)
    const tokenUrl = await getDownloadUrl(token)
    triggerDownload(tokenUrl)
    downloadInfo.value = 'Download started via purchase flow.'
  } catch (err) {
    downloadInfo.value = ''
    alert(err?.response?.data?.message || err?.message || 'Download failed')
  } finally {
    downloadBusy.value = false
  }
}

async function setReaction(value) {
  if (!isLoggedIn.value) {
    alert('Login is required')
    return
  }
  try {
    const next = reaction.value.myReaction === value ? 'none' : value
    await http.put(`/videos/${id}/reaction`, { value: next })
    await loadSocial()
  } catch (err) {
    alert(err?.response?.data?.message || 'Reaction failed')
  }
}

async function toggleFavorite() {
  if (!isLoggedIn.value) {
    alert('Login is required')
    return
  }
  try {
    if (favoriteSaved.value) {
      await http.delete(`/me/favorites/${id}`)
      favoriteSaved.value = false
    } else {
      await openFavoriteModal()
    }
  } catch (err) {
    alert(err?.response?.data?.message || 'Favorite action failed')
  }
}

async function openFavoriteModal() {
  favoriteModal.value.open = true
  favoriteModal.value.loading = true
  favoriteModal.value.newFolderName = ''
  favoriteModal.value.selectedFolderId = ''
  try {
    const folders = await foldersService.listTree('favorites')
    favoriteModal.value.folders = folders
    favoriteModal.value.selectedFolderId = folders[0]?.id || ''
  } catch (err) {
    favoriteModal.value.folders = []
  } finally {
    favoriteModal.value.loading = false
  }
}

function closeFavoriteModal() {
  favoriteModal.value = {
    open: false,
    loading: false,
    saving: false,
    folders: [],
    selectedFolderId: '',
    newFolderName: ''
  }
}

async function saveFavoriteToFolder() {
  favoriteModal.value.saving = true
  try {
    let folderID = favoriteModal.value.selectedFolderId || null
    const newName = favoriteModal.value.newFolderName.trim()
    if (newName) {
      const created = await foldersService.createFolder({
        type: 'favorites',
        name: newName,
        parentId: null
      })
      folderID = created?.folderId || folderID
    }
    await http.put(`/me/favorites/${id}`, folderID ? { folderId: folderID } : {})
    favoriteSaved.value = true
    closeFavoriteModal()
  } catch (err) {
    alert(err?.response?.data?.message || 'Favorite action failed')
  } finally {
    favoriteModal.value.saving = false
  }
}

async function addComment() {
  if (!isLoggedIn.value) {
    alert('Login is required')
    return
  }
  const text = commentText.value.trim()
  if (!text) return
  try {
    await http.post(`/videos/${id}/comments`, { text })
    commentText.value = ''
    await loadSocial()
  } catch (err) {
    alert(err?.response?.data?.message || 'Comment failed')
  }
}

async function deleteComment(comment) {
  if (!isLoggedIn.value) return
  const me = auth.user?.user_id
  if (!me || String(comment.user_id) !== String(me)) {
    alert('You can delete only your own comments')
    return
  }
  try {
    await http.delete(`/videos/${id}/comments/${comment.comment_id}`)
    await loadSocial()
  } catch (err) {
    alert(err?.response?.data?.message || 'Delete comment failed')
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

onMounted(async () => {
  await loadMedia()
  await loadSocial()
})
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
  color: var(--text-hero);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

/* states */
.status {
  text-align: center;
  font-size: 16px;
  color: var(--text-soft-strong);
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
  color: var(--text-on-accent);
}

.meta-desc {
  margin: 0;
  color: var(--text-soft);
  line-height: 1.45;
}

.owner-row {
  margin-top: 10px;
  display: flex;
  align-items: center;
  gap: 10px;
}

.owner-link {
  color: var(--ui-fg-1);
  text-decoration: none;
  font-weight: 700;
}

.owner-link:hover {
  text-decoration: underline;
}

.meta-actions {
  margin-top: 14px;
  display: flex;
  gap: 10px;
  flex-wrap: wrap;
}

.social-error {
  margin: 10px 0 0;
  color: var(--text-error);
}

.download-info {
  margin: 8px 0 0;
  color: var(--ui-fg-2);
}

.comments-box {
  margin-top: 16px;
  border-top: 1px solid var(--border);
  padding-top: 14px;
}

.comments-title {
  margin: 0 0 10px;
  color: var(--ui-fg-1);
}

.comments-empty {
  color: var(--ui-fg-2);
}

.comments-list {
  display: grid;
  gap: 10px;
}

.comment-item {
  border: 1px solid var(--border);
  border-radius: 10px;
  padding: 10px;
  background: rgba(255, 255, 255, 0.02);
}

.comment-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
}

.comment-text {
  margin: 8px 0 0;
  color: var(--ui-fg-1);
  white-space: pre-wrap;
}

.comment-form {
  margin-top: 12px;
  display: grid;
  gap: 10px;
}

.btn-sm {
  padding: 6px 10px;
  font-size: 12px;
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
  width: min(560px, calc(100vw - 32px));
  padding: 18px;
  border-radius: 14px;
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
  margin-top: 12px;
}

.hint {
  color: var(--ui-fg-2);
}

.modal-actions {
  margin-top: 14px;
  display: flex;
  justify-content: flex-end;
  gap: 10px;
}

@media (max-width: 900px) {
  .player-shell,
  .player-shell.is-half {
    width: 100%;
  }
}
</style>
