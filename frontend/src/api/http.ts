import type { ApiErrorDetail, ApiErrorPayload } from './types'

export class ApiRequestError extends Error {
  readonly code: string
  readonly status: number
  readonly details: ApiErrorDetail[]

  constructor(status: number, code: string, message: string, details: ApiErrorDetail[]) {
    super(message)
    this.name = 'ApiRequestError'
    this.status = status
    this.code = code
    this.details = details
  }

  fieldMessage(field: string): string | null {
    return this.details.find((detail) => detail.field === field)?.message ?? null
  }
}

let unauthorizedHandler: (() => void) | null = null

// The auth store registers a handler that clears the current user, which
// routes the app back to the login screen when the session expires mid-use.
export function onUnauthorized(handler: () => void): void {
  unauthorizedHandler = handler
}

export type RequestOptions = {
  method?: string
  body?: unknown
  // Auth endpoints answer 401 for expected cases (not signed in, bad OTP),
  // which should not bounce the whole app to the login screen.
  notifyUnauthorized?: boolean
}

// Every API call goes through here, so cross-cutting concerns (session
// expiry, request timing, and later per-operation idempotency keys) attach
// in one place.
export async function request<T>(path: string, options: RequestOptions = {}): Promise<T> {
  const method = options.method ?? 'GET'
  const startedAt = performance.now()

  try {
    const headers = new Headers()
    const init: RequestInit = {
      method,
      credentials: 'include',
      headers,
    }

    if (options.body !== undefined) {
      headers.set('content-type', 'application/json')
      init.body = JSON.stringify(options.body)
    }

    const response = await fetch(path, init)

    if (!response.ok) {
      if (response.status === 401 && options.notifyUnauthorized !== false) {
        unauthorizedHandler?.()
      }

      const body = (await response.json().catch(() => ({}))) as ApiErrorPayload

      throw new ApiRequestError(
        response.status,
        body.error?.code ?? 'request_failed',
        body.error?.message ?? 'We could not reach Improve.',
        body.error?.details ?? [],
      )
    }

    const text = await response.text()
    return (text ? JSON.parse(text) : null) as T
  } finally {
    if (import.meta.env.DEV) {
      // Slow requests warn, which surfaces them in the dev error badge —
      // e.g. a dev-server recompile blocking the first request after edits.
      const elapsed = performance.now() - startedAt
      const line = `[perf] ${method} ${path.split('?')[0]}: ${elapsed.toFixed(0)}ms`

      if (elapsed > 300) {
        console.warn(line)
      } else {
        console.debug(line)
      }
    }
  }
}
