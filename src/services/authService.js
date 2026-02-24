import http from "../lib/http";

function extractMessage(err) {
  return (
    err?.response?.data?.message ||
    err?.response?.data?.error ||
    err?.message ||
    "Request failed"
  );
}

export default {
  async login(login, password) {
    try {
      const { data } = await http.post("/auth/login", { login, password });
      return data.user ?? data;
    } catch (err) {
      err.userMessage = extractMessage(err);
      throw err;
    }
  },

  async register(email, username, password) {
    try {
      const { data } = await http.post("/auth/register", { email, username, password });
      return data.user ?? data;
    } catch (err) {
      err.userMessage = extractMessage(err);
      throw err;
    }
  },

  async logout() {
    // даже если сервер ответит 401, мы всё равно очищаем локального юзера
    try {
      await http.post("/auth/logout");
    } catch (_) {
      // игнор — логаут локально всё равно делаем
    }
  },

  async me() {
    const { data } = await http.get("/auth/me");
    return data.user ?? data;
  }
};
