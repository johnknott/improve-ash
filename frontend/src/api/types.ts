export type PlanSummary = {
  item_types: number
  items: number
  pools: number
  pool_memberships: number
  environments: number
  event_types: number
  session_templates: number
  session_slots: number
  direct_goals: number
  schedules: number
}

export type Plan = {
  id: string
  name: string
  intention: string
  startsOn: string
  endsOn: string
  status: string
  sourceKind: string
  sourceKey: string | null
  dayLabel: string
  summary: PlanSummary | null
}

export type WorkTarget = {
  quantity?: string | number | null
  unit?: string | null
  quantityPath?: string | null
  summaryTemplate?: string | null
}

export type ProjectedWork = {
  id: string
  kind: 'direct_goal' | 'session'
  status: string
  plannedFor: string
  ownerType: string
  ownerId: string
  title: string
  planId: string
  planName: string
  explanation: string
  target: WorkTarget
  eventTypeId: string | null
  eventTypeName: string | null
  directGoalId: string | null
  directGoalKey: string | null
  canLog: boolean
  session: {
    recommendations: Array<{ id: string; key: string; name: string; reason?: string | null }>
    state: Record<string, unknown>
  } | null
}

export type TodayProjection = {
  planId: string
  date: string
  total: number
  completed: number
  remaining: number
  work: ProjectedWork[]
  upcoming: ProjectedWork[]
  diagnostics: string[]
  explanations: string[]
}

export type JournalEntry = {
  id: string
  planId: string
  planName: string | null
  eventTypeId: string
  eventTypeName: string | null
  summary: string
  quantity: string | null
  unit: string | null
  note: string | null
  status: string
  effectiveAt: string
  recordedAt: string
}

export type PlanItem = {
  id: string
  key: string
  name: string
  typeId: string
  typeKey: string | null
  stateful: boolean
  facts: Record<string, unknown>
  archived: boolean
}

export type EventType = {
  id: string
  key: string
  name: string
  description: string | null
  payloadSchema: Record<string, unknown>
  itemLinkRoles: Record<string, unknown>
}

export type PlanDetail = {
  summary: Plan
  items: PlanItem[]
  eventTypes: EventType[]
}

export type DashboardData = {
  plans: Plan[]
  currentPlan: Plan | null
  today: TodayProjection | null
  journal: JournalEntry[]
  planDetail: PlanDetail | null
}

export type LogEventInput = {
  planId: string
  eventTypeId: string
  directGoalId?: string | null
  summary: string
  quantity?: string | null
  unit?: string | null
  note?: string | null
  payload?: Record<string, unknown>
  itemLinks?: Array<{ role: string; itemId: string; metadata?: Record<string, unknown> }>
}
