<script lang="ts">
  import { BookOpen, FilterX, RefreshCw, TriangleAlert } from '@lucide/svelte'
  import { tick, untrack } from 'svelte'
  import type { JournalEventDetail, JournalFilters } from '../../api/types'
  import { selectedPlanId } from '../../app/dashboardState'
  import Button from '../../components/ui/Button.svelte'
  import Card from '../../components/ui/Card.svelte'
  import EmptyState from '../../components/ui/EmptyState.svelte'
  import LoadingState from '../../components/ui/LoadingState.svelte'
  import DemoPlanSetup from '../setup/DemoPlanSetup.svelte'
  import JournalEventDetailDialog from './JournalEventDetailDialog.svelte'
  import JournalEventRow from './JournalEventRow.svelte'
  import JournalFiltersView from './JournalFilters.svelte'
  import {
    applyJournalFilters,
    clearJournalFilters,
    journalAppliedFilters,
    journalDraftFilters,
    journalInvalidation,
    journalPage,
    journalPageStatus,
    loadJournalPage,
    loadMoreJournal,
    setJournalDraftFilters,
  } from './journalState'

  let selectedEvent = $state<JournalEventDetail | null>(null)
  let resultsHeading = $state<HTMLElement | null>(null)
  let announcement = $state('')

  let page = $derived(
    $journalPage?.planId === $selectedPlanId ? $journalPage : null,
  )
  let filtersDirty = $derived(!filtersEqual($journalDraftFilters, $journalAppliedFilters))
  let hasAppliedFilters = $derived(hasFilters($journalAppliedFilters))
  let busy = $derived(
    $journalPageStatus.loading ||
      $journalPageStatus.refreshing ||
      $journalPageStatus.loadingMore,
  )

  $effect(() => {
    const planId = $selectedPlanId
    const invalidation = $journalInvalidation
    void invalidation

    const openEvent = untrack(() => selectedEvent)

    if (openEvent && openEvent.planId !== planId) {
      selectedEvent = null
    }

    if (planId) {
      void loadJournalPage(planId)
    }
  })

  async function applyFilters() {
    const planId = $selectedPlanId

    if (!planId) return

    selectedEvent = null
    const loaded = await applyJournalFilters(planId)

    if (loaded) {
      announcement = `${$journalPage?.events.length ?? 0} journal entries shown.`
      await focusResults()
    }
  }

  async function clearFilters() {
    const planId = $selectedPlanId

    if (!planId) return

    selectedEvent = null
    const loaded = await clearJournalFilters(planId)

    if (loaded) {
      announcement = 'Journal filters cleared.'
      await focusResults()
    }
  }

  async function loadMore() {
    const planId = $selectedPlanId
    const before = page?.events.length ?? 0

    if (!planId) return

    const loaded = await loadMoreJournal(planId)

    if (loaded) {
      const after = $journalPage?.events.length ?? before
      announcement = `${Math.max(after - before, 0)} more journal entries loaded.`

      if (!$journalPage?.pageInfo.hasMore) {
        await focusResults()
      }
    }
  }

  async function retry() {
    if ($selectedPlanId) {
      await loadJournalPage($selectedPlanId)
    }
  }

  async function focusResults() {
    await tick()
    resultsHeading?.focus()
  }

  function correctionSaved() {
    announcement = 'Correction saved. The original entry remains in your history.'
    void focusResults()
  }

  function hasFilters(filters: JournalFilters): boolean {
    return Boolean(filters.eventTypeId || filters.trackId || filters.itemId || filters.status)
  }

  function filtersEqual(left: JournalFilters, right: JournalFilters): boolean {
    return (
      left.eventTypeId === right.eventTypeId &&
      left.trackId === right.trackId &&
      left.itemId === right.itemId &&
      left.status === right.status
    )
  }
</script>

<section class="page-stack journal-page">
  <p class="sr-only" aria-live="polite">{announcement}</p>

  {#if !$selectedPlanId}
    <Card>
      <DemoPlanSetup title="Install a demo plan first" />
    </Card>
  {:else if $journalPageStatus.loading && !page}
    <Card>
      <LoadingState message="Loading your journal" />
    </Card>
  {:else if $journalPageStatus.error && !page}
    <Card>
      <div class="journal-load-error" role="alert">
        <TriangleAlert size={26} aria-hidden="true" />
        <div>
          <h2>Could not load your journal</h2>
          <p>{$journalPageStatus.error}</p>
        </div>
        <Button variant="secondary" onclick={retry}>
          <RefreshCw size={16} aria-hidden="true" />
          Try again
        </Button>
      </div>
    </Card>
  {:else if page}
    <Card class="journal-filter-card">
      <div class="journal-section-heading">
        <div>
          <p class="eyebrow">History</p>
          <h2>Find what happened</h2>
        </div>
        {#if $journalPageStatus.refreshing}
          <span class="refresh-status" role="status">Updating…</span>
        {/if}
      </div>

      <JournalFiltersView
        filters={$journalDraftFilters}
        options={page.filterOptions}
        {busy}
        dirty={filtersDirty}
        onChange={setJournalDraftFilters}
        onApply={applyFilters}
        onClear={clearFilters}
      />
    </Card>

    {#if $journalPageStatus.error}
      <div class="journal-refresh-warning" role="alert">
        <span>{$journalPageStatus.error}</span>
        <Button variant="text" onclick={retry}>Try again</Button>
      </div>
    {/if}

    <section
      class="journal-results"
      aria-labelledby="journal-results-heading"
      aria-busy={$journalPageStatus.refreshing || $journalPageStatus.loadingMore}
    >
      <div class="journal-section-heading journal-results-heading">
        <div>
          <h2 id="journal-results-heading" bind:this={resultsHeading} tabindex="-1">
            Journal entries
          </h2>
          <p>
            {page.events.length} {page.events.length === 1 ? 'entry' : 'entries'} shown,
            newest first
          </p>
        </div>
      </div>

      {#if page.events.length === 0}
        <Card>
          {#if hasAppliedFilters}
            <EmptyState
              title="No journal entries match"
              message="Try clearing a filter to see more of your history."
            >
              {#snippet icon()}<FilterX size={26} aria-hidden="true" />{/snippet}
            </EmptyState>
            <div class="journal-empty-actions">
              <Button variant="secondary" onclick={clearFilters}>Clear filters</Button>
            </div>
          {:else}
            <EmptyState
              title="Nothing logged yet"
              message="Events, completed work, and intentional skips will appear here as you use Improve."
            >
              {#snippet icon()}<BookOpen size={26} aria-hidden="true" />{/snippet}
            </EmptyState>
          {/if}
        </Card>
      {:else}
        <ul class="journal-event-list">
          {#each page.events as event (event.id)}
            <li>
              <JournalEventRow {event} onOpen={(entry) => (selectedEvent = entry)} />
            </li>
          {/each}
        </ul>

        {#if page.pageInfo.hasMore}
          <div class="journal-pagination">
            <Button variant="secondary" disabled={busy} onclick={loadMore}>
              {$journalPageStatus.loadingMore ? 'Loading…' : 'Load more'}
            </Button>
          </div>
        {/if}
      {/if}
    </section>
  {/if}
</section>

<JournalEventDetailDialog
  event={selectedEvent}
  onClose={() => (selectedEvent = null)}
  onCorrected={correctionSaved}
/>
