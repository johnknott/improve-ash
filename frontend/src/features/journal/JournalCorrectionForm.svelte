<script lang="ts">
  import { History } from '@lucide/svelte'
  import type { EventType, JournalEventDetail, JsonMap } from '../../api/types'
  import { ApiRequestError } from '../../api/improveClient'
  import { submitEventCorrection } from '../../app/dashboardState'
  import Button from '../../components/ui/Button.svelte'
  import Field from '../../components/ui/Field.svelte'
  import TextInput from '../../components/ui/TextInput.svelte'
  import { focusDialogTarget } from '../../lib/dialogFocus'

  type PayloadField = {
    name: string
    required: boolean
  }

  let {
    event,
    eventType,
    onCancel,
    onSaved,
    onBusyChange,
  }: {
    event: JournalEventDetail
    eventType: EventType | null
    onCancel: () => void
    onSaved: () => void
    onBusyChange: (busy: boolean) => void
  } = $props()

  const firstClassFields = new Set(['amount', 'quantity', 'unit', 'note'])
  let requiredPayloadFields = $derived(stringList(eventType?.payloadSchema['required']))
  let payloadFields = $derived(schemaFieldsFor(eventType, event.payload))

  let summary = $state('')
  let effectiveAt = $state('')
  let quantity = $state('')
  let unit = $state('')
  let note = $state('')
  let correctionNote = $state('')
  let fieldValues = $state<Record<string, string>>({})
  let saving = $state(false)
  let error = $state<string | null>(null)
  let invalidField = $state<string | null>(null)
  let validationMessage = $state<string | null>(null)
  let seededEventId = $state<string | null>(null)

  $effect(() => {
    if (seededEventId !== event.id) {
      summary = event.summary
      effectiveAt = toLocalDateTime(event.effectiveAt)
      quantity = event.quantity ?? ''
      unit = event.unit ?? ''
      note = event.note ?? ''
      correctionNote = ''
      fieldValues = seedFieldValues(payloadFields, event.payload)
      seededEventId = event.id
    }
  })

  let quantityRequired = $derived(
    requiredPayloadFields.includes('amount') || requiredPayloadFields.includes('quantity'),
  )
  let unitRequired = $derived(requiredPayloadFields.includes('unit'))
  let noteRequired = $derived(requiredPayloadFields.includes('note'))
  let showQuantity = $derived(
    event.quantity !== null ||
      event.unit !== null ||
      Object.hasOwn(event.payload, 'amount') ||
      Object.hasOwn(event.payload, 'quantity') ||
      Object.hasOwn(event.payload, 'unit') ||
      quantityRequired ||
      unitRequired,
  )
  let unchanged = $derived(formIsUnchanged())

  function schemaFieldsFor(type: EventType | null, payload: JsonMap): PayloadField[] {
    if (!type) return []

    const required = stringList(type.payloadSchema['required'])
    const optional = stringList(type.payloadSchema['optional'])
    const names = [...new Set([...required, ...optional])]

    return names
      .filter((name) => !firstClassFields.has(name))
      .filter((name) => editablePayloadValue(payload[name]))
      .map((name) => ({ name, required: required.includes(name) }))
  }

  function editablePayloadValue(value: unknown): boolean {
    return value === undefined || value === null || ['string', 'number', 'boolean'].includes(typeof value)
  }

  function seedFieldValues(fields: PayloadField[], payload: JsonMap): Record<string, string> {
    return Object.fromEntries(fields.map((field) => [field.name, displayValue(payload[field.name])]))
  }

  function displayValue(value: unknown): string {
    return value == null ? '' : String(value)
  }

  function stringList(value: unknown): string[] {
    return Array.isArray(value) ? value.filter((entry) => typeof entry === 'string') : []
  }

  function fieldLabel(name: string): string {
    return name.replaceAll('_', ' ').replace(/^./, (first) => first.toUpperCase())
  }

  function fieldError(field: string): string | null {
    return invalidField === field ? validationMessage : null
  }

  function showValidationError(field: string, message: string) {
    invalidField = field
    validationMessage = message
    error = null
    focusDialogTarget(
      document.querySelector<HTMLElement>('[role="dialog"]'),
      '[data-correction-invalid="true"]',
    )
  }

  function buildPayload(): JsonMap {
    const payload: JsonMap = { ...event.payload }

    for (const field of payloadFields) {
      const value = fieldValues[field.name]?.trim() ?? ''

      if (!value && !field.required) {
        delete payload[field.name]
      } else {
        payload[field.name] = payloadValue(value, event.payload[field.name])
      }
    }

    return payload
  }

  function payloadValue(value: string, original: unknown): unknown {
    if (typeof original === 'number') {
      const number = Number(value)
      return Number.isFinite(number) ? number : value
    }

    if (typeof original === 'boolean') {
      if (value.toLowerCase() === 'true') return true
      if (value.toLowerCase() === 'false') return false
    }

    return value
  }

  function formIsUnchanged(): boolean {
    return (
      summary.trim() === event.summary &&
      sameOptionalText(quantity, event.quantity) &&
      sameOptionalText(unit, event.unit) &&
      sameOptionalText(note, event.note) &&
      effectiveAt === toLocalDateTime(event.effectiveAt) &&
      JSON.stringify(buildPayload()) === JSON.stringify(event.payload)
    )
  }

  function sameOptionalText(value: string, original: string | null): boolean {
    return (value.trim() || null) === original
  }

  async function handleSubmit() {
    invalidField = null
    validationMessage = null
    error = null

    if (!summary.trim()) {
      showValidationError('summary', 'Describe what happened.')
      return
    }

    const correctedTime = parseLocalDateTime(effectiveAt)

    if (!correctedTime) {
      showValidationError('effective_at', 'Enter a valid date and time.')
      return
    }

    if (quantityRequired && !quantity.trim()) {
      showValidationError('quantity', 'Add an amount.')
      return
    }

    if (unitRequired && !unit.trim()) {
      showValidationError('unit', 'Add a unit.')
      return
    }

    if (noteRequired && !note.trim()) {
      showValidationError('note', 'Add a note.')
      return
    }

    const missingField = payloadFields.find(
      (field) => field.required && !(fieldValues[field.name] ?? '').trim(),
    )

    if (missingField) {
      showValidationError(missingField.name, `Add a value for ${fieldLabel(missingField.name)}.`)
      return
    }

    if (unchanged) {
      error = 'Change at least one recorded value before saving.'
      return
    }

    saving = true
    onBusyChange(true)

    try {
      const saved = await submitEventCorrection({
        planId: event.planId,
        originalEventId: event.id,
        effectiveAt:
          effectiveAt === toLocalDateTime(event.effectiveAt)
            ? event.effectiveAt
            : correctedTime.toISOString(),
        summary: summary.trim(),
        quantity: quantity.trim() || null,
        unit: unit.trim() || null,
        note: note.trim() || null,
        payload: buildPayload(),
        correctionNote: correctionNote.trim() || null,
      })

      if (saved) onSaved()
    } catch (caught) {
      error = caught instanceof Error ? caught.message : 'We could not save that correction.'

      if (caught instanceof ApiRequestError) {
        const detail = caught.details.find((candidate) => candidate.field)

        if (detail?.field) {
          invalidField = detail.field
          validationMessage = detail.message
          focusDialogTarget(
            document.querySelector<HTMLElement>('[role="dialog"]'),
            '[data-correction-invalid="true"]',
          )
        }
      }
    } finally {
      saving = false
      onBusyChange(false)
    }
  }

  function toLocalDateTime(iso: string): string {
    const date = new Date(iso)
    const local = new Date(date.getTime() - date.getTimezoneOffset() * 60_000)
    return local.toISOString().slice(0, 19)
  }

  function parseLocalDateTime(value: string): Date | null {
    if (!value) return null

    const date = new Date(value)
    return Number.isNaN(date.getTime()) ? null : date
  }
</script>

<div class="journal-correction-note">
  <History size={18} aria-hidden="true" />
  <p><strong>The original stays in your history.</strong> Saving creates a replacement entry.</p>
</div>

{#if event.itemLinks.length > 0}
  <p class="journal-correction-context">
    Correcting {event.itemLinks.map((link) => link.itemName ?? link.itemKey ?? 'linked item').join(', ')}.
    The linked items will not change.
  </p>
{/if}

<form
  class="dialog-form journal-correction-form"
  aria-busy={saving}
  onsubmit={(submitEvent) => {
    submitEvent.preventDefault()
    void handleSubmit()
  }}
>
  <Field label="What happened" error={fieldError('summary')}>
    <TextInput
      bind:value={summary}
      data-correction-first-focus
      data-correction-invalid={invalidField === 'summary' ? true : undefined}
      aria-invalid={invalidField === 'summary' ? true : undefined}
      disabled={saving}
    />
  </Field>

  <Field label="When it happened" error={fieldError('effective_at')}>
    <input
      type="datetime-local"
      step="1"
      bind:value={effectiveAt}
      data-correction-invalid={invalidField === 'effective_at' ? true : undefined}
      aria-invalid={invalidField === 'effective_at' ? true : undefined}
      disabled={saving}
    />
  </Field>

  {#if showQuantity}
    <div class="form-grid">
      <Field label="Amount" optional={!quantityRequired} error={fieldError('quantity')}>
        <TextInput
          bind:value={quantity}
          inputmode="decimal"
          data-correction-invalid={invalidField === 'quantity' ? true : undefined}
          aria-invalid={invalidField === 'quantity' ? true : undefined}
          disabled={saving}
        />
      </Field>
      <Field label="Unit" optional={!unitRequired} error={fieldError('unit')}>
        <TextInput
          bind:value={unit}
          data-correction-invalid={invalidField === 'unit' ? true : undefined}
          aria-invalid={invalidField === 'unit' ? true : undefined}
          disabled={saving}
        />
      </Field>
    </div>
  {/if}

  {#if payloadFields.length > 0}
    <div class="form-grid">
      {#each payloadFields as field (field.name)}
        <Field
          label={fieldLabel(field.name)}
          optional={!field.required}
          error={fieldError(field.name)}
        >
          <TextInput
            bind:value={fieldValues[field.name]}
            inputmode={typeof event.payload[field.name] === 'number' ? 'decimal' : undefined}
            data-correction-invalid={invalidField === field.name ? true : undefined}
            aria-invalid={invalidField === field.name ? true : undefined}
            disabled={saving}
          />
        </Field>
      {/each}
    </div>
  {/if}

  <Field label="Note" optional={!noteRequired} error={fieldError('note')}>
    <TextInput
      bind:value={note}
      data-correction-invalid={invalidField === 'note' ? true : undefined}
      aria-invalid={invalidField === 'note' ? true : undefined}
      disabled={saving}
    />
  </Field>

  <Field
    label="Reason for the correction"
    hint="Optional. This is kept with the original entry."
    optional
  >
    <TextInput bind:value={correctionNote} disabled={saving} />
  </Field>

  {#if unchanged}
    <p class="hint">Change at least one recorded value to save a correction.</p>
  {/if}

  {#if error}
    <p class="error inline-error" role="alert">{error}</p>
  {/if}

  <div class="dialog-actions">
    <Button variant="secondary" disabled={saving} onclick={onCancel}>Back to details</Button>
    <Button type="submit" disabled={saving || unchanged}>
      {saving ? 'Saving correction…' : 'Save correction'}
    </Button>
  </div>
</form>
