<script setup>
import { ref } from 'vue'
import { useAuthStore } from '../stores/auth'
import { useRouter } from 'vue-router'

const email = ref('')
const password = ref('')
const auth = useAuthStore()
const router = useRouter()

async function submit() {
  try {
    await auth.register(email.value, password.value)
    router.push('/dashboard')
  } catch (err) {
    alert(err.message)
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
          <span class="field-label">Password</span>
          <input
            v-model="password"
            type="password"
            autocomplete="new-password"
            placeholder="••••••••"
            class="input"
          />
        </label>

        <button class="btn btn-primary btn-wide" type="submit">
          Register
        </button>
      </form>

      <p class="auth-footer">
        Already have an account?
        <router-link to="/login" class="auth-link">Login</router-link>
      </p>
    </div>
  </div>
</template>
