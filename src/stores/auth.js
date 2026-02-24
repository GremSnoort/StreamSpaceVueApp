import { defineStore } from "pinia";
import authService from "../services/authService";

export const useAuthStore = defineStore("auth", {
  state: () => ({
    user: JSON.parse(localStorage.getItem("user")) || null,
    isRestoring: false
  }),

  getters: {
    isAuthenticated: (s) => !!s.user
  },

  actions: {
    setUser(user) {
      this.user = user;
      if (user) localStorage.setItem("user", JSON.stringify(user));
      else localStorage.removeItem("user");
    },

    async login(login, password) {
      const user = await authService.login(login, password);
      this.setUser(user);
      return user;
    },

    async register(email, username, password) {
      const user = await authService.register(email, username, password);
      this.setUser(user);
      return user;
    },

    async logout() {
      await authService.logout();
      this.setUser(null);
    },

    async tryRestoreSession() {
      // чтобы не стрелять запросом /auth/me на каждый переход
      if (this.isRestoring) return this.user;

      this.isRestoring = true;
      try {
        const user = await authService.me();
        this.setUser(user);
        return user;
      } catch (err) {
        // если 401 — сессии нет, просто очищаем
        this.setUser(null);
        return null;
      } finally {
        this.isRestoring = false;
      }
    }
  }
});
