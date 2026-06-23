<script lang="ts">
  import { Dialog } from 'bits-ui'
  import type { DashboardData, EventType, PlanItem } from '../../api/types'
  import {
    closeSessionSlotDialog,
    sessionSlotDialogState,
    submitSessionSlot,
  } from '../../app/appState'
  import { listField, roleList } from '../../lib/modelDisplay'

  let { data }: { data: DashboardData | null } = $props()

  let eventTypeId = $state('')
  let actualItemKey = $state('')
  let payloadValues = $state<Record<string, string>>({})
  let note = $state('')
  let saving = $state(false)
  let error = $state<string | null>(null)
  let seededFor = $state('')

  let work = $derived($sessionSlotDialogState.work)
  let slotResult = $derived($sessionSlotDialogState.slotResult)
  let eventTypes = $derived(data?.planDetail?.eventTypes ?? [])
  let items = $derived(data?.planDetail?.items ?? [])
  let selectedEventType = $derived(eventTypes.find((eventType) => eventType.id === eventTypeId) ?? null)
  let selectedRole = $derived(roleForEvent(selectedEventType, actualItem(items, actualItemKey)))
  let requiredPayloadFields = $derived(listField(selectedEventType?.payloadSchema, 'required'))
  let availableItems = $derived(itemsForRole(selectedEventType, items))

  $effect(() => {
    const seedKey = $sessionSlotDialogState.open ? `${slotResult?.id ?? ''}:${eventTypes.length}` : ''

    if ($sessionSlotDialogState.open && slotResult && seedKey !== seededFor) {
      const item = actualItem(items, slotResult.actualItemKey ?? slotResult.recommendedItemKey ?? '')
      const eventType = defaultEventType(eventTypes, item)

      seededFor = seedKey
      eventTypeId = eventType?.id ?? eventTypes[0]?.id ?? ''
      actualItemKey = item?.key ?? slotResult.actualItemKey ?? slotResult.recommendedItemKey ?? ''
      payloadValues = defaultPayloadValues(requiredPayloadFieldsFor(eventType))
      note = ''
      error = null
    }
  })

  $effect(() => {
    if ($sessionSlotDialogState.open && selectedEventType) {
      payloadValues = mergePayloadDefaults(payloadValues, requiredPayloadFields)
    }
  })

  async function handleSubmit() {
    if (!work || !slotResult || !selectedEventType || !actualItemKey || !selectedRole) {
      error = 'Choose an event and item before logging.'
      return
    }

    const missingField = requiredPayloadFields.find((field) => !payloadValues[field]?.trim())

    if (missingField) {
      error = `Fill in ${missingField}.`
      return
    }

    saving = true
    error = null

    const payload = payloadForSubmit(payloadValues)

    try {
      await submitSessionSlot({
        sessionOccurrenceId: slotResult.sessionOccurrenceId,
        slotKey: slotResult.slotKey ?? '',
        actualItemKey,
        recommendedItemKey: slotResult.recommendedItemKey,
        eventKey: selectedEventType.key,
        role: selectedRole.role,
        summary: summary(selectedEventType, actualItem(items, actualItemKey)),
        quantity: quantityFromPayload(payload),
        unit: unitFromPayload(payload),
        note: note.trim() || null,
        payload,
      })
    } catch {
      error = 'We could not log that slot.'
    } finally {
      saving = false
    }
  }

  function defaultEventType(allEventTypes: EventType[], item: PlanItem | null): EventType | null {
    if (!item) {
      return allEventTypes[0] ?? null
    }

    return (
      allEventTypes.find((eventType) =>
        roleList(eventType.itemLinkRoles).some((role) => role.required && role.itemTypeKey === item.typeKey)
      ) ??
      allEventTypes[0] ??
      null
    )
  }

  function roleForEvent(eventType: EventType | null, item: PlanItem | null) {
    const roles = roleList(eventType?.itemLinkRoles)

    if (!item) {
      return roles.find((role) => role.required) ?? roles[0] ?? null
    }

    return roles.find((role) => role.itemTypeKey === item.typeKey) ?? roles.find((role) => role.required) ?? roles[0] ?? null
  }

  function itemsForRole(eventType: EventType | null, allItems: PlanItem[]): PlanItem[] {
    const role = roleForEvent(eventType, actualItem(allItems, actualItemKey))
    return role?.itemTypeKey ? allItems.filter((item) => item.typeKey === role.itemTypeKey) : allItems
  }

  function actualItem(allItems: PlanItem[], key: string): PlanItem | null {
    return allItems.find((item) => item.key === key) ?? null
  }

  function requiredPayloadFieldsFor(eventType: EventType | null): string[] {
    return listField(eventType?.payloadSchema, 'required')
  }

  function defaultPayloadValues(fields: string[]): Record<string, string> {
    return Object.fromEntries(
      fields.map((field) => [field, field === 'sets' ? '3' : field === 'reps' ? '10' : ''])
    )
  }

  function mergePayloadDefaults(current: Record<string, string>, fields: string[]): Record<string, string> {
    return { ...defaultPayloadValues(fields), ...current }
  }

  function payloadForSubmit(values: Record<string, string>): Record<string, unknown> {
    return Object.fromEntries(
      Object.entries(values)
        .map(([key, value]) => [key, value.trim()])
        .filter(([, value]) => value)
    )
  }

  function quantityFromPayload(payload: Record<string, unknown>): string | null {
    const value = payload.duration_minutes ?? payload.sets ?? null
    return value == null ? null : String(value)
  }

  function unitFromPayload(payload: Record<string, unknown>): string | null {
    if (payload.duration_minutes) return 'minutes'
    if (payload.sets) return 'sets'
    return null
  }

  function summary(eventType: EventType, item: PlanItem | null): string {
    return item ? `${item.name} logged` : `${eventType.name} logged`
  }
</script>

<Dialog.Root open={$sessionSlotDialogState.open} onOpenChange={(open) => !open && closeSessionSlotDialog()}>
  <Dialog.Portal>
    <Dialog.Overlay class="dialog-overlay" />
    <Dialog.Content class="dialog-content">
      <div class="dialog-header">
        <div>
          <Dialog.Title>Log session slot</Dialog.Title>
          <Dialog.Description>
            {slotResult?.slotName ?? 'Session slot'} · {slotResult?.actualItemName ?? slotResult?.recommendedItemName ?? 'Item'}
          </Dialog.Description>
        </div>
        <Dialog.Close class="icon-button" aria-label="Close">×</Dialog.Close>
      </div>

      <form class="dialog-form" onsubmit={(event) => { event.preventDefault(); handleSubmit() }}>
        <label>
          Event type
          <select bind:value={eventTypeId} disabled={saving}>
            {#each eventTypes as eventType (eventType.id)}
              <option value={eventType.id}>{eventType.name}</option>
            {/each}
          </select>
        </label>

        <label>
          Actual item
          <select bind:value={actualItemKey} disabled={saving}>
            {#each availableItems as item (item.id)}
              <option value={item.key}>{item.name}</option>
            {/each}
          </select>
        </label>

        {#if requiredPayloadFields.length}
          <div class="form-fieldset">
            <p>Required details</p>
            <div class="form-grid">
              {#each requiredPayloadFields as field (field)}
                <label>
                  {field}
                  <input bind:value={payloadValues[field]} disabled={saving} placeholder={field} />
                </label>
              {/each}
            </div>
          </div>
        {/if}

        <label>
          Note
          <textarea bind:value={note} disabled={saving} rows="3" placeholder="Optional detail"></textarea>
        </label>

        {#if error}
          <p class="error inline-error">{error}</p>
        {/if}

        <div class="dialog-actions">
          <button class="secondary-button" type="button" disabled={saving} onclick={closeSessionSlotDialog}>Cancel</button>
          <button class="primary-button" type="submit" disabled={saving || !eventTypeId || !actualItemKey}>
            {saving ? 'Logging' : 'Log slot'}
          </button>
        </div>
      </form>
    </Dialog.Content>
  </Dialog.Portal>
</Dialog.Root>
