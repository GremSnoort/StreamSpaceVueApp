import axios from "axios";

const http = axios.create({
  baseURL: import.meta.env.VITE_API_BASE || "http://localhost:8080",
  withCredentials: true
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
