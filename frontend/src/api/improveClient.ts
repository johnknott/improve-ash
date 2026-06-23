import type {
  DashboardData,
  CreatePlanInput,
  DemoPlanKind,
} from './types'

type ApiError = {
  error?: {
    message?: string
  }
}

export async function loadDashboard(planId?: string | null, date = todayIso()): Promise<DashboardData> {
  const search = new URLSearchParams({ date })

  if (planId) {
    search.set('plan_id', planId)
  }

  return apiFetch<DashboardData>(`/api/app/dashboard?${search.toString()}`)
}

export async function installDemoPlan(kind: DemoPlanKind, date = todayIso()): Promise<DashboardData> {
  return apiFetch<DashboardData>('/api/app/demo-plans', {
    method: 'POST',
    body: JSON.stringify({ kind, date }),
  })
}

export async function createPlan(input: CreatePlanInput): Promise<DashboardData> {
  return apiFetch<DashboardData>('/api/app/plans', {
    method: 'POST',
    body: JSON.stringify({
      name: input.name,
      intention: input.intention,
      starts_on: input.startsOn,
      ends_on: input.endsOn,
      date: input.date,
    }),
  })
}

async function apiFetch<T>(path: string, init: RequestInit = {}): Promise<T> {
  const headers = new Headers(init.headers)

  if (init.body && !headers.has('content-type')) {
    headers.set('content-type', 'application/json')
  }

  const response = await fetch(path, {
    ...init,
    credentials: 'include',
    headers,
  })

  if (!response.ok) {
    const body = (await response.json().catch(() => ({}))) as ApiError
    throw new Error(body.error?.message ?? 'We could not reach Improve.')
  }

  return (await response.json()) as T
}

export function todayIso(): string {
  return new Date().toISOString().slice(0, 10)
}
