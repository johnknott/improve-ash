import { writable } from 'svelte/store'
import type { Plan, WorkItem } from '../api/types'

export const logDialogOpen = writable(false)

// The per-track log dialog is a single global instance; setting an item
// opens it (from a work card or the top-bar Log menu).
export const trackLogItem = writable<WorkItem | null>(null)

export function openTrackLog(item: WorkItem): void {
  trackLogItem.set(item)
}

export function closeTrackLog(): void {
  trackLogItem.set(null)
}
export const checkInDialogOpen = writable(false)
export const newPlanDialogOpen = writable(false)
export const planDialogPlan = writable<Plan | null>(null)
export const toastMessage = writable<string | null>(null)

export function openLogDialog(): void {
  logDialogOpen.set(true)
}

export function closeLogDialog(): void {
  logDialogOpen.set(false)
}

export function openNewPlanDialog(): void {
  planDialogPlan.set(null)
  newPlanDialogOpen.set(true)
}

export function openEditPlanDialog(plan: Plan): void {
  planDialogPlan.set(plan)
  newPlanDialogOpen.set(true)
}

export function closeNewPlanDialog(): void {
  newPlanDialogOpen.set(false)
  planDialogPlan.set(null)
}

export function showToast(message: string): void {
  toastMessage.set(message)
  window.setTimeout(() => {
    toastMessage.update((current) => (current === message ? null : current))
  }, 2600)
}

export function resetUiState(): void {
  logDialogOpen.set(false)
  trackLogItem.set(null)
  checkInDialogOpen.set(false)
  newPlanDialogOpen.set(false)
  planDialogPlan.set(null)
  toastMessage.set(null)
}
