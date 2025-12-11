export default {
  async login(email, password) {
    // Fake API delay
    await new Promise(r => setTimeout(r, 300))
    if (!email || !password) throw new Error("Invalid credentials")
    return { email }
  },

  async register(email, password) {
    // Fake registration
    await new Promise(r => setTimeout(r, 300))
    return { email }
  }
}
