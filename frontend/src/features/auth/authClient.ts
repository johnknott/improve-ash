export type CurrentUser = {
  id: string
  email: string
  fullName: string | null
}

type AuthResponse = {
  user: CurrentUser | null
}

type AuthErrorResponse = {
  error?: {
    message?: string
  }
}

export async function requestLoginCode(email: string): Promise<void> {
  await authFetch('/api/auth/request-code', {
    method: 'POST',
    body: JSON.stringify({ email }),
  })
}

export async function verifyLoginCode(email: string, otp: string): Promise<CurrentUser> {
  const response = await authFetch('/api/auth/verify-code', {
    method: 'POST',
    body: JSON.stringify({ email, otp }),
  })

  const body = (await response.json()) as AuthResponse

  if (!body.user) {
    throw new Error('That code was invalid or expired.')
  }

  return body.user
}

export async function currentUser(): Promise<CurrentUser | null> {
  const response = await authFetch('/api/auth/me')
  const body = (await response.json()) as AuthResponse
  return body.user
}

export async function completeProfile(fullName: string): Promise<CurrentUser> {
  const response = await authFetch('/api/auth/profile', {
    method: 'POST',
    body: JSON.stringify({ full_name: fullName }),
  })

  const body = (await response.json()) as AuthResponse

  if (!body.user) {
    throw new Error('Please enter your name.')
  }

  return body.user
}

export async function logout(): Promise<void> {
  await authFetch('/api/auth/logout', { method: 'POST' })
}

async function authFetch(path: string, init: RequestInit = {}): Promise<Response> {
  const headers = new Headers(init.headers)

  if (init.body && !headers.has('content-type')) {
    headers.set('content-type', 'application/json')
  }

  const response = await fetch(path, {
    ...init,
    headers,
    credentials: 'include',
  })

  if (!response.ok) {
    const body = (await response.json().catch(() => ({}))) as AuthErrorResponse
    throw new Error(body.error?.message ?? 'Something went wrong.')
  }

  return response
}
