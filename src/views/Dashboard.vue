<script setup>
import { watch } from 'vue'
import { useAuthStore } from '../stores/auth'
import { useRouter } from 'vue-router'

const auth = useAuthStore()
const router = useRouter()

function logout() {
  auth.logout()
  router.replace('/login')
}

watch(
  () => auth.user,
  (u) => {
    if (!u) router.replace('/login')
  },
  { immediate: true }
)
</script>

<template>
  <div class="dash">
    <!-- Sidebar -->
    <aside class="panel dash-sidebar">
      <nav class="dash-menu">
        <h2 class="dash-logo">StreamSpace</h2>

        <RouterLink to="/dashboard/overview" class="dash-link" active-class="is-active">
          📊 Overview
        </RouterLink>

        <RouterLink to="/dashboard/videos" class="dash-link" active-class="is-active">
          🎞 My Videos
        </RouterLink>

        <RouterLink to="/dashboard/library" class="dash-link" active-class="is-active">
          🗂 Library
        </RouterLink>

        <RouterLink to="/dashboard/favorites" class="dash-link" active-class="is-active">
          ⭐ Favorites
        </RouterLink>

        <RouterLink to="/dashboard/upload" class="dash-link" active-class="is-active">
          ⬆ Upload
        </RouterLink>

        <RouterLink to="/dashboard/profile" class="dash-link" active-class="is-active">
          👤 Profile
        </RouterLink>

      </nav>

      <div class="dash-footer">
        <button class="btn btn-secondary btn-wide" @click="logout">
          Logout
        </button>
      </div>
    </aside>

    <!-- Content -->
    <main class="dash-content">
      <header v-if="auth.user" class="dash-topbar">
        Logged in as <span class="dash-user">{{ auth.user.email }}</span>
      </header>

      <section class="page dash-page">
        <RouterView />
      </section>
    </main>
  </div>
</template>

<style scoped>
/* layout only */
.dash {
  min-height: calc(100vh - 80px);
  display: flex;
  width: 100%;
}

/* sidebar uses design-system panel */
.dash-sidebar {
  width: 240px;
  flex-shrink: 0;
  padding: var(--space-6) var(--space-5);
  display: flex;
  flex-direction: column;
  border-right: 1px solid var(--border);
  border-radius: 0; /* чтобы стык с контентом был ровный (если хочешь) */
}

.dash-menu {
  display: grid;
  gap: 12px;
}

.dash-logo {
  margin: 0 0 var(--space-5);
  font-size: 20px;
  font-weight: 800;
  letter-spacing: 0.2px;
  color: var(--title-grad-1);
}

.dash-logo::before {
  content: '▶';
  margin-right: 8px;
  opacity: 0.9;
}

.dash-link {
  position: relative;
  text-decoration: none;
  color: var(--nav-link);
  padding: 10px 12px;
  border-radius: var(--r-md);
  transition: background 0.2s, color 0.2s, transform 0.2s;
}

.dash-link:hover {
  background: rgba(255, 255, 255, 0.06);
}

.dash-link.is-active {
  color: #fff;
  background: linear-gradient(90deg, var(--primary), var(--primary-2));
  box-shadow: var(--shadow-md);
}

.dash-link.is-active::before {
  content: '';
  position: absolute;
  left: -10px;
  top: 8px;
  bottom: 8px;
  width: 4px;
  border-radius: 4px;
  background: linear-gradient(180deg, var(--primary), var(--primary-2));
}

.dash-footer {
  margin-top: auto;
  padding-top: var(--space-5);
  border-top: 1px dashed rgba(255, 255, 255, 0.10);
}

/* content */
.dash-content {
  flex: 1;
  display: flex;
  flex-direction: column;
  min-width: 0;
}

.dash-topbar {
  padding: 16px 22px;
  border-bottom: 1px solid var(--border);
  color: var(--ui-fg-2);
}

.dash-user {
  font-weight: 800;
  color: var(--ui-fg-1);
}

/* page spacing inside dashboard */
.dash-page {
  padding-top: var(--space-6);
  padding-bottom: var(--space-6);
}

/* responsive */
@media (max-width: 900px) {
  .dash {
    flex-direction: column;
  }

  .dash-sidebar {
    width: 100%;
    border-right: none;
    border-bottom: 1px solid var(--border);
  }

  .dash-link.is-active::before {
    left: 0;
  }
}
</style>
