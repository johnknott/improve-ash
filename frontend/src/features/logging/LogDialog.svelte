<script lang="ts">
  import type { EventType, Item } from '../../api/types'
  import { planDetail, selectedDate, submitEventLog } from '../../app/dashboardState'
  import { closeLogDialog, logDialogOpen } from '../../app/uiState'
  import DateInput from '../../components/ui/DateInput.svelte'
  import Field from '../../components/ui/Field.svelte'
  import FormDialog from '../../components/ui/FormDialog.svelte'
  import Select from '../../components/ui/Select.svelte'
  import TextInput from '../../components/ui/TextInput.svelte'
  import { focusDialogTarget } from '../../lib/dialogFocus'

  type LinkRole = { role: string; itemTypeKey: string | null; required: boolean }

  // quantity/unit/note are first-class inputs; schema fields render after.
  // 'amount' is the payload's quantity field — the backend fills it from the
  // quantity input, so it is first-class too rather than a raw schema field.
  const firstClassFields = new Set(['quantity', 'amount', 'unit', 'note'])

  let eventTypeId = $state('')
  let quantity = $state('')
  let unit = $state('')
  let note = $state('')
  let date = $state('')
  let fieldValues = $state<Record<string, string>>({})
  let roleSelections = $state<Record<string, string>>({})
  let saving = $state(false)
  let error = $state<string | null>(null)
  let invalidField = $state<string | null>(null)
  let seeded = $state(false)

  let showMore = $state(false)

  let eventTypes = $derived($planDetail?.eventTypes ?? [])
  let eventType = $derived(eventTypes.find((candidate) => candidate.id === eventTypeId) ?? null)
  let schemaFields = $derived(schemaFieldsFor(eventType))
  let linkRoles = $derived(linkRolesFor(eventType))

  // Progressive disclosure: required inputs up front, everything optional
  // behind "More details".
  let requiredSchemaFields = $derived(schemaFields.filter((field) => field.required))
  let optionalSchemaFields = $derived(schemaFields.filter((field) => !field.required))
  let requiredRoles = $derived(linkRoles.filter((role) => role.required))
  let optionalRoles = $derived(linkRoles.filter((role) => !role.required))
  let requiredPayloadFields = $derived(
    eventType ? stringList(eventType.payloadSchema['required']) : [],
  )
  let quantityRequired = $derived.by(() => {
    return requiredPayloadFields.includes('amount') || requiredPayloadFields.includes('quantity')
  })
  let unitRequired = $derived(requiredPayloadFields.includes('unit'))
  let noteRequired = $derived(requiredPayloadFields.includes('note'))
  let quantityFieldsRequired = $derived(quantityRequired || unitRequired)
  let hasMoreDetails = $derived(
    optionalSchemaFields.length > 0 ||
      optionalRoles.length > 0 ||
      !quantityFieldsRequired ||
      !noteRequired,
  )

  $effect(() => {
    if ($logDialogOpen && !seeded) {
      eventTypeId = eventTypes[0]?.id ?? ''
      date = $selectedDate
      quantity = ''
      unit = ''
      note = ''
      showMore = false
      saving = false
      error = null
      invalidField = null
      seeded = true
    }

    if (!$logDialogOpen) {
      seeded = false
    }
  })

  // Changing event type resets the dynamic parts of the form. Every key is
  // seeded with '' — binding an undefined property into an input with a
  // $bindable fallback is a Svelte runtime error.
  $effect(() => {
    fieldValues = Object.fromEntries(schemaFields.map((field) => [field.name, '']))
    roleSelections = Object.fromEntries(linkRoles.map((role) => [role.role, '']))
    invalidField = null
    error = null
  })

  function schemaFieldsFor(type: EventType | null): { name: string; required: boolean }[] {
    if (!type) {
      return []
    }

    const required = stringList(type.payloadSchema['required'])
    const optional = stringList(type.payloadSchema['optional'])

    return [
      ...required.filter((name) => !firstClassFields.has(name)).map((name) => ({
        name,
        required: true,
      })),
      ...optional.filter((name) => !firstClassFields.has(name)).map((name) => ({
        name,
        required: false,
      })),
    ]
  }

  function linkRolesFor(type: EventType | null): LinkRole[] {
    if (!type) {
      return []
    }

    const roles = type.itemLinkRoles['roles']

    if (!Array.isArray(roles)) {
      return []
    }

    return roles.flatMap((entry) => {
      if (typeof entry !== 'object' || entry === null || !('role' in entry)) {
        return []
      }

      const role = entry as Record<string, unknown>

      return [
        {
          role: String(role.role),
          itemTypeKey: typeof role.item_type_key === 'string' ? role.item_type_key : null,
          required: role.required === true,
        },
      ]
    })
  }

  function itemsForRole(role: LinkRole): Item[] {
    const items = $planDetail?.items ?? []

    return items.filter(
      (item) => !item.archived && (!role.itemTypeKey || item.typeKey === role.itemTypeKey),
    )
  }

  function stringList(value: unknown): string[] {
    return Array.isArray(value) ? value.filter((entry) => typeof entry === 'string') : []
  }

  function fieldLabel(name: string): string {
    return name.replaceAll('_', ' ').replace(/^./, (first) => first.toUpperCase())
  }

  function revealMoreDetails(trigger: HTMLButtonElement) {
    const form = trigger.closest('form')
    showMore = true
    focusDialogTarget(form, '[data-log-more-focus]')
  }

  function showValidationError(field: string, message: string) {
    invalidField = field
    error = message
    focusDialogTarget(
      document.querySelector<HTMLElement>('[role="dialog"]'),
      '[data-log-invalid="true"]',
    )
  }

  async function handleSubmit() {
    invalidField = null
    error = null

    if (!eventType) {
      error = 'Choose an event type.'
      return
    }

    const missingRole = linkRoles.find((role) => role.required && !roleSelections[role.role])

    if (missingRole) {
      showValidationError(
        `role:${missingRole.role}`,
        `Choose an item for ${fieldLabel(missingRole.role)}.`,
      )
      return
    }

    if (quantityRequired && !quantity.trim()) {
      showValidationError('quantity', 'Add a quantity.')
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

    const missingField = schemaFields.find(
      (field) => field.required && !(fieldValues[field.name] ?? '').trim(),
    )

    if (missingField) {
      showValidationError(
        `schema:${missingField.name}`,
        `Add a value for ${fieldLabel(missingField.name)}.`,
      )
      return
    }

    saving = true
    error = null

    const payload: Record<string, string> = {}

    for (const field of schemaFields) {
      const value = (fieldValues[field.name] ?? '').trim()

      if (value) {
        payload[field.name] = value
      }
    }

    if (requiredPayloadFields.includes('quantity') && quantity.trim()) {
      payload.quantity = quantity.trim()
    }

    try {
      const applied = await submitEventLog(
        {
          eventTypeId: eventType.id,
          summary: eventType.name,
          effectiveAt: date ? `${date}T12:00:00Z` : null,
          quantity: quantity.trim() || null,
          unit: unit.trim() || null,
          note: note.trim() || null,
          payload,
          itemLinks: linkRoles
            .filter((role) => roleSelections[role.role])
            .map((role) => ({ role: role.role, item_id: roleSelections[role.role] })),
        },
        'Logged.',
      )

      if (applied) {
        closeLogDialog()
      }
    } catch (caught) {
      error = caught instanceof Error ? caught.message : 'We could not log that event.'
    } finally {
      saving = false
    }
  }
</script>

<FormDialog
  open={$logDialogOpen}
  title="Log an event"
  submitLabel="Log it"
  busyLabel="Logging"
  busy={saving}
  submitDisabled={eventTypes.length === 0}
  {error}
  onClose={closeLogDialog}
  onSubmit={handleSubmit}
>
  {#if eventTypes.length === 0}
    <p class="hint">This plan has no event types yet — add one under Event Types first.</p>
  {:else}
    <div class="form-grid">
      <Field label="Event type">
        <Select bind:value={eventTypeId} disabled={saving}>
          {#each eventTypes as candidate (candidate.id)}
            <option value={candidate.id}>{candidate.name}</option>
          {/each}
        </Select>
      </Field>
      <Field label="Date">
        <DateInput bind:value={date} disabled={saving} />
      </Field>
    </div>

    {#each requiredRoles as role (role.role)}
      <Field label={fieldLabel(role.role)}>
        <Select
          bind:value={roleSelections[role.role]}
          aria-invalid={invalidField === `role:${role.role}` ? true : undefined}
          data-log-invalid={invalidField === `role:${role.role}` ? true : undefined}
          disabled={saving}
        >
          <option value="">Choose…</option>
          {#each itemsForRole(role) as item (item.id)}
            <option value={item.id}>{item.name}</option>
          {/each}
        </Select>
      </Field>
    {/each}

    {#if quantityFieldsRequired}
      <div class="form-grid">
        <Field label="Quantity" optional={!quantityRequired}>
          <TextInput
            bind:value={quantity}
            aria-invalid={invalidField === 'quantity' ? true : undefined}
            data-log-invalid={invalidField === 'quantity' ? true : undefined}
            inputmode="decimal"
            disabled={saving}
          />
        </Field>
        <Field label="Unit" optional={!unitRequired}>
          <TextInput
            bind:value={unit}
            aria-invalid={invalidField === 'unit' ? true : undefined}
            data-log-invalid={invalidField === 'unit' ? true : undefined}
            disabled={saving}
          />
        </Field>
      </div>
    {/if}

    {#if noteRequired}
      <Field label="Note">
        <TextInput
          bind:value={note}
          aria-invalid={invalidField === 'note' ? true : undefined}
          data-log-invalid={invalidField === 'note' ? true : undefined}
          disabled={saving}
        />
      </Field>
    {/if}

    {#if requiredSchemaFields.length > 0}
      <div class="form-grid">
        {#each requiredSchemaFields as field (field.name)}
          <Field label={fieldLabel(field.name)}>
            <TextInput
              bind:value={fieldValues[field.name]}
              aria-invalid={invalidField === `schema:${field.name}` ? true : undefined}
              data-log-invalid={invalidField === `schema:${field.name}` ? true : undefined}
              disabled={saving}
            />
          </Field>
        {/each}
      </div>
    {/if}

    {#if hasMoreDetails && !showMore}
      <button
        type="button"
        class="text-button add-note-toggle"
        disabled={saving}
        onclick={(event) => revealMoreDetails(event.currentTarget)}
      >
        More details…
      </button>
    {/if}

    {#if showMore || !hasMoreDetails}
      {#each optionalRoles as role (role.role)}
        <Field label={fieldLabel(role.role)} optional>
          <Select bind:value={roleSelections[role.role]} data-log-more-focus disabled={saving}>
            <option value="">None</option>
            {#each itemsForRole(role) as item (item.id)}
              <option value={item.id}>{item.name}</option>
            {/each}
          </Select>
        </Field>
      {/each}

      {#if !quantityFieldsRequired}
        <div class="form-grid">
          <Field label="Quantity" optional>
            <TextInput
              bind:value={quantity}
              data-log-more-focus
              inputmode="decimal"
              disabled={saving}
            />
          </Field>
          <Field label="Unit" optional>
            <TextInput bind:value={unit} data-log-more-focus disabled={saving} />
          </Field>
        </div>
      {/if}

      {#if optionalSchemaFields.length > 0}
        <div class="form-grid">
          {#each optionalSchemaFields as field (field.name)}
            <Field label={fieldLabel(field.name)} optional>
              <TextInput
                bind:value={fieldValues[field.name]}
                data-log-more-focus
                disabled={saving}
              />
            </Field>
          {/each}
        </div>
      {/if}

      {#if !noteRequired}
        <Field label="Note" optional>
          <TextInput bind:value={note} data-log-more-focus disabled={saving} />
        </Field>
      {/if}
    {/if}
  {/if}
</FormDialog>
