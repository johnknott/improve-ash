export type PlanSummary = {
  item_types?: number
  items?: number
  pools?: number
  pool_memberships?: number
  environments?: number
  event_types?: number
  session_templates?: number
  session_slots?: number
  direct_goals?: number
  schedules?: number
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

export type TodaySummary = {
  date: string
}

export type DashboardData = {
  plans: Plan[]
  currentPlan: Plan | null
  today: TodaySummary | null
  journal?: unknown[]
  planDetail?: unknown
}

export type DemoPlanKind = 'gym' | 'vial_inventory'

export type CreatePlanInput = {
  name: string
  intention: string
  startsOn: string
  endsOn: string
  date?: string | null
}
