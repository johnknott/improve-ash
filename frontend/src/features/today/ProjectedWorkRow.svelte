<script lang="ts">
  import { ClipboardPlus, Dumbbell, Play } from '@lucide/svelte'
  import type { ProjectedWork } from '../../api/types'
  import {
    openLogDialog,
    openSessionSlotDialog,
    startSession,
    startingSessionId,
  } from '../../app/appState'
  import Badge from '../../components/ui/Badge.svelte'

  let { work, actionable = true }: { work: ProjectedWork; actionable?: boolean } = $props()

  let targetText = $derived(
    work.target.quantity
      ? `${work.target.quantity}${work.target.unit ? ` ${work.target.unit}` : ''}`
      : work.eventTypeName
        ? work.eventTypeName
        : work.kind === 'session'
          ? 'Session work'
          : 'Goal'
  )

  let tone = $derived(work.status === 'completed' ? 'good' : work.kind === 'session' ? 'info' : 'neutral')
  let occurrenceId = $derived(work.session?.state?.session_occurrence_id)
  let canStartSession = $derived(actionable && work.kind === 'session' && !occurrenceId)
  let sessionStarted = $derived(work.kind === 'session' && !!occurrenceId)
</script>

<article class="work-row">
  <div class="work-row-main">
    <div class="work-row-title">
      <h3>{work.title}</h3>
      <Badge {tone}>{work.status}</Badge>
    </div>
    <p>{targetText}</p>
    {#if work.explanation}
      <small>{work.explanation}</small>
    {/if}
    {#if work.session?.recommendations.length}
      <div class="chip-list compact-chips">
        {#each work.session.recommendations as item}
          <span class="model-chip">{item.name}</span>
        {/each}
      </div>
    {/if}

    {#if sessionStarted && work.session?.slotResults.length}
      <div class="session-slot-list">
        {#each work.session.slotResults as slotResult (slotResult.id)}
          <div class="session-slot-mini">
            <div>
              <strong>{slotResult.actualItemName ?? slotResult.recommendedItemName}</strong>
              <small>{slotResult.slotName ?? 'Slot'} · {slotResult.status}</small>
            </div>
            {#if slotResult.eventInstanceId}
              <Badge tone="good">logged</Badge>
            {:else if actionable}
              <button
                class="secondary-button compact-button"
                type="button"
                onclick={() => openSessionSlotDialog(work, slotResult)}
              >
                <Dumbbell size={16} />
                <span>Log</span>
              </button>
            {/if}
          </div>
        {/each}
      </div>
    {/if}
  </div>
  {#if canStartSession}
    <button
      class="primary-button compact-button"
      type="button"
      disabled={$startingSessionId === work.id}
      onclick={() => startSession(work)}
    >
      <Play size={16} />
      <span>{$startingSessionId === work.id ? 'Starting' : 'Start'}</span>
    </button>
  {:else if work.kind !== 'session'}
    <button class="secondary-button compact-button" type="button" disabled={!work.canLog || !actionable} onclick={() => openLogDialog(work)}>
      <ClipboardPlus size={16} />
      <span>{work.status === 'completed' ? 'Done' : 'Log'}</span>
    </button>
  {/if}
</article>
