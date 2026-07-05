<script lang="ts">
  import type { WorkItem } from '../../api/types'
  import {
    planDetail,
    selectedDate,
    submitTrackLog,
    submitTrackSkip,
  } from '../../app/dashboardState'
  import Button from '../../components/ui/Button.svelte'
  import Field from '../../components/ui/Field.svelte'
  import TextInput from '../../components/ui/TextInput.svelte'
  import { formatDate } from '../../lib/dates'

  // The shared "log one track" body: target card with the track's own
  // guidance, a What happened? choice, amount with the target's unit as a
  // read-only chip (units are defined on the track, never typed at log
  // time), note behind a disclosure, and a dynamic submit label. Used by
  // the log dialog and by the check-in wizard steps.
  let {
    item,
    onFinished,
    onCancel = null,
  }: {
    item: WorkItem
    onFinished: () => void
    onCancel?: (() => void) | null
  } = $props()

  function targetOf(work: WorkItem): Record<string, unknown> {
    return (work.target ?? {}) as Record<string, unknown>
  }

  function initialQuantity(work: WorkItem): string {
    const quantity = targetOf(work).quantity
    return quantity != null ? String(quantity) : ''
  }

  let mode = $state<'record' | 'skip'>('record')
  // Seeded once per mount on purpose — the dialog content remounts on every
  // open, and edits must not be clobbered by dashboard refreshes mid-entry.
  // svelte-ignore state_referenced_locally
  let quantity = $state(initialQuantity(item))
  let note = $state('')
  let skipReason = $state('')
  let showNote = $state(false)
  let saving = $state(false)
  let error = $state<string | null>(null)

  let unit = $derived(
    typeof targetOf(item).unit === 'string' ? (targetOf(item).unit as string) : null,
  )
  let headline = $derived.by(() => {
    const targetQuantity = targetOf(item).quantity
    return targetQuantity != null
      ? `${targetQuantity}${unit ? ` ${unit}` : ''}`
      : "Today's target"
  })
  let guidance = $derived(
    $planDetail?.tracks.find((track) => track.id === item.trackId)?.description ?? null,
  )
  let submitLabel = $derived.by(() => {
    if (mode === 'skip') {
      return 'Skip today'
    }

    const amount = quantity.trim()
    return amount ? `Log ${amount}${unit ? ` ${unit}` : ''}` : 'Mark done'
  })

  async function handleSubmit() {
    if (!item.trackKey) {
      return
    }

    saving = true
    error = null

    try {
      if (mode === 'skip') {
        await submitTrackSkip(
          { trackKey: item.trackKey, reason: skipReason.trim() || null },
          `Skipped ${item.title}.`,
        )
      } else {
        await submitTrackLog(
          {
            trackKey: item.trackKey,
            quantity: quantity.trim() || null,
            note: note.trim() || null,
          },
          `Logged ${item.title}.`,
        )
      }

      onFinished()
    } catch (caught) {
      error = caught instanceof Error ? caught.message : 'That did not save.'
    } finally {
      saving = false
    }
  }
</script>

<form
  class="track-log-form"
  onsubmit={(event) => {
    event.preventDefault()
    handleSubmit()
  }}
>
  <div class="target-card">
    <p class="target-card-eyebrow">
      <span>Target</span>
      for {formatDate($selectedDate)}
    </p>
    <h3>{headline}</h3>
    {#if guidance}
      <p class="target-card-guidance">{guidance}</p>
    {/if}
  </div>

  <div class="field">
    <span class="field-label">What happened?</span>
    <div class="segmented-control what-happened" aria-label="What happened?">
      <button
        type="button"
        class:active={mode === 'record'}
        disabled={saving}
        onclick={() => (mode = 'record')}
      >
        Record
      </button>
      <button
        type="button"
        class:active={mode === 'skip'}
        disabled={saving}
        onclick={() => (mode = 'skip')}
      >
        Skip today
      </button>
    </div>
  </div>

  {#if mode === 'record'}
    <Field label="How much?">
      <div class="amount-row">
        <TextInput bind:value={quantity} inputmode="decimal" disabled={saving} />
        {#if unit}
          <span class="unit-chip">{unit}</span>
        {/if}
      </div>
    </Field>

    {#if showNote}
      <Field label="Note">
        <TextInput bind:value={note} disabled={saving} />
      </Field>
    {:else}
      <button
        type="button"
        class="text-button add-note-toggle"
        disabled={saving}
        onclick={() => (showNote = true)}
      >
        Add note
      </button>
    {/if}
  {:else}
    <Field label="Why skip it?" hint="Optional — honesty helps the review">
      <TextInput bind:value={skipReason} disabled={saving} />
    </Field>
  {/if}

  {#if error}
    <p class="error inline-error" role="alert">{error}</p>
  {/if}

  <div class="dialog-actions">
    {#if onCancel}
      <Button variant="secondary" disabled={saving} onclick={onCancel}>Cancel</Button>
    {/if}
    <Button type="submit" disabled={saving}>
      {saving ? (mode === 'skip' ? 'Skipping' : 'Logging') : submitLabel}
    </Button>
  </div>
</form>
