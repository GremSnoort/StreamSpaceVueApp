import { createRouter, createWebHistory } from "vue-router";
import { useAuthStore } from "./stores/auth";

import Home from "./views/Home.vue";
import Login from "./views/Login.vue";
import Register from "./views/Register.vue";
import Dashboard from "./views/Dashboard.vue";
import UserGallery from "./views/UserGallery.vue";
import PlayerPage from "./views/PlayerPage.vue";
import GalleryPage from "./views/GalleryPage.vue";
import Upload from "./views/Upload.vue";
import DashboardOverview from "./views/dashboard/DashboardOverview.vue";
import DashboardProfile from "./views/dashboard/DashboardProfile.vue";
import DashboardFolders from "./views/dashboard/DashboardFolders.vue";

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { name: "home", path: "/", component: Home },
    { name: "login", path: "/login", component: Login },
    { name: "register", path: "/register", component: Register },

    {
      name: "gallery",
      path: "/gallery",
      component: GalleryPage
    },

    {
      name: "player",
      path: "/player/:id",
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
      name: "dashboard",
      path: "/dashboard",
      component: Dashboard,
      meta: { requiresAuth: true },
      children: [
        { path: "", redirect: { name: "dashboard-overview" } },
        { name: "dashboard-overview", path: "overview", component: DashboardOverview },
        { name: "dashboard-library", path: "library", component: DashboardFolders, props: { treeType: "library", title: "Library Folders" } },
        { name: "dashboard-favorites", path: "favorites", component: DashboardFolders, props: { treeType: "favorites", title: "Favorites Folders" } },
        { name: "dashboard-videos", path: "videos", component: UserGallery },
        { name: "dashboard-upload", path: "upload", component: Upload },
        { name: "dashboard-profile", path: "profile", component: DashboardProfile }
      ]
    }
  ]
});

router.beforeEach(async (to) => {
  const auth = useAuthStore();

  // 1) Перед проверкой защищённых роутов пытаемся восстановить сессию
  //    (особенно важно если user был пустой, а cookie есть)
  if (!auth.user) {
    await auth.tryRestoreSession();
  }

  // 2) Если нужен логин — уводим на login + next
  if (to.meta.requiresAuth && !auth.user) {
    return { name: "login", query: { next: to.fullPath } };
  }

  // 3) Если уже залогинен — на login/register не пускаем
  if ((to.name === "login" || to.name === "register") && auth.user) {
    return { name: "dashboard-overview" };
  }
});

export default router;
