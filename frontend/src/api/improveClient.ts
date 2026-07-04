import { request } from './http'
import type {
  DashboardData,
  DashboardPatch,
  CreatePlanInput,
  DemoPlanKind,
  UpdatePlanInput,
} from './types'

export { ApiRequestError } from './http'

export async function loadDashboard(planId?: string | null, date = todayIso()): Promise<DashboardData> {
  const search = new URLSearchParams({ date })

  if (planId) {
    search.set('plan_id', planId)
  }

  return request<DashboardData>(`/api/app/dashboard?${search.toString()}`)
}

export async function installDemoPlan(kind: DemoPlanKind, date = todayIso()): Promise<DashboardPatch> {
  return request<DashboardPatch>('/api/app/demo-plans', {
    method: 'POST',
    body: { kind, date },
  })
}

export async function createPlan(input: CreatePlanInput): Promise<DashboardPatch> {
  return request<DashboardPatch>('/api/app/plans', {
    method: 'POST',
    body: planBody(input),
  })
}

export async function updatePlan(input: UpdatePlanInput): Promise<DashboardPatch> {
  return request<DashboardPatch>(`/api/app/plans/${input.id}`, {
    method: 'PATCH',
    body: planBody(input),
  })
}

function planBody(input: CreatePlanInput) {
  return {
    name: input.name,
    intention: input.intention,
    starts_on: input.startsOn,
    ends_on: input.endsOn,
    date: input.date,
  }
}

export function todayIso(): string {
  return new Date().toISOString().slice(0, 10)
}
