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
    <aside class="dash-sidebar">
      <nav class="dash-menu">
        <h2 class="dash-logo">StreamSpace</h2>

        <RouterLink to="/dashboard/overview" class="dash-link" active-class="is-active">
          📊 Overview
        </RouterLink>

        <RouterLink to="/dashboard/videos" class="dash-link" active-class="is-active">
          🎞 My Videos
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

      <!-- центрируем как PageLayout, но внутри dashboard -->
      <section class="page dash-page">
        <RouterView />
      </section>
    </main>
  </div>
</template>

<style scoped>
/* layout */
.dash {
  min-height: calc(100vh - 80px); /* navbar fixed */
  display: flex;
  width: 100%;
}

/* sidebar */
.dash-sidebar {
  width: 240px;
  flex-shrink: 0;
  border-right: 1px solid var(--border);
  background: linear-gradient(145deg, var(--panel), var(--panel-2));
  padding: var(--space-6) var(--space-5);
  display: flex;
  flex-direction: column;
}

.dash-menu {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.dash-logo {
  margin: 0 0 var(--space-5);
  font-size: 20px;
  font-weight: 700;
  color: #44aaff;
  letter-spacing: 0.4px;
}

.dash-logo::before {
  content: '▶';
  margin-right: 8px;
  opacity: 0.9;
}

.dash-link {
  position: relative;
  text-decoration: none;
  color: #bcdfff;
  padding: 10px 12px;
  border-radius: var(--r-md);
  transition: 0.2s;
}

.dash-link:hover {
  background: rgba(30, 144, 255, 0.12);
}

.dash-link.is-active {
  background: linear-gradient(135deg, rgba(79, 138, 255, 0.9), rgba(48, 109, 255, 0.65));
  color: #fff;
  box-shadow: var(--shadow-blue);
}

.dash-link.is-active::before {
  content: '';
  position: absolute;
  left: -10px;
  top: 8px;
  bottom: 8px;
  width: 4px;
  border-radius: 4px;
  background: rgba(79, 138, 255, 0.9);
}

/* footer */
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
  color: var(--muted);
}

.dash-user {
  font-weight: 700;
  color: #cfe8ff;
}

/* center page content */
.dash-page {
  padding-top: var(--space-6);
  padding-bottom: var(--space-6);
}

/* responsive: sidebar goes top */
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
