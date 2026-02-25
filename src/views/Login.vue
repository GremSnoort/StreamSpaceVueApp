<script setup>
import { ref } from 'vue'
import { useAuthStore } from '../stores/auth'
import { useRoute, useRouter } from 'vue-router'

const loginValue = ref('')
const password = ref('')
const errorText = ref('')
const pending = ref(false)
const auth = useAuthStore()
const router = useRouter()
const route = useRoute()

async function submit() {
  errorText.value = ''
  pending.value = true
  try {
    await auth.login(loginValue.value, password.value)
    const next = typeof route.query.next === 'string' ? route.query.next : '/dashboard'
    router.push(next)
  } catch (err) {
    errorText.value = err.userMessage || err.message || 'Login failed'
  } finally {
    pending.value = false
  }
}
</script>

<template>
  <div class="auth-page">
    <div class="panel auth-card">
      <h1 class="auth-title">Welcome Back</h1>

      <form @submit.prevent="submit" class="auth-form">
        <label class="field">
          <span class="field-label">Email or Username</span>
          <input
            v-model="loginValue"
            type="text"
            autocomplete="username"
            placeholder="you@example.com or username"
            class="input"
          />
        </label>

        <label class="field">
          <span class="field-label">Password</span>
          <input
            v-model="password"
            type="password"
            autocomplete="current-password"
            placeholder="••••••••"
            class="input"
          />
        </label>

        <p v-if="errorText" class="auth-error">{{ errorText }}</p>

        <button class="btn btn-primary btn-wide" type="submit">
          {{ pending ? 'Logging in…' : 'Login' }}
        </button>
      </form>

      <p class="auth-footer">
        Need an account?
        <router-link to="/register" class="auth-link">Register</router-link>
      </p>
    </div>
  </div>
</template>

<style scoped>
.auth-error {
  margin: 0;
  color: var(--text-error);
  font-size: 14px;
}
</style>
