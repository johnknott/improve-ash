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
    sessionTemplateId: string
    slotResults: SessionSlotResult[]
  } | null
}

export type SessionSlotResult = {
  id: string
  status: string
  sessionOccurrenceId: string
  sessionSlotId: string
  slotKey: string | null
  slotName: string | null
  poolId: string | null
  poolName: string | null
  recommendedItemId: string | null
  recommendedItemKey: string | null
  recommendedItemName: string | null
  actualItemId: string | null
  actualItemKey: string | null
  actualItemName: string | null
  eventInstanceId: string | null
  notes: string | null
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
  sessionOccurrenceId: string | null
  slotResultId: string | null
  directGoalId: string | null
  slot: {
    id: string
    status: string
    slotKey: string | null
    slotName: string | null
  } | null
  itemLinks: Array<{
    id: string
    role: string
    itemId: string
    itemKey: string | null
    itemName: string | null
    metadata: Record<string, unknown>
  }>
  itemEffects: Array<{
    id: string
    itemId: string
    itemKey: string | null
    itemName: string | null
    effectType: string
    quantity: string | null
    unit: string | null
    status: string
    eventInstanceId: string | null
    replacesItemEffectId: string | null
  }>
}

export type ItemState = {
  itemId: string
  startingFacts: Record<string, unknown>
  calculatedState: Record<string, unknown>
  activeEffects: JournalEntry['itemEffects']
  warnings: string[]
}

export type PlanItem = {
  id: string
  key: string
  name: string
  typeId: string
  typeKey: string | null
  stateful: boolean
  state: ItemState | null
  facts: Record<string, unknown>
  archived: boolean
}

export type ItemType = {
  id: string
  key: string
  name: string
  description: string | null
  factsSchema: Record<string, unknown>
  displayHints: Record<string, unknown>
  itemCount: number
}

export type EventType = {
  id: string
  key: string
  name: string
  description: string | null
  payloadSchema: Record<string, unknown>
  itemLinkRoles: Record<string, unknown>
  effectRules: Record<string, unknown>
}

export type Pool = {
  id: string
  key: string
  name: string
  description: string | null
}

export type PoolMembership = {
  id: string
  poolId: string
  itemId: string
  metadata: Record<string, unknown>
}

export type SessionTemplate = {
  id: string
  key: string
  name: string
  description: string | null
  environmentId: string | null
  completionPolicy: Record<string, unknown>
  missedPolicy: Record<string, unknown>
}

export type SessionSlot = {
  id: string
  sessionTemplateId: string
  key: string
  name: string
  poolId: string
  poolName: string | null
  count: number
  optional: boolean
  rules: Record<string, unknown>
  position: number
}

export type Schedule = {
  id: string
  ownerType: string
  ownerId: string
  kind: string
  rules: Record<string, unknown>
  startsOn: string
  endsOn: string | null
}

export type PlanDetail = {
  summary: Plan
  items: PlanItem[]
  itemTypes: ItemType[]
  eventTypes: EventType[]
  pools: Pool[]
  poolMemberships: PoolMembership[]
  sessionTemplates: SessionTemplate[]
  sessionSlots: SessionSlot[]
  schedules: Schedule[]
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

export type DemoPlanKind = 'gym' | 'vial_inventory'

export type StartSessionInput = {
  planId: string
  sessionTemplateId: string
  date: string
}

export type LogSessionSlotInput = {
  sessionOccurrenceId: string
  slotKey: string
  actualItemKey: string
  recommendedItemKey?: string | null
  eventKey: string
  role: string
  summary: string
  quantity?: string | null
  unit?: string | null
  note?: string | null
  payload: Record<string, unknown>
}

export type SwapSessionSlotInput = {
  slotResultId: string
  actualItemKey: string
  note?: string | null
}

export type SessionStatusInput = {
  sessionOccurrenceId: string
  note?: string | null
}

export type DoseInput = {
  planId: string
  sourceVialItemId: string
  amount: string
  unit: string
  effectiveAt?: string | null
  note?: string | null
  site?: string | null
  route?: string | null
}

export type CorrectDoseInput = DoseInput & {
  originalEventId: string
  correctionNote?: string | null
}
