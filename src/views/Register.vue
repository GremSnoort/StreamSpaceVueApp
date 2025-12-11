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
  <div class="register-page">
    <div class="register-card">
      <h1 class="title">Create Account</h1>

      <form @submit.prevent="submit" class="register-form">
        <input v-model="email" type="email" placeholder="Email" class="input" />
        <input v-model="password" type="password" placeholder="Password" class="input" />

        <button class="btn">Register</button>
      </form>

      <p class="login-text">
        Already have an account?
        <router-link to="/login" class="link">Login</router-link>
      </p>
    </div>
  </div>
</template>

<style scoped>
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;600&display=swap');

/* PAGE BACKGROUND */
.register-page {
  height: 100vh;
  width: 100vw;
  background: #0a0a0a;
  display: flex;
  justify-content: center;
  align-items: center;
  font-family: 'Inter', sans-serif;
}

/* CARD */
.register-card {
  background: #111;
  padding: 40px 50px;
  border-radius: 16px;
  box-shadow: 0 0 25px rgba(0, 140, 255, 0.3);
  width: 360px;
  text-align: center;
  border: 1px solid #0c4d8a;
}

/* TITLE */
.title {
  color: #44aaff;
  font-size: 28px;
  margin-bottom: 25px;
  font-weight: 600;
}

/* FORM */
.register-form {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

/* INPUTS */
.input {
  width: 100%;
  padding: 12px 14px;
  border-radius: 10px;
  border: 1px solid #1a4a7a;
  background: #0c0c0c;
  color: #aee1ff;
  font-size: 15px;
  outline: none;
  transition: 0.2s;
}

.input:focus {
  border-color: #009dff;
  box-shadow: 0 0 8px #009dff;
}

/* BUTTON */
.btn {
  margin-top: 10px;
  padding: 12px;
  background: linear-gradient(135deg, #0066ff, #00a3ff);
  border: none;
  border-radius: 10px;
  color: white;
  font-size: 16px;
  cursor: pointer;
  transition: 0.2s;
  font-weight: 600;
}

.btn:hover {
  background: linear-gradient(135deg, #0080ff, #0ab8ff);
  box-shadow: 0 0 15px #009dff;
}

/* TEXT + LINK */
.login-text {
  color: #7bbdf5;
  margin-top: 20px;
  font-size: 14px;
}

.link {
  color: #33aaff;
  font-weight: 600;
  text-decoration: none;
}

.link:hover {
  text-decoration: underline;
}
</style>
