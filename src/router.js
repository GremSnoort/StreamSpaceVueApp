import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from './stores/auth'

import Home from './views/Home.vue'
import Login from './views/Login.vue'
import Register from './views/Register.vue'
import Dashboard from './views/Dashboard.vue'
import UserGallery from './views/UserGallery.vue'
import PlayerPage from './views/PlayerPage.vue'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { name: 'home', path: '/', component: Home },
    { name: 'login', path: '/login', component: Login },
    { name: 'register', path: '/register', component: Register },
    {
      name: 'gallery',
      path: '/gallery',
      component: UserGallery,
      meta: { requiresAuth: true }
    },
    {
      name: 'dashboard',
      path: '/dashboard',
      component: Dashboard,
      meta: { requiresAuth: true }
    },
    { name: 'player',
      path: '/player/:id',
      component: PlayerPage,
      props: true
    }
  ]
})

router.beforeEach((to) => {
  const auth = useAuthStore()
  if (to.meta.requiresAuth && !auth.user) {
    return { name: 'login' }
  }
})

router.beforeEach(async (to) => {
  const auth = useAuthStore();

  // if user not loaded but cookie exists -> try restore session
  if (!auth.user) {
    await auth.tryRestoreSession?.();
  }

  if (to.meta.requiresAuth && !auth.user) {
    return { name: 'login' };
  }
})

export default router
