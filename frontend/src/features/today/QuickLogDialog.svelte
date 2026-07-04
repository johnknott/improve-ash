<script lang="ts">
  import type { WorkItem } from '../../api/types'
  import { submitTrackLog } from '../../app/dashboardState'
  import Field from '../../components/ui/Field.svelte'
  import FormDialog from '../../components/ui/FormDialog.svelte'
  import TextInput from '../../components/ui/TextInput.svelte'

  let { item, open = $bindable(false) }: { item: WorkItem; open?: boolean } = $props()

  let quantity = $state('')
  let unit = $state('')
  let note = $state('')
  let saving = $state(false)
  let error = $state<string | null>(null)
  let seeded = $state(false)

  $effect(() => {
    if (open && !seeded) {
      const target = item.target as Record<string, unknown>
      quantity = target?.quantity != null ? String(target.quantity) : ''
      unit = typeof target?.unit === 'string' ? target.unit : ''
      note = ''
      error = null
      saving = false
      seeded = true
    }

    if (!open) {
      seeded = false
    }
  })

  async function handleSubmit() {
    if (!item.trackKey) {
      return
    }

    saving = true
    error = null

    try {
      await submitTrackLog(
        {
          trackKey: item.trackKey,
          quantity: quantity.trim() || null,
          unit: unit.trim() || null,
          note: note.trim() || null,
        },
        `Logged ${item.title}.`,
      )
      open = false
    } catch (caught) {
      error = caught instanceof Error ? caught.message : 'We could not log that.'
    } finally {
      saving = false
    }
  }
</script>

<FormDialog
  {open}
  title="Log {item.title}"
  submitLabel="Log it"
  busyLabel="Logging"
  busy={saving}
  {error}
  class="small-dialog"
  onClose={() => (open = false)}
  onSubmit={handleSubmit}
>
  <div class="form-grid">
    <Field label="Quantity">
      <TextInput bind:value={quantity} inputmode="decimal" disabled={saving} />
    </Field>
    <Field label="Unit">
      <TextInput bind:value={unit} disabled={saving} />
    </Field>
  </div>

  <Field label="Note" hint="Optional">
    <TextInput bind:value={note} disabled={saving} />
  </Field>
</FormDialog>
