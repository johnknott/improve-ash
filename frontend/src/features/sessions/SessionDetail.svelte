<script lang="ts">
  import { ArrowLeft, CheckCircle2, ClipboardPlus, FastForward, Play, Shuffle } from '@lucide/svelte'
  import type { DashboardData, PlanItem, ProjectedWork, SessionSlotResult } from '../../api/types'
  import {
    completeSession,
    openSessionSlotDialog,
    selectedSessionWorkId,
    skipSession,
    startSession,
    swapSessionSlot,
    updatingSession,
  } from '../../app/appState'
  import Badge from '../../components/ui/Badge.svelte'
  import Card from '../../components/ui/Card.svelte'

  let { data, work }: { data: DashboardData; work: ProjectedWork } = $props()

  let selections = $state<Record<string, string>>({})
  let occurrenceId = $derived(
    typeof work.session?.state.session_occurrence_id === 'string' ? work.session.state.session_occurrence_id : null
  )
  let slotResults = $derived(work.session?.slotResults ?? [])
  let canComplete = $derived(!!occurrenceId && work.status !== 'completed' && work.status !== 'skipped')
  let canSkip = $derived(!!occurrenceId && work.status !== 'completed' && work.status !== 'skipped')

  $effect(() => {
    selections = {
      ...Object.fromEntries(slotResults.map((slotResult) => [slotResult.id, slotResult.actualItemKey ?? slotResult.recommendedItemKey ?? ''])),
      ...selections,
    }
  })

  function itemOptions(slotResult: SessionSlotResult): PlanItem[] {
    const items = data.planDetail?.items ?? []
    const memberships = data.planDetail?.poolMemberships ?? []

    if (!slotResult.poolId) {
      return items
    }

    const itemIds = memberships
      .filter((membership) => membership.poolId === slotResult.poolId)
      .map((membership) => membership.itemId)

    return items.filter((item) => itemIds.includes(item.id))
  }

  function selectedChanged(slotResult: SessionSlotResult): boolean {
    const selected = selections[slotResult.id]
    return !!selected && selected !== (slotResult.actualItemKey ?? slotResult.recommendedItemKey)
  }

  async function saveSwap(slotResult: SessionSlotResult) {
    const actualItemKey = selections[slotResult.id]

    if (!actualItemKey) {
      return
    }

    await swapSessionSlot({ slotResultId: slotResult.id, actualItemKey })
  }
</script>

<section class="page-stack">
  <Card class="model-card">
    <div class="section-heading">
      <div>
        <p class="eyebrow">{work.plannedFor}</p>
        <h2>{work.title}</h2>
      </div>
      <Badge tone={work.status === 'completed' ? 'good' : work.status === 'skipped' ? 'warning' : 'info'}>
        {work.status}
      </Badge>
    </div>

    <p class="body-copy">{work.explanation}</p>

    <div class="session-detail-actions">
      <button class="secondary-button" type="button" onclick={() => selectedSessionWorkId.set(null)}>
        <ArrowLeft size={16} />
        <span>Back</span>
      </button>

      {#if !occurrenceId}
        <button class="primary-button" type="button" onclick={() => startSession(work)}>
          <Play size={16} />
          <span>Start session</span>
        </button>
      {:else}
        <button class="secondary-button" type="button" disabled={!canSkip || $updatingSession} onclick={() => skipSession({ sessionOccurrenceId: occurrenceId })}>
          <FastForward size={16} />
          <span>Skip</span>
        </button>
        <button class="primary-button" type="button" disabled={!canComplete || $updatingSession} onclick={() => completeSession({ sessionOccurrenceId: occurrenceId })}>
          <CheckCircle2 size={16} />
          <span>Complete</span>
        </button>
      {/if}
    </div>
  </Card>

  {#if occurrenceId && slotResults.length}
    <Card class="list-card">
      <div class="section-heading">
        <div>
          <p class="eyebrow">Session slots</p>
          <h2>Recommendations and actual work</h2>
        </div>
        <span>{slotResults.length}</span>
      </div>

      <div class="session-detail-list">
        {#each slotResults as slotResult (slotResult.id)}
          <article class="session-detail-row">
            <div>
              <h3>{slotResult.slotName ?? 'Slot'}</h3>
              <p>
                Recommended {slotResult.recommendedItemName ?? 'item'}
                {#if slotResult.actualItemName && slotResult.actualItemName !== slotResult.recommendedItemName}
                  · actual {slotResult.actualItemName}
                {/if}
              </p>
            </div>

            <label>
              Actual item
              <select bind:value={selections[slotResult.id]} disabled={!!slotResult.eventInstanceId || $updatingSession}>
                {#each itemOptions(slotResult) as item (item.id)}
                  <option value={item.key}>{item.name}</option>
                {/each}
              </select>
            </label>

            <div class="row-actions">
              <Badge tone={slotResult.eventInstanceId ? 'good' : slotResult.status === 'swapped' ? 'warning' : 'neutral'}>
                {slotResult.eventInstanceId ? 'logged' : slotResult.status}
              </Badge>

              {#if selectedChanged(slotResult) && !slotResult.eventInstanceId}
                <button class="secondary-button compact-button" type="button" disabled={$updatingSession} onclick={() => saveSwap(slotResult)}>
                  <Shuffle size={16} />
                  <span>Save swap</span>
                </button>
              {/if}

              {#if !slotResult.eventInstanceId}
                <button class="primary-button compact-button" type="button" onclick={() => openSessionSlotDialog(work, { ...slotResult, actualItemKey: selections[slotResult.id] })}>
                  <ClipboardPlus size={16} />
                  <span>Log</span>
                </button>
              {/if}
            </div>
          </article>
        {/each}
      </div>
    </Card>
  {:else if occurrenceId}
    <Card>
      <p class="body-copy">This session has started, but no slot results were materialized.</p>
    </Card>
  {:else}
    <Card>
      <p class="body-copy">Start the session to preserve these recommendations as slot results.</p>
      <div class="chip-list">
        {#each work.session?.recommendations ?? [] as item}
          <span class="model-chip">{item.name}</span>
        {/each}
      </div>
    </Card>
  {/if}
</section>
