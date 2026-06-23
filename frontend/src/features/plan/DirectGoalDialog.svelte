<script lang="ts">
  import { Dialog } from 'bits-ui'
  import type { DashboardData } from '../../api/types'
  import { submitDirectGoal } from '../../app/appState'

  let {
    data,
    open,
    onClose
  }: {
    data: DashboardData | null
    open: boolean
    onClose: () => void
  } = $props()

  let name = $state('')
  let eventChoice = $state('new')
  let eventName = $state('')
  let quantity = $state('')
  let unit = $state('')
  let saving = $state(false)
  let error = $state<string | null>(null)
  let seeded = $state(false)

  let planId = $derived(data?.currentPlan?.id ?? '')
  let eventTypes = $derived(data?.planDetail?.eventTypes ?? [])
  let creatingEvent = $derived(eventChoice === 'new')

  $effect(() => {
    if (open && !seeded) {
      name = ''
      eventChoice = eventTypes[0]?.id ?? 'new'
      eventName = ''
      quantity = ''
      unit = ''
      error = null
      seeded = true
    }

    if (!open) {
      seeded = false
    }
  })

  async function handleSubmit() {
    if (!planId) {
      error = 'Choose a plan before adding a goal.'
      return
    }

    if (!name.trim() || !quantity.trim() || !unit.trim()) {
      error = 'Add a name, amount, and unit.'
      return
    }

    if (creatingEvent && !eventName.trim()) {
      error = 'Say what this goal logs.'
      return
    }

    saving = true
    error = null

    try {
      await submitDirectGoal({
        planId,
        name: name.trim(),
        eventTypeId: creatingEvent ? null : eventChoice,
        eventName: creatingEvent ? eventName.trim() : null,
        quantity: quantity.trim(),
        unit: unit.trim(),
      })
      onClose()
    } catch {
      error = 'We could not add that goal.'
    } finally {
      saving = false
    }
  }
</script>

<Dialog.Root {open} onOpenChange={(nextOpen) => !nextOpen && onClose()}>
  <Dialog.Portal>
    <Dialog.Overlay class="dialog-overlay" />
    <Dialog.Content class="dialog-content small-dialog">
      <div class="dialog-header">
        <div>
          <Dialog.Title>Add goal</Dialog.Title>
          <Dialog.Description>Daily goals show up on Today.</Dialog.Description>
        </div>
        <Dialog.Close class="icon-button" aria-label="Close">×</Dialog.Close>
      </div>

      <form class="dialog-form" onsubmit={(event) => { event.preventDefault(); handleSubmit() }}>
        <label>
          Goal
          <input bind:value={name} disabled={saving} placeholder="Read for 15 minutes" />
        </label>

        <div class="form-grid">
          <label>
            Amount
            <input bind:value={quantity} disabled={saving} inputmode="decimal" placeholder="15" />
          </label>
          <label>
            Unit
            <input bind:value={unit} disabled={saving} placeholder="minutes" />
          </label>
        </div>

        <label>
          Logs as
          <select bind:value={eventChoice} disabled={saving}>
            {#if eventTypes.length === 0}
              <option value="new">New event type</option>
            {:else}
              {#each eventTypes as eventType (eventType.id)}
                <option value={eventType.id}>{eventType.name}</option>
              {/each}
              <option value="new">New event type</option>
            {/if}
          </select>
        </label>

        {#if creatingEvent}
          <label>
            Event name
            <input bind:value={eventName} disabled={saving} placeholder="Read" />
          </label>
        {/if}

        {#if error}
          <p class="error inline-error">{error}</p>
        {/if}

        <div class="dialog-actions">
          <button class="secondary-button" type="button" disabled={saving} onclick={onClose}>
            Cancel
          </button>
          <button class="primary-button" type="submit" disabled={saving}>
            {saving ? 'Adding' : 'Add goal'}
          </button>
        </div>
      </form>
    </Dialog.Content>
  </Dialog.Portal>
</Dialog.Root>
