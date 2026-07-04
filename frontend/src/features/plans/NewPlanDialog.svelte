<script lang="ts">
  import { ApiRequestError } from '../../api/improveClient'
  import { selectedDate, submitNewPlan, submitPlanEdit } from '../../app/dashboardState'
  import { closeNewPlanDialog, newPlanDialogOpen, planDialogPlan } from '../../app/uiState'
  import DateInput from '../../components/ui/DateInput.svelte'
  import Field from '../../components/ui/Field.svelte'
  import FormDialog from '../../components/ui/FormDialog.svelte'
  import NumberInput from '../../components/ui/NumberInput.svelte'
  import Select from '../../components/ui/Select.svelte'
  import TextInput from '../../components/ui/TextInput.svelte'
  import { addDays, addMonths, daysBetweenInclusive } from '../../lib/dates'

  type FieldName = 'name' | 'intention' | 'startsOn' | 'endsOn'

  let name = $state('')
  let intention = $state('')
  let startsOn = $state('')
  let endsOn = $state('')
  let lengthMode = $state<'duration' | 'endDate'>('duration')
  let durationValue = $state(8)
  let durationUnit = $state<'days' | 'weeks' | 'months'>('weeks')
  let saving = $state(false)
  let error = $state<string | null>(null)
  let fieldErrors = $state<Partial<Record<FieldName, string>>>({})
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
      fieldErrors = {}
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

  function validate(): Partial<Record<FieldName, string>> {
    const problems: Partial<Record<FieldName, string>> = {}

    if (!name.trim()) {
      problems.name = 'Add a plan name.'
    }

    if (!intention.trim()) {
      problems.intention = 'Add a short intention.'
    }

    if (!startsOn) {
      problems.startsOn = 'Add a start date.'
    }

    if (!endsOn) {
      problems.endsOn = 'Add a plan length.'
    } else if (startsOn && endsOn < startsOn) {
      problems.endsOn = 'End date must be after the start date.'
    }

    return problems
  }

  async function handleSubmit() {
    fieldErrors = validate()
    error = null

    if (Object.keys(fieldErrors).length > 0) {
      return
    }

    saving = true

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
    } catch (caught) {
      if (caught instanceof ApiRequestError) {
        fieldErrors = apiFieldErrors(caught)
        error = Object.keys(fieldErrors).length > 0 ? null : caught.message
      } else {
        error = isEditing ? 'We could not update that plan.' : 'We could not create that plan.'
      }
    } finally {
      saving = false
    }
  }

  function apiFieldErrors(caught: ApiRequestError): Partial<Record<FieldName, string>> {
    const fieldNames: Record<string, FieldName> = {
      name: 'name',
      intention: 'intention',
      starts_on: 'startsOn',
      ends_on: 'endsOn',
    }
    const problems: Partial<Record<FieldName, string>> = {}

    for (const detail of caught.details) {
      const field = detail.field ? fieldNames[detail.field] : undefined

      if (field && !problems[field]) {
        problems[field] = detail.message
      }
    }

    return problems
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
</script>

<FormDialog
  open={$newPlanDialogOpen}
  title={isEditing ? 'Edit plan' : 'Define a plan'}
  submitLabel={isEditing ? 'Save changes' : 'Create plan'}
  busyLabel={isEditing ? 'Saving' : 'Creating'}
  busy={saving}
  {error}
  class="plan-dialog"
  onClose={closeNewPlanDialog}
  onSubmit={handleSubmit}
>
  <Field label="Plan name" error={fieldErrors.name}>
    <TextInput bind:value={name} disabled={saving} placeholder="Summer strength block" />
  </Field>

  <Field label="Intention" error={fieldErrors.intention}>
    <TextInput
      bind:value={intention}
      disabled={saving}
      placeholder="What should this plan help with?"
    />
  </Field>

  <div class="timeline-grid">
    <Field label="Starts" error={fieldErrors.startsOn}>
      <DateInput bind:value={startsOn} disabled={saving} />
    </Field>

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
      <Field label="For" error={fieldErrors.endsOn}>
        <NumberInput
          value={durationValue}
          disabled={saving}
          min="1"
          oninput={(event) => handleDurationInput(event.currentTarget.value)}
        />
      </Field>
      <Field label="Unit">
        <Select bind:value={durationUnit} disabled={saving}>
          <option value="days">days</option>
          <option value="weeks">weeks</option>
          <option value="months">months</option>
        </Select>
      </Field>
    </div>
  {:else}
    <Field label="Ends" error={fieldErrors.endsOn}>
      <DateInput bind:value={endsOn} disabled={saving} />
    </Field>
  {/if}
</FormDialog>
