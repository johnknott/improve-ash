import type {
  ApiErrorDetail,
  ApiErrorPayload,
  DashboardData,
  CreatePlanInput,
  DemoPlanKind,
  UpdatePlanInput,
} from './types'

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

export async function updatePlan(input: UpdatePlanInput): Promise<DashboardData> {
  return apiFetch<DashboardData>(`/api/app/plans/${input.id}`, {
    method: 'PATCH',
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
    const body = (await response.json().catch(() => ({}))) as ApiErrorPayload
    throw new ApiRequestError(
      response.status,
      body.error?.code ?? 'request_failed',
      body.error?.message ?? 'We could not reach Improve.',
      body.error?.details ?? [],
    )
  }

  return (await response.json()) as T
}

export function todayIso(): string {
  return new Date().toISOString().slice(0, 10)
}
