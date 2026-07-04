<script lang="ts">
  import type { EventType, Item } from '../../api/types'
  import { planDetail, selectedDate, submitEventLog } from '../../app/dashboardState'
  import { closeLogDialog, logDialogOpen } from '../../app/uiState'
  import DateInput from '../../components/ui/DateInput.svelte'
  import Field from '../../components/ui/Field.svelte'
  import FormDialog from '../../components/ui/FormDialog.svelte'
  import Select from '../../components/ui/Select.svelte'
  import TextInput from '../../components/ui/TextInput.svelte'

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
  let seeded = $state(false)

  let eventTypes = $derived($planDetail?.eventTypes ?? [])
  let eventType = $derived(eventTypes.find((candidate) => candidate.id === eventTypeId) ?? null)
  let schemaFields = $derived(schemaFieldsFor(eventType))
  let linkRoles = $derived(linkRolesFor(eventType))

  $effect(() => {
    if ($logDialogOpen && !seeded) {
      eventTypeId = eventTypes[0]?.id ?? ''
      date = $selectedDate
      quantity = ''
      unit = ''
      note = ''
      saving = false
      error = null
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

  async function handleSubmit() {
    if (!eventType) {
      error = 'Choose an event type.'
      return
    }

    const missingRole = linkRoles.find((role) => role.required && !roleSelections[role.role])

    if (missingRole) {
      error = `Choose an item for ${fieldLabel(missingRole.role)}.`
      return
    }

    const missingField = schemaFields.find(
      (field) => field.required && !(fieldValues[field.name] ?? '').trim(),
    )

    if (missingField) {
      error = `Add a value for ${fieldLabel(missingField.name)}.`
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

    try {
      await submitEventLog(
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
      closeLogDialog()
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

    {#each linkRoles as role (role.role)}
      <Field label={fieldLabel(role.role)} hint={role.required ? '' : 'Optional'}>
        <Select bind:value={roleSelections[role.role]} disabled={saving}>
          <option value="">{role.required ? 'Choose…' : 'None'}</option>
          {#each itemsForRole(role) as item (item.id)}
            <option value={item.id}>{item.name}</option>
          {/each}
        </Select>
      </Field>
    {/each}

    <div class="form-grid">
      <Field label="Quantity" hint="Optional">
        <TextInput bind:value={quantity} inputmode="decimal" disabled={saving} />
      </Field>
      <Field label="Unit" hint="Optional">
        <TextInput bind:value={unit} disabled={saving} />
      </Field>
    </div>

    {#if schemaFields.length > 0}
      <div class="form-grid">
        {#each schemaFields as field (field.name)}
          <Field label={fieldLabel(field.name)} hint={field.required ? '' : 'Optional'}>
            <TextInput bind:value={fieldValues[field.name]} disabled={saving} />
          </Field>
        {/each}
      </div>
    {/if}

    <Field label="Note" hint="Optional">
      <TextInput bind:value={note} disabled={saving} />
    </Field>
  {/if}
</FormDialog>
