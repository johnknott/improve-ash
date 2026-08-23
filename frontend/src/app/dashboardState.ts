import { derived, get, writable } from 'svelte/store'
import {
  completeSession as completeSessionRequest,
  correctEvent as correctEventRequest,
  createPlan as createPlanRequest,
  installDemoPlan as installDemoPlanRequest,
  loadDashboard as fetchDashboard,
  logEvent as logEventRequest,
  logSessionSlot as logSessionSlotRequest,
  logTrack as logTrackRequest,
  skipTrack as skipTrackRequest,
  skipSession as skipSessionRequest,
  skipSessionSlot as skipSessionSlotRequest,
  startSession as startSessionRequest,
  swapSessionSlot as swapSessionSlotRequest,
  updatePlan as updatePlanRequest,
  type LogEventInput,
  type CorrectEventInput,
  type LogTrackInput,
  type SlotActionInput,
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
import {
  invalidateJournalPage,
  resetJournalPage,
} from '../features/journal/journalState'
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
let dashboardGeneration = 0
let latestLoadRequest = 0

const updateInProgressMessage = 'Wait for the current update to finish.'

export async function loadDashboard(
  planId = get(selectedPlanId),
  date = get(selectedDate),
): Promise<void> {
  const loaded = get(dashboardStatus).loaded
  const generation = dashboardGeneration
  const requestId = ++latestLoadRequest

  dashboardStatus.update((status) => ({
    ...status,
    loading: !loaded,
    refreshing: loaded,
    error: null,
  }))

  try {
    const patch = await fetchDashboard(planId, date)

    if (generation !== dashboardGeneration || requestId !== latestLoadRequest) {
      return
    }

    applyDashboardPatch(patch)
    selectedDate.set(patch.today?.date ?? date)
  } catch {
    if (generation !== dashboardGeneration || requestId !== latestLoadRequest) {
      return
    }

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
    const previousPlanId = get(currentPlan)?.id ?? null
    const nextPlan = patch.currentPlan ?? null
    currentPlan.set(nextPlan)
    lastLoadedPlanId = nextPlan?.id ?? null
    selectedPlanId.set(lastLoadedPlanId)

    if (previousPlanId !== lastLoadedPlanId) {
      resetJournalPage()
    }
  }

  if ('today' in patch) {
    const nextToday = patch.today ?? null
    today.set(nextToday)

    if (nextToday) {
      selectedDate.set(nextToday.date)
    }
  }

  if (patch.journal) {
    journal.set(patch.journal)
    invalidateJournalPage()
  }

  if ('planDetail' in patch) {
    planDetail.set(patch.planDetail ?? null)
  }

  dashboardStatus.set({ loading: false, refreshing: false, loaded: true, error: null })
}

export function resetDashboard(): void {
  dashboardGeneration += 1
  latestLoadRequest += 1
  lastLoadedPlanId = null
  plans.set([])
  currentPlan.set(null)
  today.set(null)
  journal.set([])
  resetJournalPage()
  planDetail.set(null)
  selectedPlanId.set(null)
  selectedDate.set(todayIso())
  installingDemoPlan.set(null)
  // The next authenticated shell needs a fresh dashboard before it can show
  // an honest empty or ready state.
  dashboardStatus.set({ loading: true, refreshing: false, loaded: false, error: null })
  resetUiState()
}

export async function changeSelectedDate(date: string): Promise<void> {
  if (!date || date === get(selectedDate) || contextChangeBlocked()) {
    return
  }

  await loadDashboard(lastLoadedPlanId, date)
}

export async function changeSelectedPlan(planId: string): Promise<void> {
  if (!planId || planId === get(selectedPlanId) || contextChangeBlocked()) {
    return
  }

  await loadDashboard(planId, get(selectedDate))
}

export async function stepSelectedDate(days: number): Promise<void> {
  await changeSelectedDate(addDays(get(selectedDate), days))
}

export async function resetSelectedDate(): Promise<void> {
  await changeSelectedDate(todayIso())
}

function contextChangeBlocked(): boolean {
  const status = get(dashboardStatus)
  return status.loading || status.refreshing
}

export async function installDemoPlan(kind: DemoPlanKind): Promise<boolean> {
  if (contextChangeBlocked()) {
    showToast(updateInProgressMessage)
    return false
  }

  const generation = dashboardGeneration
  installingDemoPlan.set(kind)
  dashboardStatus.update((status) => ({ ...status, refreshing: true, error: null }))

  try {
    const patch = await installDemoPlanRequest(kind, get(selectedDate))

    if (generation !== dashboardGeneration) {
      return false
    }

    applyDashboardPatch(patch)
    showToast(kind === 'gym' ? 'Training demo ready.' : 'Inventory demo ready.')
    return true
  } catch {
    if (generation !== dashboardGeneration) {
      return false
    }

    dashboardStatus.update((status) => ({
      ...status,
      loading: false,
      refreshing: false,
      error: 'We could not install that demo plan.',
    }))
    return false
  } finally {
    if (generation === dashboardGeneration && get(installingDemoPlan) === kind) {
      installingDemoPlan.set(null)
    }
  }
}

// Write mutations share this shape: mark refreshing, apply the returned
// patch, optionally toast, and return false when logout/reset invalidates
// the response. Real failures are rethrown so callers can show them in
// place (the global banner stays out of it).
async function runMutation(
  mutate: () => Promise<DashboardPatch>,
  successToast?: string,
): Promise<boolean> {
  if (contextChangeBlocked()) {
    throw new Error(updateInProgressMessage)
  }

  const generation = dashboardGeneration
  dashboardStatus.update((status) => ({ ...status, refreshing: true, error: null }))

  try {
    const patch = await mutate()

    if (generation !== dashboardGeneration) {
      return false
    }

    applyDashboardPatch(patch)

    if (successToast) {
      showToast(successToast)
    }

    return true
  } catch (error) {
    if (generation !== dashboardGeneration) {
      return false
    }

    dashboardStatus.update((status) => ({ ...status, refreshing: false }))
    throw error
  }
}

export async function submitTrackLog(
  input: Omit<LogTrackInput, 'planId' | 'date'>,
  successToast = 'Logged.',
): Promise<boolean> {
  const planId = get(selectedPlanId)

  if (!planId) {
    throw new Error('Select a plan before logging.')
  }

  return runMutation(
    () => logTrackRequest({ ...input, planId, date: get(selectedDate) }),
    successToast,
  )
}

export async function submitTrackSkip(
  input: { trackKey: string; reason?: string | null },
  successToast = 'Skipped.',
): Promise<boolean> {
  const planId = get(selectedPlanId)

  if (!planId) {
    throw new Error('Select a plan before skipping.')
  }

  return runMutation(
    () => skipTrackRequest({ ...input, planId, date: get(selectedDate) }),
    successToast,
  )
}

export async function submitEventLog(
  input: Omit<LogEventInput, 'planId'>,
  successToast = 'Logged.',
): Promise<boolean> {
  const planId = get(selectedPlanId)

  if (!planId) {
    throw new Error('Select a plan before logging.')
  }

  return runMutation(() => logEventRequest({ ...input, planId }), successToast)
}

export async function submitEventCorrection(
  input: Omit<CorrectEventInput, 'date'>,
): Promise<boolean> {
  const planId = get(selectedPlanId)

  if (!planId || planId !== input.planId) {
    throw new Error('That journal entry is no longer in the selected plan.')
  }

  return runMutation(
    () => correctEventRequest({ ...input, date: get(selectedDate) }),
    'Correction saved. The original is still in your history.',
  )
}

export async function startProjectedSession(sessionTemplateId: string): Promise<boolean> {
  const planId = get(selectedPlanId)

  if (!planId) {
    throw new Error('Select a plan before starting a session.')
  }

  return runMutation(
    () => startSessionRequest(planId, sessionTemplateId, get(selectedDate)),
    'Session started.',
  )
}

export async function acceptSessionSlot(input: SlotActionInput): Promise<boolean> {
  return runMutation(() => logSessionSlotRequest(input, get(selectedDate)), 'Slot logged.')
}

export async function skipSlot(input: SlotActionInput): Promise<boolean> {
  return runMutation(() => skipSessionSlotRequest(input, get(selectedDate)), 'Slot skipped.')
}

export async function swapSlot(
  slotResultId: string,
  actualItemKey: string,
): Promise<boolean> {
  return runMutation(
    () => swapSessionSlotRequest(slotResultId, actualItemKey, get(selectedDate)),
    'Slot swapped.',
  )
}

export async function finishSession(sessionOccurrenceId: string): Promise<boolean> {
  return runMutation(
    () => completeSessionRequest(sessionOccurrenceId, get(selectedDate)),
    'Session completed.',
  )
}

export async function skipWholeSession(
  sessionOccurrenceId: string,
  note?: string | null,
): Promise<boolean> {
  return runMutation(
    () => skipSessionRequest(sessionOccurrenceId, get(selectedDate), note),
    'Session skipped.',
  )
}

// Plan form submissions rethrow the original error so the dialog can show
// field-level messages; the global error banner stays out of it.
export async function submitNewPlan(input: CreatePlanInput): Promise<boolean> {
  if (contextChangeBlocked()) {
    throw new Error(updateInProgressMessage)
  }

  const generation = dashboardGeneration
  dashboardStatus.update((status) => ({ ...status, refreshing: true, error: null }))

  try {
    const patch = await createPlanRequest({ ...input, date: get(selectedDate) })

    if (generation !== dashboardGeneration) {
      return false
    }

    applyDashboardPatch(patch)
    closeNewPlanDialog()
    showToast('Plan created.')
    return true
  } catch (error) {
    if (generation !== dashboardGeneration) {
      return false
    }

    dashboardStatus.update((status) => ({ ...status, refreshing: false }))
    throw error
  }
}

export async function submitPlanEdit(input: UpdatePlanInput): Promise<boolean> {
  if (contextChangeBlocked()) {
    throw new Error(updateInProgressMessage)
  }

  const generation = dashboardGeneration
  dashboardStatus.update((status) => ({ ...status, refreshing: true, error: null }))

  try {
    const patch = await updatePlanRequest({ ...input, date: get(selectedDate) })

    if (generation !== dashboardGeneration) {
      return false
    }

    applyDashboardPatch(patch)
    closeNewPlanDialog()
    showToast('Plan updated.')
    return true
  } catch (error) {
    if (generation !== dashboardGeneration) {
      return false
    }

    dashboardStatus.update((status) => ({ ...status, refreshing: false }))
    throw error
  }
}
