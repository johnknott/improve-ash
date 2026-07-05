// Dev-only error visibility. Uncaught exceptions, unhandled rejections, and
// console.error/warn calls land in one ring buffer that is:
//   - rendered as a badge (DevErrorBadge) so problems are visible instantly,
//   - exposed as window.__improveErrors so agent sessions can poll it after
//     every scripted interaction (agent-browser's console channel misses
//     uncaught exceptions entirely).
import { writable } from 'svelte/store'

export type CapturedError = {
  kind: 'error' | 'rejection' | 'console.error' | 'console.warn'
  message: string
  at: string
}

declare global {
  interface Window {
    __improveErrors?: CapturedError[]
  }
}

const MAX_ENTRIES = 100

export const devErrors = writable<CapturedError[]>([])

let installed = false
let capturing = false

export function installDevErrorCapture(): void {
  if (installed) {
    return
  }

  installed = true
  window.__improveErrors = []

  window.addEventListener('error', (event) => {
    capture('error', [event.error ?? event.message])
  })

  window.addEventListener('unhandledrejection', (event) => {
    capture('rejection', [event.reason])
  })

  for (const level of ['error', 'warn'] as const) {
    const original = console[level].bind(console)

    console[level] = (...args: unknown[]) => {
      capture(`console.${level}`, args)
      original(...args)
    }
  }
}

// Boundaries report caught component crashes here (see AppShell).
export function reportBoundaryError(error: unknown): void {
  capture('error', [error])
}

export function clearDevErrors(): void {
  devErrors.set([])
  window.__improveErrors = []
}

function capture(kind: CapturedError['kind'], parts: unknown[]): void {
  // The badge or store subscribers may themselves warn; do not recurse.
  if (capturing) {
    return
  }

  capturing = true

  try {
    const entry: CapturedError = {
      kind,
      message: parts.map(format).join(' '),
      at: new Date().toISOString(),
    }

    devErrors.update((list) => {
      const next = [...list, entry].slice(-MAX_ENTRIES)
      window.__improveErrors = next
      return next
    })
  } finally {
    capturing = false
  }
}

function format(value: unknown): string {
  if (value instanceof Error) {
    const stackHead = value.stack?.split('\n').slice(1, 3).join(' ') ?? ''
    return `${value.name}: ${value.message}${stackHead ? ` (${stackHead.trim()})` : ''}`
  }

  if (typeof value === 'string') {
    return value
  }

  try {
    return JSON.stringify(value)
  } catch {
    return String(value)
  }
}
