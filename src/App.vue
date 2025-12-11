<script setup>
import { ref, onMounted, onUnmounted, computed } from 'vue'
import { useAuthStore } from './stores/auth'

const auth = useAuthStore()

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

<style>
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;600&display=swap');

body {
  margin: 0;
  padding: 0;
  background: #0a0a0a;
  font-family: 'Inter', sans-serif;
}

/* NAVBAR */
.navbar {
  width: 100%;
  background: #0d0d0d;
  border-bottom: 1px solid #0c4d8a;
  box-shadow: 0 0 15px rgba(0, 140, 255, 0.2);
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0.5rem 1rem;
  position: fixed;
  top: 0;
  left: 0;
  z-index: 50;
  flex-wrap: wrap;
  box-sizing: border-box;
  transition: transform 0.3s ease, box-shadow 0.3s ease;
}

.navbar.hidden {
  transform: translateY(-100%);
  box-shadow: none;
}

/* LOGO */
.logo {
  color: #4bb8ff;
  font-size: 1.25rem;
  font-weight: 600;
  text-shadow: 0 0 8px rgba(0, 160, 255, 0.8);
  flex: 1 1 auto;
}

/* LINKS */
.links {
  display: flex;
  gap: 1rem;
  flex: 1 1 auto;
  justify-content: flex-end;
  transition: max-height 0.3s ease;
}

/* NAV LINK */
.nav-link {
  position: relative;
  color: #9fd4ff;
  text-decoration: none;
  font-size: 0.95rem;
  font-weight: 500;
  padding: 6px 10px;
  border-radius: 8px;
  white-space: nowrap;
  transition: color 0.25s;
}

/* Hover effect */
.nav-link:hover {
  color: #ffffff;
}

/* Glowing underline for active and hover */
.nav-link::after {
  content: '';
  position: absolute;
  left: 0;
  bottom: 0;
  width: 0%;
  height: 3px;
  border-radius: 2px;
  background: linear-gradient(90deg, #00d4ff, #0066ff);
  box-shadow: 0 0 8px #00d4ff, 0 0 12px #0066ff;
  transition: width 0.3s ease;
}

.nav-link:hover::after,
.router-link-active::after {
  width: 100%;
}

/* HAMBURGER BUTTON */
.hamburger {
  display: none;
  flex-direction: column;
  justify-content: space-around;
  width: 28px;
  height: 22px;
  cursor: pointer;
  z-index: 60;
}

.hamburger span {
  display: block;
  height: 3px;
  width: 100%;
  background: #4bb8ff;
  border-radius: 3px;
  transition: 0.3s;
}

.hamburger span.open:nth-child(1) {
  transform: rotate(45deg) translate(5px, 5px);
}

.hamburger span.open:nth-child(2) {
  opacity: 0;
}

.hamburger span.open:nth-child(3) {
  transform: rotate(-45deg) translate(5px, -5px);
}

/* PAGE CONTENT */
.page-content {
  padding-top: 80px;
  width: 100%;
  box-sizing: border-box;
}

/* MOBILE STYLES */
@media (max-width: 600px) {
  .hamburger {
    display: flex;
  }

  .links {
    width: 100%;
    flex-direction: column;
    overflow: hidden;
    max-height: 0;
    background: #0d0d0d;
    border-top: 1px solid #0c4d8a;
    box-shadow: 0 0 15px rgba(0, 140, 255, 0.15);
  }

  .links.open {
    max-height: 300px;
    transition: max-height 0.3s ease-in-out;
  }

  .nav-link {
    padding: 12px 0;
    text-align: center;
    border-radius: 0;
  }

  .logo {
    text-align: left;
    width: auto;
    margin-bottom: 0;
  }
}
</style>
