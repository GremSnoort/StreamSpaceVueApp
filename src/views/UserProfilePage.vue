<script setup>
import { computed, onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import usersService from '../services/usersService'
import videosService from '../services/videosService'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()

const loading = ref(true)
const busy = ref(false)
const profile = ref(null)
const errorText = ref('')
const galleryLoading = ref(false)
const userVideos = ref([])

const apiBase = (import.meta.env.VITE_API_BASE || 'http://localhost:8080').replace(/\/+$/, '')
const fallbackPoster = 'https://placehold.co/640x360?text=No+Poster'

const userId = computed(() => String(route.params.id || ''))
const isLoggedIn = computed(() => !!auth.user)

async function loadProfile() {
  loading.value = true
  errorText.value = ''
  try {
    profile.value = await usersService.getProfile(userId.value)
  } catch (err) {
    profile.value = null
    errorText.value = err?.response?.data?.message || 'Failed to load user profile'
  } finally {
    loading.value = false
  }
}

async function loadUserGallery() {
  galleryLoading.value = true
  try {
    const items = await videosService.listUserVideos(userId.value, 200, 0)
    userVideos.value = items
  } catch (err) {
    userVideos.value = []
  } finally {
    galleryLoading.value = false
  }
}

function posterUrl(video) {
  if (!video?.poster_key) return fallbackPoster
  if (String(video.poster_key).startsWith('http')) return video.poster_key
  const name = String(video.poster_key).split('/').pop()
  return `${apiBase}/stream/hls/${video.id}/${name}`
}

function goPlay(videoId) {
  router.push({ name: 'player', params: { id: videoId } })
}

async function toggleFollow() {
  if (!isLoggedIn.value) {
    router.push({ name: 'login', query: { next: route.fullPath } })
    return
  }
  if (!profile.value || profile.value.is_me) return

  busy.value = true
  errorText.value = ''
  try {
    if (profile.value.is_following) {
      await usersService.unfollow(profile.value.user_id)
      profile.value.is_following = false
      profile.value.followers_count = Math.max(0, Number(profile.value.followers_count || 0) - 1)
    } else {
      await usersService.follow(profile.value.user_id)
      profile.value.is_following = true
      profile.value.followers_count = Number(profile.value.followers_count || 0) + 1
    }
  } catch (err) {
    errorText.value = err?.response?.data?.message || 'Follow action failed'
  } finally {
    busy.value = false
  }
}

watch(userId, async () => {
  await Promise.all([loadProfile(), loadUserGallery()])
})
onMounted(async () => {
  await Promise.all([loadProfile(), loadUserGallery()])
})
</script>

<template>
  <section class="page panel user-profile">
    <header class="user-header">
      <button class="btn btn-secondary" @click="router.back()">← Back</button>
      <h1 class="title">User Profile</h1>
    </header>

    <p v-if="errorText" class="error">{{ errorText }}</p>
    <div v-if="loading" class="muted">Loading…</div>

    <div v-else-if="!profile" class="muted">Profile is unavailable.</div>

    <div v-else class="grid info-grid">
      <article class="panel info-card">
        <p><strong>Username:</strong> @{{ profile.username }}</p>
        <p><strong>Display name:</strong> {{ profile.display_name || '—' }}</p>
        <p><strong>Bio:</strong> {{ profile.bio || '—' }}</p>
        <p><strong>Joined:</strong> {{ profile.created_at ? new Date(profile.created_at).toLocaleDateString() : '—' }}</p>
      </article>

      <article class="panel info-card">
        <p><strong>Followers:</strong> {{ profile.followers_count ?? 0 }}</p>
        <p><strong>Following:</strong> {{ profile.following_count ?? 0 }}</p>
        <p><strong>Public videos:</strong> {{ profile.public_videos_count ?? 0 }}</p>

        <div class="actions" v-if="!profile.is_me">
          <button class="btn" :class="profile.is_following ? 'btn-secondary' : 'btn-primary'" :disabled="busy" @click="toggleFollow">
            {{ profile.is_following ? 'Unfollow' : 'Follow' }}
          </button>
        </div>
      </article>
    </div>

    <section class="panel gallery-card">
      <header class="gallery-header">
        <h2>User Gallery</h2>
      </header>
      <div v-if="galleryLoading" class="muted">Loading videos…</div>
      <div v-else-if="userVideos.length === 0" class="muted">No visible videos.</div>
      <div v-else class="grid gallery-grid">
        <article v-for="v in userVideos" :key="v.id" class="video-card">
          <button class="thumb" type="button" @click="goPlay(v.id)">
            <img class="thumb-img" :src="posterUrl(v)" alt="Preview" loading="lazy" />
            <span class="thumb-play">▶</span>
          </button>
          <div class="video-body">
            <h3 class="video-title">{{ v.title }}</h3>
            <p class="video-meta">{{ v.visibility }} · {{ v.status }}</p>
          </div>
        </article>
      </div>
    </section>
  </section>
</template>

<style scoped>
.user-profile {
  padding: 24px;
}

.user-header {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 12px;
}

.user-header .title {
  margin: 0;
  line-height: 1.1;
}

.info-grid {
  gap: 16px;
  grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
}

.info-card {
  padding: 16px;
}

.actions {
  margin-top: 10px;
}

.gallery-card {
  margin-top: 16px;
  padding: 16px;
}

.gallery-header h2 {
  margin: 0 0 12px;
}

.gallery-grid {
  grid-template-columns: repeat(auto-fill, minmax(240px, 1fr));
  gap: 12px;
}

.video-card {
  border: 1px solid var(--border);
  border-radius: 10px;
  overflow: hidden;
  background: rgba(255, 255, 255, 0.02);
}

.thumb {
  width: 100%;
  border: 0;
  padding: 0;
  display: block;
  background: #000;
  position: relative;
  cursor: pointer;
}

.thumb-img {
  width: 100%;
  aspect-ratio: 16 / 9;
  object-fit: cover;
  display: block;
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
  padding: 10px 12px;
}

.video-title {
  margin: 0 0 6px;
  font-size: 15px;
  color: var(--ui-fg-1);
}

.video-meta {
  margin: 0;
  font-size: 12px;
  color: var(--ui-fg-2);
}

.muted {
  color: var(--ui-fg-2);
}

.error {
  color: var(--text-error);
}
</style>
