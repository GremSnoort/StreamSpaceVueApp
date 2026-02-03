<script setup>
import { ref, onMounted, onUnmounted, computed } from 'vue'
import { useAuthStore } from './stores/auth'
import { useTheme } from '@/composables/useTheme'

const auth = useAuthStore()
const { theme,
    themes,
    toggle,
    setTheme } = useTheme()

const menuOpen = ref(false)
const hidden = ref(false)
let lastScrollY = window.scrollY

function toggleMenu() {
  menuOpen.value = !menuOpen.value
}

function closeMenu() {
  menuOpen.value = false
}

function logout() {
  auth.logout()
  closeMenu()
}

// SCROLL EVENT: hide on scroll down, show on scroll up
function onScroll() {
  const currentScrollY = window.scrollY
  hidden.value = currentScrollY > lastScrollY && currentScrollY > 100
  lastScrollY = currentScrollY
}

onMounted(() => {
  window.addEventListener('scroll', onScroll)
})

onUnmounted(() => {
  window.removeEventListener('scroll', onScroll)
})

// CHECK AUTH STATE
const isLoggedIn = computed(() => !!auth.user)
</script>

<template>
  <div>
    <nav :class="['navbar', { hidden }]">
      <div class="logo">StreamSpace</div>

      <button class="btn btn-primary" @click="toggle">
        🎨 {{ theme }}
      </button>

      <!-- Links -->
      <div :class="['links', { open: menuOpen }]">

        <router-link @click="closeMenu" to="/" class="nav-link">Home</router-link>

        <router-link
          v-if="isLoggedIn"
          @click="closeMenu"
          to="/gallery"
          class="nav-link"
        >
          Gallery
        </router-link>

        <router-link
          v-if="isLoggedIn"
          @click="closeMenu"
          to="/dashboard"
          class="nav-link"
        >
          Dashboard
        </router-link>

        <router-link
          v-if="!isLoggedIn"
          @click="closeMenu"
          to="/login"
          class="nav-link"
        >
          Login
        </router-link>

        <router-link
          v-if="!isLoggedIn"
          @click="closeMenu"
          to="/register"
          class="nav-link"
        >
          Register
        </router-link>

        <button
          v-if="isLoggedIn"
          class="nav-link"
          style="background:none;border:none;cursor:pointer"
          @click="logout"
        >
          Logout
        </button>
      </div>

      <!-- Hamburger -->
      <div class="hamburger" @click="toggleMenu">
        <span :class="{ open: menuOpen }"></span>
        <span :class="{ open: menuOpen }"></span>
        <span :class="{ open: menuOpen }"></span>
      </div>
    </nav>

    <main class="page-content">
      <router-view />
    </main>
  </div>
</template>
