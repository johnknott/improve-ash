<script lang="ts">
  import { Dialog } from 'bits-ui'
  import type { DashboardData } from '../../api/types'
  import { closeLogDialog, logDialogState, submitLog } from '../../app/appState'

  let { data }: { data: DashboardData | null } = $props()

  let eventTypeId = $state('')
  let summary = $state('')
  let quantity = $state('')
  let unit = $state('')
  let note = $state('')
  let itemSelections = $state<Record<string, string>>({})
  let payloadValues = $state<Record<string, string>>({})
  let seededEventTypeId = $state('')
  let saving = $state(false)
  let error = $state<string | null>(null)

  let work = $derived($logDialogState.work)
  let planId = $derived(work?.planId ?? data?.currentPlan?.id ?? '')
  let eventTypes = $derived(data?.planDetail?.eventTypes ?? [])
  let items = $derived(data?.planDetail?.items ?? [])
  let selectedEventType = $derived(eventTypes.find((eventType) => eventType.id === eventTypeId) ?? null)
  let requiredRoles = $derived(requiredItemRoles(selectedEventType?.itemLinkRoles))
  let requiredPayloadFields = $derived(
    requiredPayloadPaths(selectedEventType?.payloadSchema).filter((path) => path !== 'amount' && path !== 'unit')
  )

  $effect(() => {
    if ($logDialogState.open) {
      eventTypeId = work?.eventTypeId ?? eventTypes[0]?.id ?? ''
      summary = work?.title ?? ''
      quantity = work?.target.quantity == null ? '' : String(work.target.quantity)
      unit = work?.target.unit ?? ''
      note = ''
      itemSelections = {}
      payloadValues = {}
      seededEventTypeId = ''
      error = null
    }
  })

  $effect(() => {
    if ($logDialogState.open && eventTypeId && seededEventTypeId !== eventTypeId) {
      seededEventTypeId = eventTypeId
      itemSelections = defaultsForRoles(requiredRoles, items)
      payloadValues = defaultsForPayload(requiredPayloadFields)
    }
  })

  async function handleSubmit() {
    if (!planId || !eventTypeId) {
      error = 'Choose a plan and event type before logging.'
      return
    }

    const missingRole = requiredRoles.find((role) => !itemSelections[role.role])

    if (missingRole) {
      error = `Choose an item for ${missingRole.role}.`
      return
    }

    const missingPayloadField = requiredPayloadFields.find((field) => !payloadValues[field]?.trim())

    if (missingPayloadField) {
      error = `Fill in ${missingPayloadField}.`
      return
    }

    saving = true
    error = null

    try {
      await submitLog({
        planId,
        eventTypeId,
        directGoalId: work?.directGoalId ?? null,
        summary: summary.trim() || work?.title || 'Logged event',
        quantity: quantity.trim() || null,
        unit: unit.trim() || null,
        note: note.trim() || null,
        payload: payloadForSubmit(payloadValues),
        itemLinks: requiredRoles.map((role) => ({
          role: role.role,
          itemId: itemSelections[role.role],
        })),
      })
    } catch {
      error = 'We could not log that event.'
    } finally {
      saving = false
    }
  }

  type ItemRole = {
    role: string
    itemTypeKey: string | null
    required: boolean
  }

  function requiredItemRoles(itemLinkRoles: Record<string, unknown> | undefined): ItemRole[] {
    const roles = Array.isArray(itemLinkRoles?.roles) ? itemLinkRoles.roles : []

    return roles
      .filter((role): role is Record<string, unknown> => isRecord(role))
      .map((role) => ({
        role: String(role.role ?? ''),
        itemTypeKey: typeof role.item_type_key === 'string' ? role.item_type_key : null,
        required: role.required === true,
      }))
      .filter((role) => role.required && role.role)
  }

  function requiredPayloadPaths(payloadSchema: Record<string, unknown> | undefined): string[] {
    return Array.isArray(payloadSchema?.required)
      ? payloadSchema.required.filter((path): path is string => typeof path === 'string')
      : []
  }

  function defaultsForRoles(roles: ItemRole[], planItems: typeof items): Record<string, string> {
    return Object.fromEntries(
      roles.map((role) => [role.role, itemsForRole(role, planItems)[0]?.id ?? ''])
    )
  }

  function defaultsForPayload(paths: string[]): Record<string, string> {
    return Object.fromEntries(paths.map((path) => [path, '']))
  }

  function itemsForRole(role: ItemRole, planItems = items) {
    return role.itemTypeKey ? planItems.filter((item) => item.typeKey === role.itemTypeKey) : planItems
  }

  function payloadForSubmit(values: Record<string, string>): Record<string, unknown> {
    return Object.fromEntries(
      Object.entries(values)
        .map(([key, value]) => [key, value.trim()])
        .filter(([, value]) => value)
    )
  }

  function isRecord(value: unknown): value is Record<string, unknown> {
    return typeof value === 'object' && value !== null
  }
</script>

<Dialog.Root open={$logDialogState.open} onOpenChange={(open) => !open && closeLogDialog()}>
  <Dialog.Portal>
    <Dialog.Overlay class="dialog-overlay" />
    <Dialog.Content class="dialog-content">
      <div class="dialog-header">
        <div>
          <Dialog.Title>Log event</Dialog.Title>
          <Dialog.Description>
            {work ? `Recording work for ${work.planName}.` : 'Record something that happened in the current plan.'}
          </Dialog.Description>
        </div>
        <Dialog.Close class="icon-button" aria-label="Close">×</Dialog.Close>
      </div>

      <form class="dialog-form" onsubmit={(event) => { event.preventDefault(); handleSubmit() }}>
        <label>
          Event type
          <select bind:value={eventTypeId} disabled={!!work?.eventTypeId || saving}>
            {#each eventTypes as eventType}
              <option value={eventType.id}>{eventType.name}</option>
            {/each}
          </select>
        </label>

        <label>
          Summary
          <input bind:value={summary} disabled={saving} placeholder="What happened?" />
        </label>

        {#if requiredRoles.length}
          <div class="form-fieldset">
            <p>Involved items</p>
            {#each requiredRoles as role (role.role)}
              <label>
                {role.role}
                <select bind:value={itemSelections[role.role]} disabled={saving}>
                  {#each itemsForRole(role) as item (item.id)}
                    <option value={item.id}>{item.name}</option>
                  {/each}
                </select>
              </label>
            {/each}
          </div>
        {/if}

        <div class="form-grid">
          <label>
            Quantity
            <input bind:value={quantity} disabled={saving} inputmode="decimal" placeholder="Optional" />
          </label>
          <label>
            Unit
            <input bind:value={unit} disabled={saving} placeholder="reps, ml, minutes" />
          </label>
        </div>

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
          <button class="secondary-button" type="button" disabled={saving} onclick={closeLogDialog}>Cancel</button>
          <button class="primary-button" type="submit" disabled={saving || !eventTypeId}>
            {saving ? 'Logging' : 'Log event'}
          </button>
        </div>
      </form>
    </Dialog.Content>
  </Dialog.Portal>
</Dialog.Root>
