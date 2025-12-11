import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from './stores/auth'

import Home from './views/Home.vue'
import Login from './views/Login.vue'
import Register from './views/Register.vue'
import Dashboard from './views/Dashboard.vue'
import UserGallery from './views/UserGallery.vue'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/', component: Home },
    { path: '/login', component: Login },
    { path: '/register', component: Register },
    {
      path: '/gallery',
      component: UserGallery,
      meta: { requiresAuth: true }
    },
    {
      path: '/dashboard',
      component: Dashboard,
      meta: { requiresAuth: true }
    }
    // optional: video player page
    //{ path: "/player/:id", component: () => import("../pages/PlayerPage.vue") }
  ]
})

router.beforeEach((to) => {
  const auth = useAuthStore()
  if (to.meta.requiresAuth && !auth.user) {
    return '/login'
  }
})

export default router
