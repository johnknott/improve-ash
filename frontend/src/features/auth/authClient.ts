import { request } from '../../api/http'

export type CurrentUser = {
  id: string
  email: string
  fullName: string | null
}

type AuthResponse = {
  user: CurrentUser | null
}

export async function requestLoginCode(email: string): Promise<void> {
  await authRequest('/api/auth/request-code', { email })
}

export async function verifyLoginCode(email: string, otp: string): Promise<CurrentUser> {
  const body = await authRequest('/api/auth/verify-code', { email, otp })

  if (!body.user) {
    throw new Error('That code was invalid or expired.')
  }

  return body.user
}

export async function currentUser(): Promise<CurrentUser | null> {
  const body = await request<AuthResponse>('/api/auth/me', { notifyUnauthorized: false })
  return body.user
}

export async function completeProfile(fullName: string): Promise<CurrentUser> {
  const body = await authRequest('/api/auth/profile', { full_name: fullName })

  if (!body.user) {
    throw new Error('Please enter your name.')
  }

  return body.user
}

export async function logout(): Promise<void> {
  await request<unknown>('/api/auth/logout', { method: 'POST', notifyUnauthorized: false })
}

function authRequest(path: string, body: unknown): Promise<AuthResponse> {
  return request<AuthResponse>(path, { method: 'POST', body, notifyUnauthorized: false })
}
