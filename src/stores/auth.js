import { defineStore } from 'pinia'
import authService from '../services/authService'

export const useAuthStore = defineStore('auth', {
  state: () => ({
    user: JSON.parse(localStorage.getItem('user')) || null
  }),
  actions: {
    async login(email, password) {
      this.user = await authService.login(email, password)
      localStorage.setItem('user', JSON.stringify(this.user))
    },
    async register(email, password) {
      this.user = await authService.register(email, password)
      localStorage.setItem('user', JSON.stringify(this.user))
    },
    logout() {
      this.user = null
      localStorage.removeItem('user')
    }
  }
})
