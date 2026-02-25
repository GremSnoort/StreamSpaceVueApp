<script setup>
import { ref } from 'vue'
import { useAuthStore } from '../stores/auth'
import { useRouter } from 'vue-router'

const email = ref('')
const username = ref('')
const password = ref('')
const showPassword = ref(false)
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
          <div class="password-wrap">
            <input
              v-model="password"
              :type="showPassword ? 'text' : 'password'"
              autocomplete="new-password"
              placeholder="••••••••"
              class="input password-input"
            />
            <button
              type="button"
              class="password-toggle"
              :aria-label="showPassword ? 'Hide password' : 'Show password'"
              :title="showPassword ? 'Hide password' : 'Show password'"
              @click="showPassword = !showPassword"
            >
              {{ showPassword ? '🙈' : '👁' }}
            </button>
          </div>
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
  color: var(--text-error);
  font-size: 14px;
}

.password-wrap {
  position: relative;
}

.password-input {
  padding-right: 44px;
}

.password-toggle {
  position: absolute;
  right: 8px;
  top: 50%;
  transform: translateY(-50%);
  border: 0;
  background: transparent;
  color: var(--ui-fg-1);
  cursor: pointer;
  width: 30px;
  height: 30px;
  border-radius: 8px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
}

.password-toggle:hover {
  background: var(--ui-surface-1);
}
</style>
