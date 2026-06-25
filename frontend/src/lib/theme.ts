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

export function toggleTheme(): void {
  theme.update((current) => (current === 'dark' ? 'light' : 'dark'))
}
