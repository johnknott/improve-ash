// Hand-written contract for the /api/app endpoints.
//
// Convention: every key the backend generates is camelCase. Maps whose keys
// are user-authored JSONB (facts, payloads, rules, schemas) pass through
// untouched and are typed as JsonMap.
//
// The read-only /api/rpc endpoints have generated types in
// priv/generated/ash_types.ts (checked by `mix ash_typescript.codegen --check`
// in precommit).

export type JsonMap = Record<string, unknown>

export type ApiErrorDetail = {
  field: string | null
  message: string
}

export type ApiErrorPayload = {
  error?: {
    code?: string
    message?: string
    details?: ApiErrorDetail[]
  }
}

export type PlanSummary = {
  itemTypes: number
  items: number
  pools: number
  poolMemberships: number
  environments: number
  eventTypes: number
  sessionTemplates: number
  sessionSlots: number
  tracks: number
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

export type Target = {
  quantity: string | number | null
  unit: string | null
  mode: string | null
  metricName: string | null
  quantityPath: string | null
  summaryTemplate: string | null
}

// Shape varies by target type (fixed/metric/checklist/period_total/
// progression/adaptive); these are the common keys.
export type TargetProgress = {
  completedEventCount?: number
  completedEventIds?: string[]
  label?: string | null
} & Record<string, unknown>

export type Recommendation = {
  id: string
  key: string
  name: string
  reason: string | null
  source: string | null
  suggestedPayload: JsonMap
  previousEventIds: string[]
  previousEvents: unknown[]
}

export type TimeOffWindow = {
  key?: string
  kind?: string
  reason?: string | null
  startsOn?: string
  endsOn?: string
  availability?: string
} & Record<string, unknown>

export type SessionState = {
  sessionOccurrenceId: string | null
  occurrenceStatus: string | null
  slotResultsTotal: number
  slotResultsLogged: number
  slotResultsRemaining: number
  progressLabel: string | null
  recommendedSlotResults: number
  timeOffWindow: TimeOffWindow | null
}

export type SlotResult = {
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
  suggestedPayload: JsonMap | null
  actualPayload: JsonMap | null
  eventInstanceId: string | null
  notes: string | null
}

export type SessionWork = {
  sessionTemplateId: string
  recommendations: Recommendation[]
  state: SessionState
  slotResults: SlotResult[]
}

export type WorkItem = {
  id: string
  kind: 'track' | 'session'
  status: string
  plannedFor: string
  ownerType: string
  ownerId: string
  title: string
  planId: string
  planName: string
  explanation: string | null
  target: Target | JsonMap
  targetProgress: TargetProgress
  eventTypeId: string | null
  eventTypeName: string | null
  trackId: string | null
  trackKey: string | null
  session: SessionWork | null
  canLog: boolean
}

export type Diagnostic = {
  code?: string
  severity?: string
  message?: string
} & Record<string, unknown>

export type Today = {
  planId: string
  date: string
  total: number
  completed: number
  remaining: number
  work: WorkItem[]
  upcoming: WorkItem[]
  diagnostics: Diagnostic[]
  explanations: unknown[]
}

export type EventItemLink = {
  id: string
  role: string
  itemId: string
  itemKey: string | null
  itemName: string | null
  metadata: JsonMap
}

export type ItemEffect = {
  id: string
  itemId: string
  itemKey: string | null
  itemName: string | null
  effectType: string
  quantity: string | null
  unit: string | null
  status: string
  eventInstanceId: string
  replacesItemEffectId: string | null
}

export type JournalEvent = {
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
  trackId: string | null
  slot: {
    id: string
    status: string
    slotKey: string | null
    slotName: string | null
  } | null
  itemLinks: EventItemLink[]
  itemEffects: ItemEffect[]
}

export type ItemState = {
  itemId: string
  startingFacts: JsonMap
  calculatedState: JsonMap
  activeEffects: ItemEffect[]
  warnings: Diagnostic[]
}

export type Item = {
  id: string
  key: string
  name: string
  typeId: string
  typeKey: string | null
  stateful: boolean
  state: ItemState | null
  facts: JsonMap
  archived: boolean
}

export type ItemType = {
  id: string
  key: string
  name: string
  description: string | null
  factsSchema: JsonMap
  displayHints: JsonMap
  itemCount: number
}

export type EventType = {
  id: string
  key: string
  name: string
  description: string | null
  payloadSchema: JsonMap
  itemLinkRoles: JsonMap
  effectRules: JsonMap
}

export type Schedule = {
  id: string
  ownerType: string
  ownerId: string
  kind: string
  rules: JsonMap
  startsOn: string
  endsOn: string | null
}

export type Track = {
  id: string
  key: string
  name: string
  description: string | null
  eventTypeId: string
  eventTypeName: string | null
  target: Target | JsonMap
  schedule: Schedule | null
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
  metadata: JsonMap
}

export type SessionTemplate = {
  id: string
  key: string
  name: string
  description: string | null
  environmentId: string | null
  completionPolicy: JsonMap
  missedPolicy: JsonMap
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
  rules: JsonMap
  position: number
}

export type PlanDetail = {
  summary: Plan
  items: Item[]
  itemTypes: ItemType[]
  eventTypes: EventType[]
  tracks: Track[]
  pools: Pool[]
  poolMemberships: PoolMembership[]
  sessionTemplates: SessionTemplate[]
  sessionSlots: SessionSlot[]
  schedules: Schedule[]
}

export type DashboardData = {
  plans: Plan[]
  currentPlan: Plan | null
  today: Today | null
  journal: JournalEvent[]
  planDetail: PlanDetail | null
}

// Mutations return only the slices they invalidate; merge into the cached
// DashboardData. GET /app/dashboard always returns every slice.
export type DashboardPatch = Partial<DashboardData>

export type DemoPlanKind = 'gym' | 'vial_inventory'

export type CreatePlanInput = {
  name: string
  intention: string
  startsOn: string
  endsOn: string
  date?: string | null
}

export type UpdatePlanInput = CreatePlanInput & {
  id: string
}
