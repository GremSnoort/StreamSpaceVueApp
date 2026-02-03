import { ref, watchEffect } from 'vue'

const themes = ['ocean', 'violet', 'sunset', 'emerald', 'cyber']

// текущая тема
const theme = ref(localStorage.getItem('theme') || 'ocean')

// применяем тему к <html>
watchEffect(() => {
  document.documentElement.dataset.theme = theme.value
  localStorage.setItem('theme', theme.value)
})

// переключение по кругу
function toggle() {
  const idx = themes.indexOf(theme.value)
  theme.value = themes[(idx + 1) % themes.length]
}

// установка конкретной темы
function setTheme(t) {
  if (themes.includes(t)) {
    theme.value = t
  }
}

export function useTheme() {
  return {
    theme,
    themes,
    toggle,
    setTheme
  }
}
