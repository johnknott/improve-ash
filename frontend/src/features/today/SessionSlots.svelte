<script lang="ts">
  import { Check } from '@lucide/svelte'
  import type { SessionWork, SlotResult } from '../../api/types'

  let { session }: { session: SessionWork } = $props()

  let state = $derived(session.state)
  let started = $derived(session.slotResults.length > 0)
  let loggedLine = $derived(
    started
      ? (state.progressLabel ??
        `${state.slotResultsLogged} of ${state.slotResultsTotal} slots logged`)
      : '',
  )

  function swapped(slot: SlotResult): boolean {
    return Boolean(
      slot.actualItemId && slot.recommendedItemId && slot.actualItemId !== slot.recommendedItemId,
    )
  }
</script>

{#if started}
  <div class="session-detail">
    {#if loggedLine}
      <p class="session-progress">{loggedLine}</p>
    {/if}

    <ul class="slot-list">
      {#each session.slotResults as slot (slot.id)}
        <li class="slot-row" class:done={Boolean(slot.eventInstanceId)}>
          <span class="slot-check" aria-hidden="true">
            {#if slot.eventInstanceId}
              <Check size={13} />
            {/if}
          </span>

          <div class="slot-main">
            <span class="slot-name">{slot.slotName ?? slot.slotKey ?? 'Slot'}</span>
            {#if slot.poolName}
              <span class="slot-pool">{slot.poolName}</span>
            {/if}
          </div>

          <div class="slot-outcome">
            {#if slot.actualItemName}
              <span class="slot-item">{slot.actualItemName}</span>
              {#if swapped(slot)}
                <span class="slot-note">swapped from {slot.recommendedItemName}</span>
              {/if}
            {:else if slot.recommendedItemName}
              <span class="slot-item">{slot.recommendedItemName}</span>
            {/if}
          </div>
        </li>
      {/each}
    </ul>
  </div>
{:else if session.recommendations.length > 0}
  <div class="session-detail">
    <ul class="slot-list">
      {#each session.recommendations as recommendation (recommendation.sessionSlotId)}
        <li class="slot-row">
          <span class="slot-check" aria-hidden="true"></span>

          <div class="slot-main">
            <span class="slot-name">
              {recommendation.slotName ?? recommendation.slotKey ?? 'Slot'}
            </span>
            {#if recommendation.poolName}
              <span class="slot-pool">
                {recommendation.poolName}{recommendation.count > 1
                  ? ` × ${recommendation.count}`
                  : ''}
              </span>
            {/if}
          </div>

          <div class="slot-outcome">
            {#if recommendation.items.length > 0}
              <span class="slot-item">
                {recommendation.items.map((item) => item.name).join(', ')}
              </span>
              {#if recommendation.items[0].reason}
                <span class="slot-note">{recommendation.items[0].reason}</span>
              {/if}
            {/if}
          </div>
        </li>
      {/each}
    </ul>
  </div>
{/if}
