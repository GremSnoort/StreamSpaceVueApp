<script setup>
import { computed, onMounted, ref } from 'vue'
import { useAuthStore } from '../../stores/auth'
import usersService from '../../services/usersService'

const auth = useAuthStore()

const loading = ref(true)
const busyUserId = ref('')
const profile = ref(null)
const following = ref([])
const followers = ref([])
const errorText = ref('')

const myUserId = computed(() => String(auth.user?.user_id || ''))
const followingSet = computed(() => new Set(following.value.map((u) => String(u.user_id))))

function isFollowingUser(userId) {
  return followingSet.value.has(String(userId))
}

async function loadAll() {
  loading.value = true
  errorText.value = ''
  try {
    const uid = myUserId.value
    if (!uid) {
      profile.value = null
      following.value = []
      followers.value = []
      return
    }

    const [p, fwing, fwers] = await Promise.all([
      usersService.getProfile(uid),
      usersService.listFollowing(200),
      usersService.listFollowers(200)
    ])

    profile.value = p || null
    following.value = fwing
    followers.value = fwers
  } catch (err) {
    errorText.value = err?.response?.data?.message || 'Failed to load subscriptions'
    profile.value = null
    following.value = []
    followers.value = []
  } finally {
    loading.value = false
  }
}

async function followUser(userId) {
  if (!userId) return
  busyUserId.value = String(userId)
  errorText.value = ''
  try {
    await usersService.follow(userId)
    await loadAll()
  } catch (err) {
    errorText.value = err?.response?.data?.message || 'Follow failed'
  } finally {
    busyUserId.value = ''
  }
}

async function unfollowUser(userId) {
  if (!userId) return
  busyUserId.value = String(userId)
  errorText.value = ''
  try {
    await usersService.unfollow(userId)
    await loadAll()
  } catch (err) {
    errorText.value = err?.response?.data?.message || 'Unfollow failed'
  } finally {
    busyUserId.value = ''
  }
}

onMounted(loadAll)
</script>

<template>
  <section class="profile">
    <header class="profile-header">
      <h1 class="profile-title">Profile & Subscriptions</h1>
      <p class="profile-subtitle">Manage your followers and following list.</p>
      <button class="btn btn-secondary" :disabled="loading" @click="loadAll">↻ Refresh</button>
    </header>

    <p v-if="errorText" class="error">{{ errorText }}</p>

    <div v-if="loading" class="muted">Loading profile…</div>

    <template v-else>
      <div v-if="profile" class="grid profile-grid">
        <article class="panel profile-card">
          <p><strong>Username:</strong> {{ profile.username }}</p>
          <p><strong>Display name:</strong> {{ profile.display_name || '—' }}</p>
          <p><strong>Bio:</strong> {{ profile.bio || '—' }}</p>
        </article>

        <article class="panel profile-card">
          <p><strong>Followers:</strong> {{ profile.followers_count ?? 0 }}</p>
          <p><strong>Following:</strong> {{ profile.following_count ?? 0 }}</p>
          <p><strong>Public videos:</strong> {{ profile.public_videos_count ?? 0 }}</p>
        </article>
      </div>

      <div class="grid subs-grid">
        <article class="panel subs-card">
          <h3>Following ({{ following.length }})</h3>
          <div v-if="following.length === 0" class="muted">You are not following anyone yet.</div>
          <div v-else class="subs-list">
            <div v-for="u in following" :key="`fwing:${u.user_id}`" class="subs-row">
              <div>
                <RouterLink class="user-link" :to="`/users/${u.user_id}`">@{{ u.username }}</RouterLink>
                <small>{{ u.display_name || '—' }}</small>
              </div>
              <button
                class="btn btn-secondary"
                :disabled="busyUserId === String(u.user_id)"
                @click="unfollowUser(u.user_id)"
              >
                Unfollow
              </button>
            </div>
          </div>
        </article>

        <article class="panel subs-card">
          <h3>Followers ({{ followers.length }})</h3>
          <div v-if="followers.length === 0" class="muted">No followers yet.</div>
          <div v-else class="subs-list">
            <div v-for="u in followers" :key="`fwers:${u.user_id}`" class="subs-row">
              <div>
                <RouterLink class="user-link" :to="`/users/${u.user_id}`">@{{ u.username }}</RouterLink>
                <small>{{ u.display_name || '—' }}</small>
              </div>
              <div class="row-actions">
                <button
                  v-if="!isFollowingUser(u.user_id)"
                  class="btn btn-primary"
                  :disabled="busyUserId === String(u.user_id) || myUserId === String(u.user_id)"
                  @click="followUser(u.user_id)"
                >
                  Follow back
                </button>
                <button
                  v-else
                  class="btn btn-secondary"
                  :disabled="busyUserId === String(u.user_id)"
                  @click="unfollowUser(u.user_id)"
                >
                  Unfollow
                </button>
              </div>
            </div>
          </div>
        </article>
      </div>
    </template>
  </section>
</template>

<style scoped>
.profile {
  padding: var(--space-6);
}

.profile-header {
  margin-bottom: var(--space-5);
  display: grid;
  gap: 8px;
}

.profile-title {
  margin: 0;
}

.profile-subtitle,
.muted {
  margin: 0;
  color: var(--muted);
}

.profile-grid {
  gap: 16px;
  grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
  margin-bottom: 16px;
}

.profile-card {
  padding: 16px;
}

.subs-grid {
  grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
  gap: 16px;
}

.subs-card {
  padding: 16px;
}

.subs-card h3 {
  margin: 0 0 12px;
}

.subs-list {
  display: grid;
  gap: 8px;
}

.subs-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  border: 1px solid var(--border);
  border-radius: 10px;
  padding: 10px 12px;
}

.subs-row small {
  display: block;
  color: var(--ui-fg-2);
}

.user-link {
  color: var(--ui-fg-1);
  text-decoration: none;
  font-weight: 700;
}

.user-link:hover {
  text-decoration: underline;
}

.row-actions {
  display: flex;
  gap: 8px;
}

.error {
  color: var(--text-error);
  margin: 0 0 12px;
}

@media (max-width: 760px) {
  .subs-row {
    flex-direction: column;
    align-items: flex-start;
  }
}
</style>
