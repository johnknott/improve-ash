import { get, writable } from 'svelte/store'
import {
  loadJournalPage as fetchJournalPage,
  type LoadJournalPageInput,
} from '../../api/improveClient'
import type { JournalFilters, JournalPageData } from '../../api/types'

export type JournalPageStatus = {
  loading: boolean
  refreshing: boolean
  loadingMore: boolean
  loaded: boolean
  stale: boolean
  error: string | null
}

const DEFAULT_PAGE_LIMIT = 20

export function emptyJournalFilters(): JournalFilters {
  return {
    eventTypeId: null,
    trackId: null,
    itemId: null,
    status: null,
  }
}

export const journalPage = writable<JournalPageData | null>(null)
export const journalDraftFilters = writable<JournalFilters>(emptyJournalFilters())
export const journalAppliedFilters = writable<JournalFilters>(emptyJournalFilters())
export const journalInvalidation = writable(0)
export const journalPageStatus = writable<JournalPageStatus>(initialStatus())

let journalGeneration = 0
let latestJournalRequest = 0
let activePlanId: string | null = null

export async function loadJournalPage(planId: string): Promise<boolean> {
  if (!planId) {
    resetJournalPage()
    return false
  }

  preparePlan(planId)

  return fetchPage({
    planId,
    limit: DEFAULT_PAGE_LIMIT,
    ...get(journalAppliedFilters),
  })
}

export async function applyJournalFilters(
  planId: string,
  filters = get(journalDraftFilters),
): Promise<boolean> {
  if (!planId) {
    return false
  }

  preparePlan(planId)
  const nextFilters = normalizeFilters(filters)
  journalDraftFilters.set(nextFilters)
  journalAppliedFilters.set(nextFilters)

  return fetchPage({
    planId,
    limit: DEFAULT_PAGE_LIMIT,
    ...nextFilters,
  })
}

export function setJournalDraftFilters(filters: JournalFilters): void {
  journalDraftFilters.set(normalizeFilters(filters))
}

export async function clearJournalFilters(planId: string): Promise<boolean> {
  return applyJournalFilters(planId, emptyJournalFilters())
}

export async function loadMoreJournal(planId: string): Promise<boolean> {
  const page = get(journalPage)
  const status = get(journalPageStatus)

  if (
    !planId ||
    page?.planId !== planId ||
    !page.pageInfo.hasMore ||
    !page.pageInfo.nextCursor ||
    status.loading ||
    status.refreshing ||
    status.loadingMore
  ) {
    return false
  }

  return fetchPage(
    {
      planId,
      limit: page.pageInfo.limit,
      cursor: page.pageInfo.nextCursor,
      ...get(journalAppliedFilters),
    },
    true,
  )
}

// Dashboard mutations carry a five-event preview. They invalidate this
// independently paginated page but must never overwrite it. The mounted
// Journal page watches this token and reloads its current plan and filters.
export function invalidateJournalPage(): void {
  latestJournalRequest += 1
  journalInvalidation.update((value) => value + 1)
  journalPageStatus.update((status) => ({
    ...status,
    loading: false,
    refreshing: false,
    loadingMore: false,
    stale: true,
    error: null,
  }))
}

export function resetJournalPage(): void {
  journalGeneration += 1
  latestJournalRequest += 1
  activePlanId = null
  journalPage.set(null)
  journalDraftFilters.set(emptyJournalFilters())
  journalAppliedFilters.set(emptyJournalFilters())
  journalPageStatus.set(initialStatus())
  journalInvalidation.update((value) => value + 1)
}

async function fetchPage(input: LoadJournalPageInput, append = false): Promise<boolean> {
  const generation = journalGeneration
  const requestId = ++latestJournalRequest
  const currentPage = get(journalPage)
  const hasCurrentPage = currentPage?.planId === input.planId

  journalPageStatus.update((status) => ({
    ...status,
    loading: !hasCurrentPage,
    refreshing: hasCurrentPage && !append,
    loadingMore: append,
    stale: false,
    error: null,
  }))

  try {
    const response = await fetchJournalPage(input)

    if (!requestIsCurrent(generation, requestId, input.planId)) {
      return false
    }

    if (response.planId !== input.planId) {
      journalPage.set(null)
      journalPageStatus.set({
        loading: false,
        refreshing: false,
        loadingMore: false,
        loaded: false,
        stale: false,
        error: 'We could not load that plan’s journal.',
      })
      return false
    }

    if (append) {
      const existing = get(journalPage)

      if (existing?.planId !== input.planId) {
        return false
      }

      const seenIds = new Set(existing.events.map((event) => event.id))
      journalPage.set({
        ...response,
        events: [
          ...existing.events,
          ...response.events.filter((event) => !seenIds.has(event.id)),
        ],
      })
    } else {
      journalPage.set(response)
    }

    journalAppliedFilters.set(normalizeFilters(response.appliedFilters))
    journalPageStatus.set({
      loading: false,
      refreshing: false,
      loadingMore: false,
      loaded: true,
      stale: false,
      error: null,
    })
    return true
  } catch (error) {
    if (!requestIsCurrent(generation, requestId, input.planId)) {
      return false
    }

    journalPageStatus.update((status) => ({
      ...status,
      loading: false,
      refreshing: false,
      loadingMore: false,
      loaded: hasCurrentPage,
      error: error instanceof Error ? error.message : 'We could not load your journal.',
    }))
    return false
  }
}

function preparePlan(planId: string): void {
  if (activePlanId === planId) {
    return
  }

  latestJournalRequest += 1
  activePlanId = planId
  journalPage.set(null)
  journalDraftFilters.set(emptyJournalFilters())
  journalAppliedFilters.set(emptyJournalFilters())
  journalPageStatus.set(initialStatus())
}

function requestIsCurrent(generation: number, requestId: number, planId: string): boolean {
  return (
    generation === journalGeneration &&
    requestId === latestJournalRequest &&
    planId === activePlanId
  )
}

function normalizeFilters(filters: JournalFilters): JournalFilters {
  return {
    eventTypeId: filters.eventTypeId || null,
    trackId: filters.trackId || null,
    itemId: filters.itemId || null,
    status: filters.status || null,
  }
}

function initialStatus(): JournalPageStatus {
  return {
    loading: false,
    refreshing: false,
    loadingMore: false,
    loaded: false,
    stale: false,
    error: null,
  }
}
