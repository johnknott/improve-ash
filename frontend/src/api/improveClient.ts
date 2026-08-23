import { request } from './http'
import { operationIdempotency } from './idempotency'
import type {
  DashboardData,
  DashboardPatch,
  CorrectionDashboardPatch,
  CreatePlanInput,
  DemoPlanKind,
  JournalEventStatus,
  JournalPageData,
  JsonMap,
  UpdatePlanInput,
} from './types'

export { ApiRequestError } from './http'

export type LoadJournalPageInput = {
  planId: string
  limit?: number
  cursor?: string | null
  eventTypeId?: string | null
  trackId?: string | null
  itemId?: string | null
  status?: JournalEventStatus | null
}

export type LogTrackInput = {
  planId: string
  trackKey: string
  date: string
  quantity?: string | number | null
  unit?: string | null
  note?: string | null
  payload?: JsonMap
}

export type LogEventInput = {
  planId: string
  eventTypeId: string
  trackId?: string | null
  effectiveAt?: string | null
  summary?: string | null
  quantity?: string | number | null
  unit?: string | null
  note?: string | null
  payload?: JsonMap
  itemLinks?: Array<{ role: string; item_id: string }>
}

export type CorrectEventInput = {
  planId: string
  originalEventId: string
  effectiveAt: string
  summary: string
  quantity?: string | number | null
  unit?: string | null
  note?: string | null
  payload: JsonMap
  correctionNote?: string | null
  date?: string
}

export type SlotActionInput = {
  sessionOccurrenceId: string
  slotKey: string
  recommendedItemKey?: string | null
  actualItemKey?: string | null
  quantity?: string | number | null
  unit?: string | null
  note?: string | null
  payload?: JsonMap
}

export async function loadDashboard(planId?: string | null, date = todayIso()): Promise<DashboardData> {
  const search = new URLSearchParams({ date })

  if (planId) {
    search.set('plan_id', planId)
  }

  return request<DashboardData>(`/api/app/dashboard?${search.toString()}`)
}

export async function loadJournalPage(input: LoadJournalPageInput): Promise<JournalPageData> {
  const search = new URLSearchParams({ plan_id: input.planId })

  if (input.limit !== undefined) {
    search.set('limit', String(input.limit))
  }

  setSearchParam(search, 'cursor', input.cursor)
  setSearchParam(search, 'event_type_id', input.eventTypeId)
  setSearchParam(search, 'track_id', input.trackId)
  setSearchParam(search, 'item_id', input.itemId)
  setSearchParam(search, 'status', input.status)

  return request<JournalPageData>(`/api/app/journal?${search.toString()}`)
}

function setSearchParam(
  search: URLSearchParams,
  key: string,
  value: string | null | undefined,
): void {
  if (value) {
    search.set(key, value)
  }
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

export async function logTrack(input: LogTrackInput): Promise<DashboardPatch> {
  return request<DashboardPatch>('/api/app/log-track', {
    method: 'POST',
    body: {
      plan_id: input.planId,
      track_key: input.trackKey,
      date: input.date,
      quantity: input.quantity,
      unit: input.unit,
      note: input.note,
      payload: input.payload ?? {},
      ...operationIdempotency(),
    },
  })
}

export async function skipTrack(input: {
  planId: string
  trackKey: string
  date: string
  reason?: string | null
}): Promise<DashboardPatch> {
  return request<DashboardPatch>('/api/app/skip-track', {
    method: 'POST',
    body: {
      plan_id: input.planId,
      track_key: input.trackKey,
      date: input.date,
      reason: input.reason,
      ...operationIdempotency(),
    },
  })
}

export async function logEvent(input: LogEventInput): Promise<DashboardPatch> {
  return request<DashboardPatch>('/api/app/log-event', {
    method: 'POST',
    body: {
      plan_id: input.planId,
      event_type_id: input.eventTypeId,
      track_id: input.trackId,
      effective_at: input.effectiveAt,
      summary: input.summary,
      quantity: input.quantity,
      unit: input.unit,
      note: input.note,
      payload: input.payload ?? {},
      item_links: input.itemLinks ?? [],
      ...operationIdempotency(),
    },
  })
}

export async function correctEvent(input: CorrectEventInput): Promise<CorrectionDashboardPatch> {
  return request<CorrectionDashboardPatch>('/api/app/correct-event', {
    method: 'POST',
    body: {
      plan_id: input.planId,
      original_event_id: input.originalEventId,
      effective_at: input.effectiveAt,
      summary: input.summary,
      quantity: input.quantity,
      unit: input.unit,
      note: input.note,
      payload: input.payload,
      correction_note: input.correctionNote,
      date: input.date,
    },
  })
}

export async function startSession(
  planId: string,
  sessionTemplateId: string,
  date: string,
): Promise<DashboardPatch> {
  return request<DashboardPatch>('/api/app/start-session', {
    method: 'POST',
    body: { plan_id: planId, session_template_id: sessionTemplateId, date },
  })
}

export async function logSessionSlot(
  input: SlotActionInput,
  date: string,
): Promise<DashboardPatch> {
  return request<DashboardPatch>('/api/app/log-session-slot', {
    method: 'POST',
    body: {
      date,
      session_occurrence_id: input.sessionOccurrenceId,
      slot_key: input.slotKey,
      actual_item_key: input.actualItemKey,
      recommended_item_key: input.recommendedItemKey,
      quantity: input.quantity,
      unit: input.unit,
      note: input.note,
      payload: input.payload ?? {},
      ...operationIdempotency(),
    },
  })
}

export async function skipSessionSlot(
  input: SlotActionInput,
  date: string,
): Promise<DashboardPatch> {
  return request<DashboardPatch>('/api/app/skip-session-slot', {
    method: 'POST',
    body: {
      date,
      session_occurrence_id: input.sessionOccurrenceId,
      slot_key: input.slotKey,
      recommended_item_key: input.recommendedItemKey,
      note: input.note,
    },
  })
}

export async function swapSessionSlot(
  slotResultId: string,
  actualItemKey: string,
  date: string,
  note?: string | null,
): Promise<DashboardPatch> {
  return request<DashboardPatch>('/api/app/swap-session-slot', {
    method: 'POST',
    body: { slot_result_id: slotResultId, actual_item_key: actualItemKey, date, note },
  })
}

export async function completeSession(
  sessionOccurrenceId: string,
  date: string,
  note?: string | null,
): Promise<DashboardPatch> {
  return request<DashboardPatch>('/api/app/complete-session', {
    method: 'POST',
    body: { session_occurrence_id: sessionOccurrenceId, date, note },
  })
}

export async function skipSession(
  sessionOccurrenceId: string,
  date: string,
  note?: string | null,
): Promise<DashboardPatch> {
  return request<DashboardPatch>('/api/app/skip-session', {
    method: 'POST',
    body: { session_occurrence_id: sessionOccurrenceId, date, note },
  })
}

export function todayIso(): string {
  return new Date().toISOString().slice(0, 10)
}
