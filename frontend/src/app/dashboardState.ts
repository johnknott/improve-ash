import { derived, get, writable } from 'svelte/store'
import {
  createPlan as createPlanRequest,
  installDemoPlan as installDemoPlanRequest,
  loadDashboard as fetchDashboard,
  updatePlan as updatePlanRequest,
} from '../api/improveClient'
import type {
  CreatePlanInput,
  DashboardData,
  DashboardPatch,
  DemoPlanKind,
  JournalEvent,
  Plan,
  PlanDetail,
  Today,
  UpdatePlanInput,
} from '../api/types'
import { addDays, todayIso } from '../lib/dates'
import { closeNewPlanDialog, resetUiState, showToast } from './uiState'

// One store per dashboard slice, so pages can subscribe to (and later
// refresh) only what they touch. Mutations return DashboardPatch with just
// the slices they invalidated; applyDashboardPatch merges per slice.
export const plans = writable<Plan[]>([])
export const currentPlan = writable<Plan | null>(null)
export const today = writable<Today | null>(null)
export const journal = writable<JournalEvent[]>([])
export const planDetail = writable<PlanDetail | null>(null)

export const selectedPlanId = writable<string | null>(null)
export const selectedDate = writable(todayIso())
export const installingDemoPlan = writable<DemoPlanKind | null>(null)

type DashboardStatus = {
  loading: boolean
  refreshing: boolean
  loaded: boolean
  error: string | null
}

export const dashboardStatus = writable<DashboardStatus>({
  loading: true,
  refreshing: false,
  loaded: false,
  error: null,
})

// Combined view for components that render several slices at once.
export const dashboardData = derived(
  [dashboardStatus, plans, currentPlan, today, journal, planDetail],
  ([status, planList, plan, todaySlice, journalSlice, detail]): DashboardData | null =>
    status.loaded
      ? {
          plans: planList,
          currentPlan: plan,
          today: todaySlice,
          journal: journalSlice,
          planDetail: detail,
        }
      : null,
)

let lastLoadedPlanId: string | null = null

export async function loadDashboard(
  planId = get(selectedPlanId),
  date = get(selectedDate),
): Promise<void> {
  const loaded = get(dashboardStatus).loaded

  dashboardStatus.update((status) => ({
    ...status,
    loading: !loaded,
    refreshing: loaded,
    error: null,
  }))

  try {
    applyDashboardPatch(await fetchDashboard(planId, date))
  } catch {
    dashboardStatus.update((status) => ({
      ...status,
      loading: false,
      refreshing: false,
      error: 'We could not load your planning dashboard.',
    }))
  }
}

export function applyDashboardPatch(patch: DashboardPatch): void {
  if (patch.plans) {
    plans.set(patch.plans)
  }

  if ('currentPlan' in patch) {
    currentPlan.set(patch.currentPlan ?? null)
  }

  if ('today' in patch) {
    today.set(patch.today ?? null)
  }

  if (patch.journal) {
    journal.set(patch.journal)
  }

  if ('planDetail' in patch) {
    planDetail.set(patch.planDetail ?? null)
  }

  lastLoadedPlanId = get(currentPlan)?.id ?? lastLoadedPlanId
  selectedPlanId.set(lastLoadedPlanId)
  selectedDate.set(get(today)?.date ?? get(selectedDate))
  dashboardStatus.set({ loading: false, refreshing: false, loaded: true, error: null })
}

export function resetDashboard(): void {
  lastLoadedPlanId = null
  plans.set([])
  currentPlan.set(null)
  today.set(null)
  journal.set([])
  planDetail.set(null)
  selectedPlanId.set(null)
  selectedDate.set(todayIso())
  installingDemoPlan.set(null)
  dashboardStatus.set({ loading: false, refreshing: false, loaded: false, error: null })
  resetUiState()
}

export async function changeSelectedDate(date: string): Promise<void> {
  if (!date) {
    return
  }

  selectedDate.set(date)
  await loadDashboard(lastLoadedPlanId, date)
}

export async function stepSelectedDate(days: number): Promise<void> {
  await changeSelectedDate(addDays(get(selectedDate), days))
}

export async function resetSelectedDate(): Promise<void> {
  await changeSelectedDate(todayIso())
}

export async function installDemoPlan(kind: DemoPlanKind): Promise<void> {
  installingDemoPlan.set(kind)
  dashboardStatus.update((status) => ({ ...status, refreshing: true, error: null }))

  try {
    applyDashboardPatch(await installDemoPlanRequest(kind, get(selectedDate)))
    showToast(kind === 'gym' ? 'Training demo ready.' : 'Inventory demo ready.')
  } catch {
    dashboardStatus.update((status) => ({
      ...status,
      loading: false,
      refreshing: false,
      error: 'We could not install that demo plan.',
    }))
  } finally {
    installingDemoPlan.set(null)
  }
}

// Plan form submissions rethrow the original error so the dialog can show
// field-level messages; the global error banner stays out of it.
export async function submitNewPlan(input: CreatePlanInput): Promise<void> {
  dashboardStatus.update((status) => ({ ...status, refreshing: true, error: null }))

  try {
    applyDashboardPatch(await createPlanRequest({ ...input, date: get(selectedDate) }))
    closeNewPlanDialog()
    showToast('Plan created.')
  } catch (error) {
    dashboardStatus.update((status) => ({ ...status, refreshing: false }))
    throw error
  }
}

export async function submitPlanEdit(input: UpdatePlanInput): Promise<void> {
  dashboardStatus.update((status) => ({ ...status, refreshing: true, error: null }))

  try {
    applyDashboardPatch(await updatePlanRequest({ ...input, date: get(selectedDate) }))
    closeNewPlanDialog()
    showToast('Plan updated.')
  } catch (error) {
    dashboardStatus.update((status) => ({ ...status, refreshing: false }))
    throw error
  }
}
