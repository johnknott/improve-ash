import { writable } from 'svelte/store'
import type { Plan } from '../api/types'

export const logDialogOpen = writable(false)
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
  checkInDialogOpen.set(false)
  newPlanDialogOpen.set(false)
  planDialogPlan.set(null)
  toastMessage.set(null)
}
