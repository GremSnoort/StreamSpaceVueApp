<script setup>
import { useAuthStore } from '../stores/auth'
import { useRouter } from 'vue-router'

const auth = useAuthStore()
const router = useRouter()

function logout() {
  auth.logout()
  router.push('/login')
}
</script>

<template>
  <div class="dashboard-page">
    <div class="dash-card">
      <h1 class="title">Dashboard</h1>

      <p class="welcome">
        Logged in as:
        <span class="email">{{ auth.user?.email }}</span>
      </p>

      <button class="btn logout" @click="logout">Logout</button>
    </div>
  </div>
</template>

<style scoped>
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;600&display=swap');

.dashboard-page {
  height: 100vh;
  width: 100vw;
  background: #0a0a0a;
  display: flex;
  justify-content: center;
  align-items: center;
  font-family: 'Inter', sans-serif;
}

.dash-card {
  background: #111;
  padding: 40px 50px;
  border-radius: 18px;
  width: 420px;
  text-align: center;
  border: 1px solid #0c4d8a;
  box-shadow: 0 0 35px rgba(0, 140, 255, 0.25);
}

/* Title */
.title {
  color: #44aaff;
  font-size: 32px;
  font-weight: 600;
  margin-bottom: 20px;
}

/* Welcome text */
.welcome {
  color: #9fcff7;
  font-size: 16px;
  margin-bottom: 35px;
}

.email {
  color: #66c9ff;
  font-weight: 600;
}

/* Logout button */
.btn.logout {
  padding: 12px 26px;
  font-size: 16px;
  font-weight: 600;
  background: transparent;
  border-radius: 10px;
  border: 2px solid #ff4e4e;
  color: #ff6c6c;
  cursor: pointer;
  transition: 0.25s;
}

.btn.logout:hover {
  background: rgba(255, 70, 70, 0.15);
  box-shadow: 0 0 12px rgba(255, 80, 80, 0.6);
}
</style>
