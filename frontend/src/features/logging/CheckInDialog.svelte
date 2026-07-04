<script lang="ts">
  import type { WorkItem } from '../../api/types'
  import {
    finishSession,
    skipWholeSession,
    submitTrackLog,
    today,
  } from '../../app/dashboardState'
  import { checkInDialogOpen, showToast } from '../../app/uiState'
  import Field from '../../components/ui/Field.svelte'
  import FormDialog from '../../components/ui/FormDialog.svelte'
  import TextInput from '../../components/ui/TextInput.svelte'

  type Choice = 'done' | 'skip' | 'leave'

  let choices = $state<Record<string, Choice>>({})
  let skipNotes = $state<Record<string, string>>({})
  let rowErrors = $state<Record<string, string>>({})
  let saving = $state(false)
  let seeded = $state(false)

  let rows = $derived(
    ($today?.work ?? []).filter((item) =>
      ['planned', 'started', 'partial'].includes(item.status),
    ),
  )

  $effect(() => {
    if ($checkInDialogOpen && !seeded) {
      choices = {}
      skipNotes = {}
      rowErrors = {}
      saving = false
      seeded = true
    }

    if (!$checkInDialogOpen) {
      seeded = false
    }
  })

  function close() {
    checkInDialogOpen.set(false)
  }

  // Tracks can be marked done (quick-log with target defaults) or left;
  // sessions can be completed (once started), skipped with a reason, or left.
  function rowChoices(item: WorkItem): Choice[] {
    if (item.kind === 'track') {
      return item.canLog ? ['done', 'leave'] : ['leave']
    }

    const startable = Boolean(item.session?.state.sessionOccurrenceId)
    return startable ? ['done', 'skip', 'leave'] : ['skip', 'leave']
  }

  function choiceLabel(choice: Choice): string {
    if (choice === 'done') return 'Done'
    if (choice === 'skip') return 'Skip'
    return 'Leave'
  }

  function sessionSkippable(item: WorkItem): boolean {
    return item.kind === 'session' && Boolean(item.session?.state.sessionOccurrenceId)
  }

  async function applyRow(item: WorkItem, choice: Choice): Promise<void> {
    if (choice === 'leave') {
      return
    }

    if (item.kind === 'track') {
      // Send the target the card showed (the effective target), so "done"
      // means "did the planned amount".
      const target = item.target as Record<string, unknown>

      await submitTrackLog(
        {
          trackKey: item.trackKey!,
          quantity: target?.quantity != null ? String(target.quantity) : null,
          unit: typeof target?.unit === 'string' ? target.unit : null,
        },
        '',
      )
      return
    }

    const occurrenceId = item.session?.state.sessionOccurrenceId

    if (!occurrenceId) {
      throw new Error('This session has not been started.')
    }

    if (choice === 'done') {
      await finishSession(occurrenceId)
    } else {
      await skipWholeSession(occurrenceId, (skipNotes[item.id] ?? '').trim() || null)
    }
  }

  async function handleSubmit() {
    saving = true
    rowErrors = {}
    let failures = 0

    for (const item of rows) {
      const choice = choices[item.id] ?? 'leave'

      try {
        await applyRow(item, choice)
      } catch (caught) {
        failures += 1
        rowErrors = {
          ...rowErrors,
          [item.id]: caught instanceof Error ? caught.message : 'That did not apply.',
        }
      }
    }

    saving = false

    if (failures === 0) {
      showToast('Check-in saved.')
      close()
    }
  }
</script>

<FormDialog
  open={$checkInDialogOpen}
  title="Evening check-in"
  submitLabel="Apply check-in"
  busyLabel="Applying"
  busy={saving}
  error={null}
  onClose={close}
  onSubmit={handleSubmit}
>
  {#if rows.length === 0}
    <p class="hint">Everything is wrapped up — nothing left to sweep today.</p>
  {:else}
    <p class="hint">
      Sweep what's left of today: mark it done, skip it honestly, or leave it for later.
    </p>

    <ul class="checkin-rows">
      {#each rows as item (item.id)}
        {@const available = rowChoices(item)}
        <li class="checkin-row">
          <div class="checkin-row-head">
            <span class="checkin-title">{item.title}</span>

            <div class="segmented-control checkin-choice" aria-label="Choice for {item.title}">
              {#each available as choice (choice)}
                <button
                  type="button"
                  class:active={(choices[item.id] ?? 'leave') === choice}
                  disabled={saving}
                  onclick={() => (choices[item.id] = choice)}
                >
                  {choiceLabel(choice)}
                </button>
              {/each}
            </div>
          </div>

          {#if choices[item.id] === 'skip' && sessionSkippable(item)}
            <Field label="Why skip it?" hint="Optional — honesty helps the review">
              <TextInput bind:value={skipNotes[item.id]} disabled={saving} />
            </Field>
          {/if}

          {#if rowErrors[item.id]}
            <p class="field-error" role="alert">{rowErrors[item.id]}</p>
          {/if}
        </li>
      {/each}
    </ul>
  {/if}
</FormDialog>
