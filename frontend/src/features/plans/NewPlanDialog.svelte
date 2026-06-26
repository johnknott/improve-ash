<script lang="ts">
  import { Dialog } from 'bits-ui'
  import {
    closeNewPlanDialog,
    newPlanDialogOpen,
    planDialogPlan,
    selectedDate,
    submitNewPlan,
    submitPlanEdit,
  } from '../../app/appState'

  let name = $state('')
  let intention = $state('')
  let startsOn = $state('')
  let endsOn = $state('')
  let lengthMode = $state<'duration' | 'endDate'>('duration')
  let durationValue = $state(8)
  let durationUnit = $state<'days' | 'weeks' | 'months'>('weeks')
  let saving = $state(false)
  let error = $state<string | null>(null)
  let seededFor = $state('')
  const editingPlan = $derived($planDialogPlan)
  const isEditing = $derived(Boolean(editingPlan))

  $effect(() => {
    const seedKey = editingPlan ? `edit:${editingPlan.id}` : `new:${$selectedDate}`

    if ($newPlanDialogOpen && seededFor !== seedKey) {
      const start = editingPlan?.startsOn ?? $selectedDate
      const duration = editingPlan
        ? durationFromRange(editingPlan.startsOn, editingPlan.endsOn)
        : { value: 8, unit: 'weeks' as const }

      name = editingPlan?.name ?? ''
      intention = editingPlan?.intention ?? ''
      startsOn = start
      lengthMode = 'duration'
      durationValue = duration.value
      durationUnit = duration.unit
      endsOn = editingPlan?.endsOn ?? addDuration(start, durationValue, durationUnit)
      saving = false
      error = null
      seededFor = seedKey
    }

    if (!$newPlanDialogOpen) {
      seededFor = ''
    }
  })

  $effect(() => {
    if (lengthMode === 'duration' && startsOn) {
      endsOn = addDuration(startsOn, durationValue, durationUnit)
    }
  })

  async function handleSubmit() {
    if (!name.trim() || !intention.trim()) {
      error = 'Add a name and a short intention.'
      return
    }

    if (!startsOn || !endsOn) {
      error = 'Add a start date and plan length.'
      return
    }

    if (endsOn < startsOn) {
      error = 'End date must be after the start date.'
      return
    }

    saving = true
    error = null

    try {
      const input = {
        name: name.trim(),
        intention: intention.trim(),
        startsOn,
        endsOn,
      }

      if (editingPlan) {
        await submitPlanEdit({ ...input, id: editingPlan.id })
      } else {
        await submitNewPlan(input)
      }
    } catch {
      error = isEditing ? 'We could not update that plan.' : 'We could not create that plan.'
    } finally {
      saving = false
    }
  }

  function setLengthMode(mode: 'duration' | 'endDate') {
    lengthMode = mode

    if (mode === 'duration') {
      durationValue = Math.max(1, durationValue || 1)
      endsOn = addDuration(startsOn, durationValue, durationUnit)
    }
  }

  function handleDurationInput(value: string) {
    durationValue = Math.max(1, Number.parseInt(value, 10) || 1)
  }

  function addDuration(date: string, amount: number, unit: 'days' | 'weeks' | 'months'): string {
    if (!date) {
      return ''
    }

    if (unit === 'months') {
      return addDays(addMonths(date, amount), -1)
    }

    return addDays(date, (unit === 'weeks' ? amount * 7 : amount) - 1)
  }

  function durationFromRange(startsOn: string, endsOn: string): {
    value: number
    unit: 'days' | 'weeks' | 'months'
  } {
    const days = Math.max(1, daysBetweenInclusive(startsOn, endsOn))

    if (days % 7 === 0) {
      return { value: days / 7, unit: 'weeks' }
    }

    return { value: days, unit: 'days' }
  }

  function daysBetweenInclusive(startsOn: string, endsOn: string): number {
    const start = utcDate(startsOn).getTime()
    const end = utcDate(endsOn).getTime()

    return Math.floor((end - start) / 86_400_000) + 1
  }

  function addDays(date: string, days: number): string {
    const next = utcDate(date)
    next.setUTCDate(next.getUTCDate() + days)
    return isoDate(next)
  }

  function addMonths(date: string, months: number): string {
    const next = utcDate(date)
    const day = next.getUTCDate()

    next.setUTCMonth(next.getUTCMonth() + months)

    if (next.getUTCDate() !== day) {
      next.setUTCDate(0)
    }

    return isoDate(next)
  }

  function utcDate(date: string): Date {
    const [year, month, day] = date.split('-').map(Number)
    return new Date(Date.UTC(year, month - 1, day, 12))
  }

  function isoDate(date: Date): string {
    return [
      date.getUTCFullYear(),
      String(date.getUTCMonth() + 1).padStart(2, '0'),
      String(date.getUTCDate()).padStart(2, '0'),
    ].join('-')
  }
</script>

<Dialog.Root open={$newPlanDialogOpen} onOpenChange={(open) => !open && closeNewPlanDialog()}>
  <Dialog.Portal>
    <Dialog.Overlay class="dialog-overlay" />
    <Dialog.Content class="dialog-content plan-dialog">
      <div class="dialog-header">
        <div>
          <Dialog.Title>{isEditing ? 'Edit plan' : 'Define a plan'}</Dialog.Title>
        </div>
        <Dialog.Close class="icon-button" aria-label="Close">×</Dialog.Close>
      </div>

      <form class="dialog-form" onsubmit={(event) => { event.preventDefault(); handleSubmit() }}>
        <label>
          Plan name
          <input bind:value={name} disabled={saving} placeholder="Summer strength block" />
        </label>

        <label>
          Intention
          <input
            bind:value={intention}
            disabled={saving}
            placeholder="What should this plan help with?"
          />
        </label>

        <div class="timeline-grid">
          <label>
            Starts
            <input bind:value={startsOn} disabled={saving} type="date" />
          </label>

          <div class="plan-length-fields">
            <span class="field-label">Plan length</span>
            <div class="segmented-control" aria-label="Plan length mode">
              <button
                class:active={lengthMode === 'duration'}
                type="button"
                disabled={saving}
                onclick={() => setLengthMode('duration')}
              >
                Duration
              </button>
              <button
                class:active={lengthMode === 'endDate'}
                type="button"
                disabled={saving}
                onclick={() => setLengthMode('endDate')}
              >
                End date
              </button>
            </div>
          </div>
        </div>

        {#if lengthMode === 'duration'}
          <div class="form-grid duration-grid">
            <label>
              For
              <input
                value={durationValue}
                disabled={saving}
                min="1"
                type="number"
                oninput={(event) => handleDurationInput(event.currentTarget.value)}
              />
            </label>
            <label>
              Unit
              <select bind:value={durationUnit} disabled={saving}>
                <option value="days">days</option>
                <option value="weeks">weeks</option>
                <option value="months">months</option>
              </select>
            </label>
          </div>
        {:else}
          <label>
            Ends
            <input bind:value={endsOn} disabled={saving} type="date" />
          </label>
        {/if}

        {#if error}
          <p class="error inline-error">{error}</p>
        {/if}

        <div class="dialog-actions">
          <button class="secondary-button" type="button" disabled={saving} onclick={closeNewPlanDialog}>
            Cancel
          </button>
          <button class="primary-button" type="submit" disabled={saving}>
            {#if saving}
              {isEditing ? 'Saving' : 'Creating'}
            {:else}
              {isEditing ? 'Save changes' : 'Create plan'}
            {/if}
          </button>
        </div>
      </form>
    </Dialog.Content>
  </Dialog.Portal>
</Dialog.Root>
