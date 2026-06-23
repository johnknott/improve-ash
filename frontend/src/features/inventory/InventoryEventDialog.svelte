<script lang="ts">
  import { Dialog } from 'bits-ui'
  import type { DashboardData } from '../../api/types'
  import {
    closeLinkedEventDialog,
    linkedEventDialogState,
    submitLinkedEvent,
    submitLinkedEventCorrection,
  } from '../../app/appState'

  let { data }: { data: DashboardData | null } = $props()

  let quantity = $state('')
  let unit = $state('')
  let effectiveAt = $state('')
  let site = $state('')
  let note = $state('')
  let correctionNote = $state('')
  let saving = $state(false)
  let error = $state<string | null>(null)
  let seededFor = $state('')

  let item = $derived($linkedEventDialogState.item)
  let event = $derived($linkedEventDialogState.event)
  let eventTypeId = $derived($linkedEventDialogState.eventTypeId)
  let role = $derived($linkedEventDialogState.role)
  let planId = $derived(data?.currentPlan?.id ?? '')
  let isCorrection = $derived(!!event)

  $effect(() => {
    const seedKey = $linkedEventDialogState.open ? `${item?.id ?? ''}:${event?.id ?? 'new'}` : ''

    if (seedKey && seedKey !== seededFor) {
      quantity = event?.quantity ?? ''
      unit = event?.unit ?? stateValue(item?.state?.calculatedState.unit) ?? stateValue(item?.facts.unit) ?? ''
      effectiveAt = event?.effectiveAt ? toLocalDateTime(event.effectiveAt) : ''
      site = ''
      note = event?.note ?? ''
      correctionNote = ''
      error = null
      seededFor = seedKey
    }

    if (!$linkedEventDialogState.open) {
      seededFor = ''
    }
  })

  async function handleSubmit() {
    if (!planId || !item || !eventTypeId || !role) {
      error = 'Choose an item and event before logging.'
      return
    }

    if (!quantity.trim() || !unit.trim()) {
      error = 'Enter an amount and unit.'
      return
    }

    saving = true
    error = null

    try {
      const input = {
        planId,
        itemId: item.id,
        eventTypeId,
        role,
        quantity: quantity.trim(),
        unit: unit.trim(),
        effectiveAt: effectiveAt ? new Date(effectiveAt).toISOString() : null,
        note: note.trim() || null,
        payload: payload(site.trim(), note.trim(), quantity.trim(), unit.trim()),
      }

      if (event) {
        await submitLinkedEventCorrection({
          ...input,
          originalEventId: event.id,
          correctionNote: correctionNote.trim() || 'Corrected from inventory',
        })
      } else {
        await submitLinkedEvent(input)
      }
    } catch {
      error = isCorrection ? 'We could not correct that event.' : 'We could not log that event.'
    } finally {
      saving = false
    }
  }

  function stateValue(value: unknown): string | null {
    if (typeof value === 'string') {
      return value
    }

    if (typeof value === 'number') {
      return String(value)
    }

    return null
  }

  function toLocalDateTime(value: string): string {
    const date = new Date(value)
    const offset = date.getTimezoneOffset() * 60000
    return new Date(date.getTime() - offset).toISOString().slice(0, 16)
  }

  function payload(site: string, note: string, quantity: string, unit: string): Record<string, unknown> {
    return {
      amount: quantity,
      unit,
      ...(site ? { site } : {}),
      ...(note ? { notes: note } : {}),
    }
  }
</script>

<Dialog.Root open={$linkedEventDialogState.open} onOpenChange={(open) => !open && closeLinkedEventDialog()}>
  <Dialog.Portal>
    <Dialog.Overlay class="dialog-overlay" />
    <Dialog.Content class="dialog-content small-dialog">
      <div class="dialog-header">
        <div>
          <Dialog.Title>{isCorrection ? 'Correct event' : 'Log event'}</Dialog.Title>
          <Dialog.Description>{item?.name ?? 'Choose an item'} inventory event.</Dialog.Description>
        </div>
        <Dialog.Close class="icon-button" aria-label="Close">×</Dialog.Close>
      </div>

      <form class="dialog-form" onsubmit={(submitEvent) => { submitEvent.preventDefault(); handleSubmit() }}>
        <div class="form-grid">
          <label>
            Amount
            <input bind:value={quantity} disabled={saving} inputmode="decimal" placeholder="250" />
          </label>
          <label>
            Unit
            <input bind:value={unit} disabled={saving} placeholder="mcg" />
          </label>
        </div>

        <label>
          When
          <input bind:value={effectiveAt} disabled={saving} type="datetime-local" />
        </label>

        <label>
          Site
          <input bind:value={site} disabled={saving} placeholder="Optional" />
        </label>

        <label>
          Note
          <textarea bind:value={note} disabled={saving} rows="3" placeholder="Optional detail"></textarea>
        </label>

        {#if isCorrection}
          <label>
            Correction note
            <input bind:value={correctionNote} disabled={saving} placeholder="What changed?" />
          </label>
        {/if}

        {#if error}
          <p class="error inline-error">{error}</p>
        {/if}

        <div class="dialog-actions">
          <button class="secondary-button" type="button" disabled={saving} onclick={closeLinkedEventDialog}>
            Cancel
          </button>
          <button class="primary-button" type="submit" disabled={saving}>
            {saving ? 'Saving' : isCorrection ? 'Save correction' : 'Log event'}
          </button>
        </div>
      </form>
    </Dialog.Content>
  </Dialog.Portal>
</Dialog.Root>
