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
  <div class="dashboard-layout">
    <!-- Sidebar -->
    <aside class="sidebar">
      <nav class="menu">
        <h2 class="logo">StreamSpace</h2>
        <RouterLink to="/dashboard/overview" class="menu-link" active-class="active">
          📊 Overview
        </RouterLink>

        <RouterLink to="/dashboard/videos" class="menu-link" active-class="active">
          🎞 My Videos
        </RouterLink>

        <RouterLink to="/dashboard/upload" class="menu-link" active-class="active">
          ⬆ Upload
        </RouterLink>

        <RouterLink to="/dashboard/profile" class="menu-link" active-class="active">
          👤 Profile
        </RouterLink>
      </nav>

      <!-- отдельный footer -->
      <div class="sidebar-footer">
        <button class="logout" @click="logout">Logout</button>
      </div>
    </aside>

    <!-- Content -->
    <main class="content">
      <header class="topbar" v-if="auth.user">
        Logged in as <span>{{ auth.user.email }}</span>
      </header>

      <section class="dashboard-page">
        <RouterView />
      </section>
    </main>
  </div>
</template>

<style scoped>
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;600&display=swap');

.dashboard-page {
  padding: 32px;
  flex: 1;
  overflow-y: auto;
}

.dashboard-layout {
  display: flex;
  background: #0a0a0a;
  color: white;
  font-family: Inter, sans-serif;
  flex: 1;
}

.sidebar {
  width: 240px;
  background: #111;
  padding: 30px 20px;
  border-right: 1px solid #1e1e1e;

  display: flex;
  flex-direction: column;
  flex-shrink: 0;
}

/* Footer */
.sidebar-footer {
  margin-top: auto;
  padding-top: 24px;
  border-top: 1px dashed #222;
  opacity: 0.85;
}

.logo::before {
  content: '▶';
  margin-right: 6px;
}

.logo {
  color: #44aaff;
  font-size: 22px;
  font-weight: 400;
  letter-spacing: 0.5px;
  margin-bottom: 30px;
}

/* Logout */
.logout {
  width: 100%;
  padding: 12px;
  border: 1px solid #ff4e4e;
  background: transparent;
  color: #ff6c6c;
  border-radius: 8px;
  cursor: pointer;
  transition: 0.25s;
}

.logout:hover {
  background: rgba(255, 78, 78, 0.12);
  box-shadow: 0 0 12px rgba(255, 80, 80, 0.5);
}

.content {
  flex: 1;
  display: flex;
  flex-direction: column;
}

.topbar {
  padding: 18px 26px;
  border-bottom: 1px solid #1e1e1e;
  color: #9fcff7;
}

.menu {
  display: flex;
  flex-direction: column;
  gap: 14px;

  overflow-y: auto;
  padding-right: 4px;
}

.menu-link {
  color: #bcdfff;
  text-decoration: none;
  padding: 10px;
  border-radius: 8px;
  transition: 0.25s;
  position: relative;
}

.menu-link.active::before {
  content: '';
  position: absolute;
  left: -6px;
  top: 0;
  bottom: 0;
  width: 4px;
  background: #1e90ff;
  border-radius: 4px;
}

.menu-link.active {
  background: linear-gradient(135deg, #1e90ff, #1450aa);
  color: #fff;
  box-shadow: 0 0 12px rgba(80, 150, 255, 0.4);
  transform: none;
}

.menu-link:hover {
  background: rgba(30, 144, 255, 0.12);
}

</style>
