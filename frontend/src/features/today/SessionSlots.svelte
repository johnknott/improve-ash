<script lang="ts">
  import { Check } from '@lucide/svelte'
  import { tick } from 'svelte'
  import type { SessionWork, SlotResult } from '../../api/types'
  import { acceptSessionSlot, planDetail, skipSlot, swapSlot } from '../../app/dashboardState'
  import { showToast } from '../../app/uiState'
  import Button from '../../components/ui/Button.svelte'
  import Select from '../../components/ui/Select.svelte'

  let { session }: { session: SessionWork } = $props()

  let sessionState = $derived(session.state)
  let started = $derived(session.slotResults.length > 0)
  let occurrenceId = $derived(sessionState.sessionOccurrenceId)
  let sessionOpen = $derived(
    sessionState.occurrenceStatus === 'started' || sessionState.occurrenceStatus === 'partial',
  )
  let loggedLine = $derived(
    started
      ? (sessionState.progressLabel ??
        `${sessionState.slotResultsLogged} of ${sessionState.slotResultsTotal} slots logged`)
      : '',
  )

  let pendingSlot = $state<string | null>(null)
  let swappingSlot = $state<string | null>(null)

  function swapped(slot: SlotResult): boolean {
    return Boolean(
      slot.actualItemId && slot.recommendedItemId && slot.actualItemId !== slot.recommendedItemId,
    )
  }

  function actionable(slot: SlotResult): boolean {
    return sessionOpen && !slot.eventInstanceId && slot.status !== 'skipped'
  }

  function poolItems(slot: SlotResult) {
    const detail = $planDetail

    if (!detail || !slot.poolId) {
      return []
    }

    const memberIds = new Set(
      detail.poolMemberships
        .filter((membership) => membership.poolId === slot.poolId)
        .map((membership) => membership.itemId),
    )

    return detail.items.filter((item) => memberIds.has(item.id) && !item.archived)
  }

  async function runSlotAction(
    slot: SlotResult,
    action: () => Promise<boolean>,
    trigger: HTMLElement,
    restoreSelector: string,
  ) {
    const originalRow = trigger.closest<HTMLElement>('.slot-row')
    let restoreFocus = true
    pendingSlot = slot.id

    try {
      restoreFocus = await action()
    } catch (caught) {
      showToast(caught instanceof Error ? caught.message : 'That slot action failed.')
    } finally {
      pendingSlot = null
      swappingSlot = null
      await tick()

      const row = originalRow?.isConnected
        ? originalRow
        : [...document.querySelectorAll<HTMLElement>('[data-slot-result]')].find(
            (candidate) => candidate.dataset.slotResult === slot.id,
          )
      const focusTarget = row?.querySelector<HTMLElement>(restoreSelector) ?? row
      const activeElement = document.activeElement
      const focusNeedsRestoring =
        !activeElement || activeElement === document.body || activeElement === trigger

      if (restoreFocus && focusNeedsRestoring) {
        focusTarget?.focus()
      }
    }
  }

  function acceptSlot(slot: SlotResult, trigger: HTMLButtonElement) {
    const actualKey = slot.actualItemKey ?? slot.recommendedItemKey

    if (!occurrenceId || !slot.slotKey || !actualKey) {
      return
    }

    runSlotAction(
      slot,
      () =>
        acceptSessionSlot({
          sessionOccurrenceId: occurrenceId,
          slotKey: slot.slotKey!,
          actualItemKey: actualKey,
          recommendedItemKey: slot.recommendedItemKey,
          payload: slot.suggestedPayload ?? {},
        }),
      trigger,
      '[data-slot-log-trigger]',
    )
  }

  function skipThisSlot(slot: SlotResult, trigger: HTMLButtonElement) {
    if (!occurrenceId || !slot.slotKey) {
      return
    }

    runSlotAction(
      slot,
      () =>
        skipSlot({
          sessionOccurrenceId: occurrenceId,
          slotKey: slot.slotKey!,
          recommendedItemKey: slot.recommendedItemKey,
        }),
      trigger,
      '[data-slot-skip-trigger]',
    )
  }

  function swapTo(slot: SlotResult, itemKey: string, trigger: HTMLSelectElement) {
    if (!itemKey) {
      return
    }

    runSlotAction(
      slot,
      () => swapSlot(slot.id, itemKey),
      trigger,
      '[data-slot-swap-trigger]',
    )
  }

  async function openSwap(slot: SlotResult, trigger: HTMLButtonElement) {
    const actions = trigger.parentElement
    swappingSlot = slot.id
    await tick()
    actions?.querySelector<HTMLSelectElement>('select')?.focus()
  }

  async function cancelSwap(trigger: HTMLButtonElement) {
    const actions = trigger.parentElement
    swappingSlot = null
    await tick()
    actions?.querySelector<HTMLButtonElement>('[data-slot-swap-trigger]')?.focus()
  }
</script>

{#if started}
  <div class="session-detail">
    {#if loggedLine}
      <p class="session-progress">{loggedLine}</p>
    {/if}

    <ul class="slot-list">
      {#each session.slotResults as slot (slot.id)}
        <li
          class="slot-row"
          data-slot-result={slot.id}
          class:done={Boolean(slot.eventInstanceId)}
          class:skipped={slot.status === 'skipped'}
          tabindex="-1"
        >
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
            {#if slot.status === 'skipped'}
              <span class="slot-note">skipped</span>
            {:else if slot.actualItemName}
              <span class="slot-item">{slot.actualItemName}</span>
              {#if swapped(slot)}
                <span class="slot-note">swapped from {slot.recommendedItemName}</span>
              {/if}
            {:else if slot.recommendedItemName}
              <span class="slot-item">{slot.recommendedItemName}</span>
            {/if}
          </div>

          {#if actionable(slot)}
            <div class="slot-actions">
              {#if swappingSlot === slot.id}
                <Select
                  value=""
                  disabled={pendingSlot === slot.id}
                  class="slot-swap-select"
                  aria-label="Choose a replacement for {slot.slotName ?? slot.slotKey ?? 'slot'}"
                  onchange={(event) => swapTo(slot, event.currentTarget.value, event.currentTarget)}
                >
                  <option value="" disabled>Swap to…</option>
                  {#each poolItems(slot) as poolItem (poolItem.id)}
                    <option value={poolItem.key}>{poolItem.name}</option>
                  {/each}
                </Select>
                <Button
                  variant="ghost"
                  class="slot-button"
                  disabled={pendingSlot === slot.id}
                  onclick={(event) => cancelSwap(event.currentTarget)}
                >
                  Cancel
                </Button>
              {:else}
                <Button
                  variant="secondary"
                  class="slot-button"
                  disabled={pendingSlot === slot.id}
                  data-slot-log-trigger
                  aria-label="Log {slot.slotName ?? slot.slotKey ?? 'slot'}"
                  onclick={(event) => acceptSlot(slot, event.currentTarget)}
                >
                  Log
                </Button>
                <Button
                  variant="ghost"
                  class="slot-button"
                  disabled={pendingSlot === slot.id}
                  data-slot-swap-trigger
                  aria-label="Swap {slot.slotName ?? slot.slotKey ?? 'slot'}"
                  onclick={(event) => openSwap(slot, event.currentTarget)}
                >
                  Swap
                </Button>
                <Button
                  variant="ghost"
                  class="slot-button"
                  disabled={pendingSlot === slot.id}
                  data-slot-skip-trigger
                  aria-label="Skip {slot.slotName ?? slot.slotKey ?? 'slot'}"
                  onclick={(event) => skipThisSlot(slot, event.currentTarget)}
                >
                  Skip
                </Button>
              {/if}
            </div>
          {/if}
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
