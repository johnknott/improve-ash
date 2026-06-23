import type { DashboardData, DemoPlanKind, LogEventInput, JournalEntry } from './types'

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

export async function logEvent(input: LogEventInput): Promise<JournalEntry> {
  const body = {
    plan_id: input.planId,
    event_type_id: input.eventTypeId,
    direct_goal_id: input.directGoalId,
    summary: input.summary,
    quantity: input.quantity,
    unit: input.unit,
    note: input.note,
    payload: input.payload ?? {},
    item_links:
      input.itemLinks?.map((itemLink) => ({
        role: itemLink.role,
        item_id: itemLink.itemId,
        metadata: itemLink.metadata ?? {},
      })) ?? [],
  }

  const response = await apiFetch<{ event: JournalEntry }>('/api/app/log-event', {
    method: 'POST',
    body: JSON.stringify(body),
  })

  return response.event
}

export async function installDemoPlan(kind: DemoPlanKind): Promise<DashboardData> {
  return apiFetch<DashboardData>('/api/app/demo-plans', {
    method: 'POST',
    body: JSON.stringify({ kind }),
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
