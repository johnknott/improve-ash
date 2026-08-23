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

// Every target evaluator emits these keys; the variants below add their
// per-type fields. Quantities are decimal strings rendered by the backend.
type TargetProgressBase = {
  completedEventCount: number
  completedEventIds: string[]
  label: string
}

export type FixedTargetProgress = TargetProgressBase

export type MetricTargetProgress = TargetProgressBase & {
  recordedValue: string | number | null
  unit: string | null
}

export type ChecklistTargetProgress = TargetProgressBase & {
  completedCount: number
  requiredCount: number
  completedItems: string[]
  requiredItems: string[]
}

export type AdaptiveTargetProgress = TargetProgressBase & {
  requiredFields: string[]
  recordedFields: string[]
  missingFields: string[]
  recordedCount: number
  requiredCount: number
}

export type PeriodTotalTargetProgress = TargetProgressBase & {
  totalQuantity: string | null
  targetQuantity: string | null
  unit: string | null
  period: string | null
  startsOn: string | null
  endsOn: string | null
}

export type ProgressionTargetProgress = TargetProgressBase & {
  totalQuantity: string | null
  expectedQuantity: string | null
  unit: string | null
  startsOn: string | null
  endsOn: string | null
  from: string | null
  to: string | null
  shape: string | null
}

export type ResponsiveProgressionTargetProgress = TargetProgressBase & {
  totalQuantity: string | null
  expectedQuantity: string | null
  unit: string | null
  position: number
  totalSteps: number
  deloadAfter: number | null
  mode: 'responsive'
}

export type TargetProgress =
  | FixedTargetProgress
  | MetricTargetProgress
  | ChecklistTargetProgress
  | AdaptiveTargetProgress
  | PeriodTotalTargetProgress
  | ProgressionTargetProgress
  | ResponsiveProgressionTargetProgress

export type RecommendationPreviousEvent = {
  id: string
  summary: string
  effectiveAt: string
  payload: JsonMap
}

export type RecommendedItem = {
  id: string
  key: string
  name: string
  reason: string | null
  source: string | null
  suggestedPayload: JsonMap
  previousEventIds: string[]
  previousEvents: RecommendationPreviousEvent[]
}

// One entry per session slot, in slot order; present before a session
// starts (slotResults take over once it does).
export type SlotRecommendation = {
  sessionSlotId: string
  slotKey: string | null
  slotName: string | null
  count: number
  poolId: string | null
  poolName: string | null
  items: RecommendedItem[]
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
  recommendations: SlotRecommendation[]
  state: SessionState
  slotResults: SlotResult[]
}

// Session work items carry no target progress, so the payload is {}.
export type WorkItemTargetProgress = TargetProgress | Record<string, never>

// Present when the effective target differs from the authored one (an
// evaluator adjusted it); null otherwise.
export type TargetProvenance = {
  planned: Target | JsonMap
  effective: Target | JsonMap
  adjusted: boolean
  source: string
  reason: string | null
}

export type WorkStatus =
  | 'planned'
  | 'started'
  | 'partial'
  | 'completed'
  | 'missed'
  | 'on_hold'
  | 'skipped'

export type WorkItem = {
  id: string
  kind: 'track' | 'session'
  status: WorkStatus
  plannedFor: string
  ownerType: string
  ownerId: string
  title: string
  planId: string
  planName: string
  explanation: string | null
  target: Target | JsonMap
  targetProgress: WorkItemTargetProgress
  provenance: TargetProvenance | null
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

export type ProposalCard = {
  id: string
  kind: string
  text: string
  sourceEvaluator: string | null
}

export type ProposalsSummary = {
  count: number
  cards: ProposalCard[]
}

export type Today = {
  planId: string
  date: string
  total: number
  completed: number
  skipped: number
  missed: number
  onHold: number
  remaining: number
  work: WorkItem[]
  upcoming: WorkItem[]
  proposals: ProposalsSummary | null
  diagnostics: Diagnostic[]
  explanations: string[]
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

export type JournalItemEffect = ItemEffect & {
  payload: JsonMap
  voidedAt: string | null
}

export type JournalEventStatus = 'active' | 'corrected' | 'voided' | 'skipped'

export type JournalEventOrigin =
  | 'manual'
  | 'seed'
  | 'assistant_proposed'
  | 'imported'
  | 'offline_sync'

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
  status: JournalEventStatus
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

export type JournalEventReference = {
  id: string
  summary: string
  status: JournalEventStatus
  effectiveAt: string
}

export type JournalCorrection = {
  eligible: boolean
  unavailableReason: string | null
  replaces: JournalEventReference | null
  replacedBy: JournalEventReference[]
}

export type JournalEventDetail = {
  id: string
  planId: string
  eventTypeId: string
  eventTypeName: string | null
  eventTypeKey: string | null
  trackId: string | null
  trackName: string | null
  trackKey: string | null
  summary: string
  quantity: string | null
  unit: string | null
  note: string | null
  payload: JsonMap
  origin: JournalEventOrigin
  status: JournalEventStatus
  effectiveAt: string
  recordedAt: string
  correctedAt: string | null
  voidedAt: string | null
  targetSnapshot: JsonMap | null
  sessionOccurrenceId: string | null
  slotResultId: string | null
  replacesEventInstanceId: string | null
  itemLinks: EventItemLink[]
  itemEffects: JournalItemEffect[]
  correction: JournalCorrection
}

export type JournalFilters = {
  eventTypeId: string | null
  trackId: string | null
  itemId: string | null
  status: JournalEventStatus | null
}

export type JournalFilterOption = {
  id: string
  name: string
}

export type JournalPageData = {
  planId: string
  events: JournalEventDetail[]
  pageInfo: {
    limit: number
    hasMore: boolean
    nextCursor: string | null
  }
  appliedFilters: JournalFilters
  filterOptions: {
    eventTypes: JournalFilterOption[]
    tracks: JournalFilterOption[]
    items: JournalFilterOption[]
    statuses: Array<{ value: JournalEventStatus; label: string }>
  }
}

export type CorrectionResult = {
  originalEventId: string
  replacementEventId: string
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

export type CorrectionDashboardPatch = DashboardPatch & {
  correctionResult: CorrectionResult
}

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
