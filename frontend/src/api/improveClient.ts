import type {
  DashboardData,
  CorrectDoseInput,
  DemoPlanKind,
  DoseInput,
  LogEventInput,
  JournalEntry,
  LogSessionSlotInput,
  StartSessionInput,
  SessionStatusInput,
  SwapSessionSlotInput,
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

export async function logDose(input: DoseInput): Promise<DashboardData> {
  return apiFetch<DashboardData>('/api/app/log-dose', {
    method: 'POST',
    body: JSON.stringify(doseBody(input)),
  })
}

export async function correctDose(input: CorrectDoseInput): Promise<DashboardData> {
  return apiFetch<DashboardData>('/api/app/correct-dose', {
    method: 'POST',
    body: JSON.stringify({
      ...doseBody(input),
      original_event_id: input.originalEventId,
      correction_note: input.correctionNote,
    }),
  })
}

export async function installDemoPlan(kind: DemoPlanKind): Promise<DashboardData> {
  return apiFetch<DashboardData>('/api/app/demo-plans', {
    method: 'POST',
    body: JSON.stringify({ kind }),
  })
}

export async function startSession(input: StartSessionInput): Promise<DashboardData> {
  return apiFetch<DashboardData>('/api/app/start-session', {
    method: 'POST',
    body: JSON.stringify({
      plan_id: input.planId,
      session_template_id: input.sessionTemplateId,
      date: input.date,
    }),
  })
}

export async function logSessionSlot(input: LogSessionSlotInput): Promise<DashboardData> {
  return apiFetch<DashboardData>('/api/app/log-session-slot', {
    method: 'POST',
    body: JSON.stringify({
      session_occurrence_id: input.sessionOccurrenceId,
      slot_key: input.slotKey,
      actual_item_key: input.actualItemKey,
      recommended_item_key: input.recommendedItemKey,
      event_key: input.eventKey,
      role: input.role,
      summary: input.summary,
      quantity: input.quantity,
      unit: input.unit,
      note: input.note,
      payload: input.payload,
    }),
  })
}

export async function swapSessionSlot(input: SwapSessionSlotInput): Promise<DashboardData> {
  return apiFetch<DashboardData>('/api/app/swap-session-slot', {
    method: 'POST',
    body: JSON.stringify({
      slot_result_id: input.slotResultId,
      actual_item_key: input.actualItemKey,
      note: input.note,
    }),
  })
}

export async function completeSession(input: SessionStatusInput): Promise<DashboardData> {
  return updateSessionStatus('/api/app/complete-session', input)
}

export async function skipSession(input: SessionStatusInput): Promise<DashboardData> {
  return updateSessionStatus('/api/app/skip-session', input)
}

function updateSessionStatus(path: string, input: SessionStatusInput): Promise<DashboardData> {
  return apiFetch<DashboardData>(path, {
    method: 'POST',
    body: JSON.stringify({
      session_occurrence_id: input.sessionOccurrenceId,
      note: input.note,
    }),
  })
}

function doseBody(input: DoseInput): Record<string, unknown> {
  return {
    plan_id: input.planId,
    source_vial_item_id: input.sourceVialItemId,
    amount: input.amount,
    unit: input.unit,
    effective_at: input.effectiveAt,
    note: input.note,
    site: input.site,
    route: input.route,
  }
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
