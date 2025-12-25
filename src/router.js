import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from './stores/auth'

import Home from './views/Home.vue'
import Login from './views/Login.vue'
import Register from './views/Register.vue'
import Dashboard from './views/Dashboard.vue'
import UserGallery from './views/UserGallery.vue'
import PlayerPage from './views/PlayerPage.vue'
import GalleryPage from './views/GalleryPage.vue'
import Upload from './views/Upload.vue'
import DashboardOverview from './views/dashboard/DashboardOverview.vue'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { name: 'home', path: '/', component: Home },
    { name: 'login', path: '/login', component: Login },
    { name: 'register', path: '/register', component: Register },
    {
      name: 'gallery',
      path: '/gallery',
      component: GalleryPage,
      meta: { requiresAuth: true }
    },
    { name: 'player',
      path: '/player/:id',
      component: PlayerPage,
      props: true
    },
    {
      name: "upload",
      path: "/upload",
      component: Upload,
      meta: { requiresAuth: true }
    },
    {
      name: 'dashboard',
      path: '/dashboard',
      component: Dashboard,
      meta: { requiresAuth: true },
      children: [
        { path: '', redirect: '/dashboard/overview' },
        { path: 'overview', component: () => DashboardOverview },
        { path: 'videos', component: () => UserGallery },
        { path: 'upload', component: () => Upload },
        //{ path: 'profile', component: () => import('@/views/Profile.vue') }
      ]
    }
  ]
})

router.beforeEach(async (to) => {
  const auth = useAuthStore();

  // if user not loaded but cookie exists -> try restore session
  if (!auth.user && auth.token) {
    await auth.tryRestoreSession?.();
  }

  if (to.meta.requiresAuth && !auth.user) {
    return { name: 'login' };
  }
})

export default router
