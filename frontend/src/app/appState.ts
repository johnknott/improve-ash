import { get, writable } from 'svelte/store'
import {
  installDemoPlan as installDemoPlanRequest,
  loadDashboard as fetchDashboard,
  completeSession as completeSessionRequest,
  correctDose as correctDoseRequest,
  createDirectGoal as createDirectGoalRequest,
  createPlan as createPlanRequest,
  logDose as logDoseRequest,
  logSessionSlot as submitSessionSlotEvent,
  logEvent as submitLogEvent,
  skipSession as skipSessionRequest,
  startSession as startSessionRequest,
  swapSessionSlot as swapSessionSlotRequest,
  todayIso,
} from '../api/improveClient'
import type {
  DashboardData,
  CorrectDoseInput,
  CreateDirectGoalInput,
  CreatePlanInput,
  DemoPlanKind,
  DoseInput,
  JournalEntry,
  LogEventInput,
  LogSessionSlotInput,
  ProjectedWork,
  SessionStatusInput,
  SessionSlotResult,
  SwapSessionSlotInput,
  PlanItem,
} from '../api/types'

type DashboardState = {
  loading: boolean
  refreshing: boolean
  error: string | null
  data: DashboardData | null
}

type LogDialogState = {
  open: boolean
  work: ProjectedWork | null
}

type SessionSlotDialogState = {
  open: boolean
  work: ProjectedWork | null
  slotResult: SessionSlotResult | null
}

type DoseDialogState = {
  open: boolean
  item: PlanItem | null
  event: JournalEntry | null
}

export const dashboardState = writable<DashboardState>({
  loading: true,
  refreshing: false,
  error: null,
  data: null,
})

export const selectedPlanId = writable<string | null>(null)
export const selectedDate = writable(todayIso())

export const logDialogState = writable<LogDialogState>({
  open: false,
  work: null,
})

export const sessionSlotDialogState = writable<SessionSlotDialogState>({
  open: false,
  work: null,
  slotResult: null,
})

export const doseDialogState = writable<DoseDialogState>({
  open: false,
  item: null,
  event: null,
})

export const newPlanDialogOpen = writable(false)
export const checkInDialogOpen = writable(false)
export const toastMessage = writable<string | null>(null)
export const installingDemoPlan = writable<DemoPlanKind | null>(null)
export const startingSessionId = writable<string | null>(null)
export const selectedSessionWorkId = writable<string | null>(null)
export const updatingSession = writable(false)

let lastLoadedPlanId: string | null = null

export async function loadDashboard(planId = get(selectedPlanId), date = get(selectedDate)): Promise<void> {
  const current = get(dashboardState)

  dashboardState.set({
    ...current,
    loading: current.data === null,
    refreshing: current.data !== null,
    error: null,
  })

  try {
    setDashboardData(await fetchDashboard(planId, date))
  } catch {
    dashboardState.set({
      loading: false,
      refreshing: false,
      error: 'We could not load your planning dashboard.',
      data: current.data,
    })
  }
}

export function resetDashboard(): void {
  lastLoadedPlanId = null
  selectedPlanId.set(null)
  selectedDate.set(todayIso())
  dashboardState.set({ loading: false, refreshing: false, error: null, data: null })
  logDialogState.set({ open: false, work: null })
  sessionSlotDialogState.set({ open: false, work: null, slotResult: null })
  doseDialogState.set({ open: false, item: null, event: null })
  newPlanDialogOpen.set(false)
  checkInDialogOpen.set(false)
  toastMessage.set(null)
  installingDemoPlan.set(null)
  startingSessionId.set(null)
  selectedSessionWorkId.set(null)
  updatingSession.set(false)
}

export function openLogDialog(work: ProjectedWork | null = null): void {
  logDialogState.set({ open: true, work })
}

export function closeLogDialog(): void {
  logDialogState.set({ open: false, work: null })
}

export function openSessionSlotDialog(work: ProjectedWork, slotResult: SessionSlotResult): void {
  sessionSlotDialogState.set({ open: true, work, slotResult })
}

export function closeSessionSlotDialog(): void {
  sessionSlotDialogState.set({ open: false, work: null, slotResult: null })
}

export function openDoseDialog(item: PlanItem, event: JournalEntry | null = null): void {
  doseDialogState.set({ open: true, item, event })
}

export function closeDoseDialog(): void {
  doseDialogState.set({ open: false, item: null, event: null })
}

export function openNewPlanDialog(): void {
  newPlanDialogOpen.set(true)
}

export function closeNewPlanDialog(): void {
  newPlanDialogOpen.set(false)
}

export async function changeSelectedDate(date: string): Promise<void> {
  if (!date) {
    return
  }

  selectedDate.set(date)
  await loadDashboard(lastLoadedPlanId, date)
}

export async function stepSelectedDate(days: number): Promise<void> {
  await changeSelectedDate(addIsoDays(get(selectedDate), days))
}

export async function resetSelectedDate(): Promise<void> {
  await changeSelectedDate(todayIso())
}

export async function submitLog(input: LogEventInput): Promise<void> {
  await submitLogEvent(input)
  closeLogDialog()
  showToast('Logged.')
  await loadDashboard(lastLoadedPlanId, get(selectedDate))
}

export async function submitDose(input: DoseInput): Promise<void> {
  const data = await logDoseRequest({ ...input, date: get(selectedDate) })
  closeDoseDialog()
  setDashboardData(data)
  showToast('Dose logged.')
}

export async function submitDoseCorrection(input: CorrectDoseInput): Promise<void> {
  const data = await correctDoseRequest({ ...input, date: get(selectedDate) })
  closeDoseDialog()
  setDashboardData(data)
  showToast('Dose corrected.')
}

export async function installDemoPlan(kind: DemoPlanKind): Promise<void> {
  installingDemoPlan.set(kind)
  dashboardState.update((state) => ({ ...state, refreshing: true, error: null }))

  try {
    setDashboardData(await installDemoPlanRequest(kind, get(selectedDate)))
    showToast(kind === 'gym' ? 'Gym demo ready.' : 'Inventory demo ready.')
  } catch {
    dashboardState.update((state) => ({
      ...state,
      loading: false,
      refreshing: false,
      error: 'We could not install that demo plan.',
    }))
  } finally {
    installingDemoPlan.set(null)
  }
}

export async function submitNewPlan(input: CreatePlanInput): Promise<void> {
  dashboardState.update((state) => ({ ...state, refreshing: true, error: null }))

  try {
    setDashboardData(await createPlanRequest({ ...input, date: get(selectedDate) }))
    closeNewPlanDialog()
    showToast('Plan created.')
  } catch {
    dashboardState.update((state) => ({
      ...state,
      refreshing: false,
      error: 'We could not create that plan.',
    }))
    throw new Error('We could not create that plan.')
  }
}

export async function submitDirectGoal(input: CreateDirectGoalInput): Promise<void> {
  dashboardState.update((state) => ({ ...state, refreshing: true, error: null }))

  try {
    setDashboardData(await createDirectGoalRequest({ ...input, date: get(selectedDate) }))
    showToast('Goal added.')
  } catch {
    dashboardState.update((state) => ({
      ...state,
      refreshing: false,
      error: 'We could not add that goal.',
    }))
    throw new Error('We could not add that goal.')
  }
}

export async function startSession(work: ProjectedWork): Promise<void> {
  if (!work.session) {
    return
  }

  startingSessionId.set(work.id)
  dashboardState.update((state) => ({ ...state, refreshing: true, error: null }))

  try {
    const data = await startSessionRequest({
      planId: work.planId,
      sessionTemplateId: work.session.sessionTemplateId,
      date: work.plannedFor,
    })
    lastLoadedPlanId = data.currentPlan?.id ?? null
    selectedPlanId.set(lastLoadedPlanId)
    dashboardState.set({ loading: false, refreshing: false, error: null, data })
    showToast('Session started.')
  } catch {
    dashboardState.update((state) => ({
      ...state,
      refreshing: false,
      error: 'We could not start that session.',
    }))
  } finally {
    startingSessionId.set(null)
  }
}

export async function submitSessionSlot(input: LogSessionSlotInput): Promise<void> {
  const data = await submitSessionSlotEvent({ ...input, date: get(selectedDate) })
  closeSessionSlotDialog()
  setDashboardData(data)
  showToast('Slot logged.')
}

export function selectSession(work: ProjectedWork): void {
  selectedSessionWorkId.set(work.id)
}

export async function swapSessionSlot(input: SwapSessionSlotInput): Promise<void> {
  updatingSession.set(true)

  try {
    setDashboardData(await swapSessionSlotRequest({ ...input, date: get(selectedDate) }))
    showToast('Slot swapped.')
  } finally {
    updatingSession.set(false)
  }
}

export async function completeSession(input: SessionStatusInput): Promise<void> {
  updatingSession.set(true)

  try {
    setDashboardData(await completeSessionRequest({ ...input, date: get(selectedDate) }))
    showToast('Session completed.')
  } finally {
    updatingSession.set(false)
  }
}

export async function skipSession(input: SessionStatusInput): Promise<void> {
  updatingSession.set(true)

  try {
    setDashboardData(await skipSessionRequest({ ...input, date: get(selectedDate) }))
    showToast('Session skipped.')
  } finally {
    updatingSession.set(false)
  }
}

function setDashboardData(data: DashboardData): void {
  lastLoadedPlanId = data.currentPlan?.id ?? null
  selectedPlanId.set(lastLoadedPlanId)
  selectedDate.set(data.today?.date ?? get(selectedDate))
  dashboardState.set({ loading: false, refreshing: false, error: null, data })
}

function addIsoDays(date: string, days: number): string {
  const [year, month, day] = date.split('-').map(Number)
  const next = new Date(Date.UTC(year, month - 1, day + days, 12))

  return [
    next.getUTCFullYear(),
    String(next.getUTCMonth() + 1).padStart(2, '0'),
    String(next.getUTCDate()).padStart(2, '0'),
  ].join('-')
}

export function showToast(message: string): void {
  toastMessage.set(message)
  window.setTimeout(() => {
    toastMessage.update((current) => (current === message ? null : current))
  }, 2600)
}
