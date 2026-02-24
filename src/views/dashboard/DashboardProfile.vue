<script setup>
import { onMounted, ref } from 'vue'
import { useAuthStore } from '../../stores/auth'
import http from '../../lib/http'

const auth = useAuthStore()
const loading = ref(true)
const profile = ref(null)

onMounted(async () => {
  loading.value = true
  try {
    if (!auth.user?.user_id) {
      profile.value = null
      return
    }
    const { data } = await http.get(`/users/${auth.user.user_id}`)
    profile.value = data || null
  } catch (err) {
    console.error('Profile load failed', err)
    profile.value = null
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <section class="profile">
    <header class="profile-header">
      <h1 class="profile-title">Profile</h1>
      <p class="profile-subtitle">Account and public counters</p>
    </header>

    <div v-if="loading" class="muted">Loading profile…</div>

    <div v-else-if="!profile" class="muted">Profile is unavailable.</div>

    <div v-else class="grid profile-grid">
      <article class="panel profile-card">
        <p><strong>Username:</strong> {{ profile.username }}</p>
        <p><strong>Display name:</strong> {{ profile.display_name || '—' }}</p>
        <p><strong>Bio:</strong> {{ profile.bio || '—' }}</p>
      </article>

      <article class="panel profile-card">
        <p><strong>Followers:</strong> {{ profile.followers_count ?? 0 }}</p>
        <p><strong>Following:</strong> {{ profile.following_count ?? 0 }}</p>
      </article>
    </div>
  </section>
</template>

<style scoped>
.profile {
  padding: var(--space-6);
}

.profile-header {
  margin-bottom: var(--space-5);
}

.profile-title {
  margin: 0 0 6px;
}

.profile-subtitle,
.muted {
  margin: 0;
  color: var(--muted);
}

.profile-grid {
  gap: 16px;
  grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
}

.profile-card {
  padding: 16px;
}
</style>
