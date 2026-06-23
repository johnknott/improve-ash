import { get, writable } from 'svelte/store'
import {
  installDemoPlan as installDemoPlanRequest,
  loadDashboard as fetchDashboard,
  createPlan as createPlanRequest,
  todayIso,
} from '../api/improveClient'
import type {
  DashboardData,
  CreatePlanInput,
  DemoPlanKind,
} from '../api/types'

type DashboardState = {
  loading: boolean
  refreshing: boolean
  error: string | null
  data: DashboardData | null
}

type LogDialogState = {
  open: boolean
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
})

export const newPlanDialogOpen = writable(false)
export const checkInDialogOpen = writable(false)
export const toastMessage = writable<string | null>(null)
export const installingDemoPlan = writable<DemoPlanKind | null>(null)

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
  logDialogState.set({ open: false })
  newPlanDialogOpen.set(false)
  checkInDialogOpen.set(false)
  toastMessage.set(null)
  installingDemoPlan.set(null)
}

export function openLogDialog(): void {
  logDialogState.set({ open: true })
}

export function closeLogDialog(): void {
  logDialogState.set({ open: false })
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

export async function installDemoPlan(kind: DemoPlanKind): Promise<void> {
  installingDemoPlan.set(kind)
  dashboardState.update((state) => ({ ...state, refreshing: true, error: null }))

  try {
    setDashboardData(await installDemoPlanRequest(kind, get(selectedDate)))
    showToast(kind === 'gym' ? 'Training demo ready.' : 'Inventory demo ready.')
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
