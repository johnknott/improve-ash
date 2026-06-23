<script lang="ts">
  import { Dialog } from 'bits-ui'
  import {
    closeNewPlanDialog,
    newPlanDialogOpen,
    selectedDate,
    submitNewPlan,
  } from '../../app/appState'

  let name = $state('')
  let intention = $state('')
  let startsOn = $state('')
  let endsOn = $state('')
  let saving = $state(false)
  let error = $state<string | null>(null)
  let seededFor = $state('')

  $effect(() => {
    if ($newPlanDialogOpen && seededFor !== $selectedDate) {
      const start = $selectedDate

      name = ''
      intention = ''
      startsOn = start
      endsOn = addDays(start, 56)
      saving = false
      error = null
      seededFor = start
    }

    if (!$newPlanDialogOpen) {
      seededFor = ''
    }
  })

  async function handleSubmit() {
    if (!name.trim() || !intention.trim()) {
      error = 'Add a name and a short intention.'
      return
    }

    if (endsOn < startsOn) {
      error = 'End date must be after the start date.'
      return
    }

    saving = true
    error = null

    try {
      await submitNewPlan({
        name: name.trim(),
        intention: intention.trim(),
        startsOn,
        endsOn,
      })
    } catch {
      error = 'We could not create that plan.'
    } finally {
      saving = false
    }
  }

  function addDays(date: string, days: number): string {
    const next = new Date(`${date}T00:00:00`)
    next.setDate(next.getDate() + days)
    return next.toISOString().slice(0, 10)
  }
</script>

<Dialog.Root open={$newPlanDialogOpen} onOpenChange={(open) => !open && closeNewPlanDialog()}>
  <Dialog.Portal>
    <Dialog.Overlay class="dialog-overlay" />
    <Dialog.Content class="dialog-content small-dialog">
      <div class="dialog-header">
        <div>
          <Dialog.Title>New plan</Dialog.Title>
          <Dialog.Description>Start with a simple empty plan.</Dialog.Description>
        </div>
        <Dialog.Close class="icon-button" aria-label="Close">×</Dialog.Close>
      </div>

      <form class="dialog-form" onsubmit={(event) => { event.preventDefault(); handleSubmit() }}>
        <label>
          Name
          <input bind:value={name} disabled={saving} placeholder="Reading" />
        </label>

        <label>
          Intention
          <textarea
            bind:value={intention}
            disabled={saving}
            rows="3"
            placeholder="Read a little every day"
          ></textarea>
        </label>

        <div class="form-grid">
          <label>
            Starts
            <input bind:value={startsOn} disabled={saving} type="date" />
          </label>
          <label>
            Ends
            <input bind:value={endsOn} disabled={saving} type="date" />
          </label>
        </div>

        {#if error}
          <p class="error inline-error">{error}</p>
        {/if}

        <div class="dialog-actions">
          <button class="secondary-button" type="button" disabled={saving} onclick={closeNewPlanDialog}>
            Cancel
          </button>
          <button class="primary-button" type="submit" disabled={saving}>
            {saving ? 'Creating' : 'Create plan'}
          </button>
        </div>
      </form>
    </Dialog.Content>
  </Dialog.Portal>
</Dialog.Root>
