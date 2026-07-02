import { writable } from 'svelte/store'

export type Theme = 'light' | 'dark'

const STORAGE_KEY = 'improve-theme'

function initialTheme(): Theme {
  if (typeof window === 'undefined') {
    return 'light'
  }

  const stored = window.localStorage.getItem(STORAGE_KEY)

  if (stored === 'light' || stored === 'dark') {
    return stored
  }

  return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'
}

export const theme = writable<Theme>(initialTheme())

if (typeof window !== 'undefined') {
  theme.subscribe((value) => {
    document.documentElement.setAttribute('data-theme', value)
    window.localStorage.setItem(STORAGE_KEY, value)
  })
}

function prefersReducedMotion(): boolean {
  return (
    typeof window !== 'undefined' &&
    window.matchMedia('(prefers-reduced-motion: reduce)').matches
  )
}

export function toggleTheme(): void {
  if (typeof document === 'undefined' || prefersReducedMotion()) {
    theme.update((current) => (current === 'dark' ? 'light' : 'dark'))
    return
  }

  const root = document.documentElement
  root.classList.add('theme-transitioning')
  requestAnimationFrame(() => {
    theme.update((current) => (current === 'dark' ? 'light' : 'dark'))
    setTimeout(() => root.classList.remove('theme-transitioning'), 240)
  })
}
