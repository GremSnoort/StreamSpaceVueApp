import axios from "axios";

const http = axios.create({
  baseURL: import.meta.env.VITE_API_BASE || "http://localhost:8080",
  withCredentials: true
});

function readCookie(name) {
  if (typeof document === "undefined") return "";
  const raw = document.cookie || "";
  const needle = `${name}=`;
  const parts = raw.split(";").map((s) => s.trim());
  const hit = parts.find((p) => p.startsWith(needle));
  if (!hit) return "";
  return decodeURIComponent(hit.slice(needle.length));
}

function isSafeMethod(method) {
  const m = String(method || "get").toLowerCase();
  return m === "get" || m === "head" || m === "options";
}

http.interceptors.request.use((config) => {
  if (!isSafeMethod(config?.method)) {
    const csrf = readCookie("csrf_token");
    if (csrf) {
      config.headers = config.headers || {};
      config.headers["X-CSRF-Token"] = csrf;
    }
  }
  return config;
});

// Глобальная обработка 401 (сессия истекла / нет cookie)
http.interceptors.response.use(
  (res) => res,
  (error) => {
    const status = error?.response?.status;

    // ВАЖНО: не делаем редиректы тут (иначе циклы).
    // Просто пробрасываем ошибку — store/guard решит, что делать.
    if (status === 401) {
      // можно пометить ошибку, чтобы выше уровни могли отличить
      error.isUnauthorized = true;
    }

    return Promise.reject(error);
  }
);

export default http;
