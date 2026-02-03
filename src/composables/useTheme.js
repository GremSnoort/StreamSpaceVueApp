import { ref, watchEffect } from 'vue'

const theme = ref(
  localStorage.getItem('theme') || 'ocean'
)

watchEffect(() => {
  document.documentElement.dataset.theme = theme.value
  localStorage.setItem('theme', theme.value)
})

export function useTheme() {
  return {
    theme,
    setTheme: (t) => (theme.value = t),
    toggle: () => {
      theme.value = theme.value === 'ocean' ? 'violet' : 'ocean'
    }
  }
}
