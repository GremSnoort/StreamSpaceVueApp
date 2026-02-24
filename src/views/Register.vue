<script setup>
import { ref } from 'vue'
import { useAuthStore } from '../stores/auth'
import { useRouter } from 'vue-router'

const email = ref('')
const username = ref('')
const password = ref('')
const errorText = ref('')
const pending = ref(false)
const auth = useAuthStore()
const router = useRouter()

async function submit() {
  errorText.value = ''
  pending.value = true
  try {
    await auth.register(email.value, username.value, password.value)
    router.push('/dashboard')
  } catch (err) {
    errorText.value = err.userMessage || err.message || 'Registration failed'
  } finally {
    pending.value = false
  }
}
</script>

<template>
  <div class="auth-page">
    <div class="panel auth-card">
      <h1 class="auth-title">Create Account</h1>

      <form @submit.prevent="submit" class="auth-form">
        <label class="field">
          <span class="field-label">Email</span>
          <input
            v-model="email"
            type="email"
            autocomplete="email"
            placeholder="you@example.com"
            class="input"
          />
        </label>

        <label class="field">
          <span class="field-label">Username</span>
          <input
            v-model="username"
            type="text"
            autocomplete="username"
            placeholder="your_username"
            class="input"
          />
        </label>

        <label class="field">
          <span class="field-label">Password</span>
          <input
            v-model="password"
            type="password"
            autocomplete="new-password"
            placeholder="••••••••"
            class="input"
          />
        </label>

        <p v-if="errorText" class="auth-error">{{ errorText }}</p>

        <button class="btn btn-primary btn-wide" type="submit">
          {{ pending ? 'Creating…' : 'Register' }}
        </button>
      </form>

      <p class="auth-footer">
        Already have an account?
        <router-link to="/login" class="auth-link">Login</router-link>
      </p>
    </div>
  </div>
</template>

<style scoped>
.auth-error {
  margin: 0;
  color: #ff8f8f;
  font-size: 14px;
}
</style>
