import { writable } from 'svelte/store'
import { onUnauthorized } from '../../api/http'
import { completeProfile, currentUser, logout, type CurrentUser } from './authClient'

type AuthState = {
  loading: boolean
  user: CurrentUser | null
}

export const authState = writable<AuthState>({
  loading: true,
  user: null,
})

// A 401 from any app endpoint means the session expired mid-use: clear the
// user so App.svelte routes back to the login screen.
onUnauthorized(() => {
  authState.set({ loading: false, user: null })
})

export async function loadCurrentUser(): Promise<void> {
  authState.set({ loading: true, user: null })

  try {
    authState.set({ loading: false, user: await currentUser() })
  } catch {
    authState.set({ loading: false, user: null })
  }
}

export function setCurrentUser(user: CurrentUser): void {
  authState.set({ loading: false, user })
}

export async function completeCurrentUserProfile(fullName: string): Promise<void> {
  authState.set({ loading: false, user: await completeProfile(fullName) })
}

export async function logoutCurrentUser(): Promise<void> {
  try {
    await logout()
  } finally {
    authState.set({ loading: false, user: null })
  }
}
