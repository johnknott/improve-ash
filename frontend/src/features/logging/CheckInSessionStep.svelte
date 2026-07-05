<script lang="ts">
  import type { WorkItem } from '../../api/types'
  import { finishSession, skipWholeSession, startProjectedSession } from '../../app/dashboardState'
  import Button from '../../components/ui/Button.svelte'
  import Field from '../../components/ui/Field.svelte'
  import TextInput from '../../components/ui/TextInput.svelte'

  // A session step in the check-in sweep: a quick slot summary and the
  // whole-session decisions. Slot-by-slot logging still lives on the Today
  // card; here the sweep just needs complete / skip / leave.
  let {
    item,
    onFinished,
    onBack = null,
    onLeave = null,
  }: {
    item: WorkItem
    onFinished: () => void
    onBack?: (() => void) | null
    onLeave?: (() => void) | null
  } = $props()

  let skipReason = $state('')
  let showSkipReason = $state(false)
  let saving = $state(false)
  let error = $state<string | null>(null)

  let session = $derived(item.session)
  let occurrenceId = $derived(session?.state.sessionOccurrenceId ?? null)
  let started = $derived(Boolean(occurrenceId))
  let slotCount = $derived(session?.recommendations.length ?? 0)
  let summaryLine = $derived.by(() => {
    const base = `${slotCount} ${slotCount === 1 ? 'slot' : 'slots'}`
    return started && session?.state.progressLabel
      ? `${base} · ${session.state.progressLabel}`
      : base
  })

  async function run(action: () => Promise<void>) {
    saving = true
    error = null

    try {
      await action()
      onFinished()
    } catch (caught) {
      error = caught instanceof Error ? caught.message : 'That did not save.'
    } finally {
      saving = false
    }
  }

  function complete() {
    if (occurrenceId) {
      run(() => finishSession(occurrenceId!))
    }
  }

  function start() {
    if (session) {
      run(() => startProjectedSession(session!.sessionTemplateId))
    }
  }

  function skip() {
    if (occurrenceId) {
      run(() => skipWholeSession(occurrenceId!, skipReason.trim() || null))
    }
  }
</script>

<div class="track-log-form">
  <div class="target-card">
    <p class="target-card-eyebrow"><span>Session</span></p>
    <h3>{item.title}</h3>
    {#if session}
      <p class="target-card-guidance">{summaryLine}</p>
    {/if}
  </div>

  {#if !started}
    <p class="hint">This session hasn't been started. Start it to log slot by slot on Today.</p>
  {/if}

  {#if showSkipReason}
    <Field label="Why skip it?" hint="Optional — honesty helps the review">
      <TextInput bind:value={skipReason} disabled={saving} />
    </Field>
  {/if}

  {#if error}
    <p class="error inline-error" role="alert">{error}</p>
  {/if}

  <div class="dialog-actions track-log-actions">
    {#if onBack}
      <Button variant="ghost" disabled={saving} onclick={onBack}>Back</Button>
    {/if}
    <span class="track-log-actions-spacer"></span>
    {#if onLeave}
      <Button variant="secondary" disabled={saving} onclick={onLeave}>Leave</Button>
    {/if}
    {#if started}
      {#if showSkipReason}
        <Button variant="secondary" disabled={saving} onclick={skip}>Skip session</Button>
      {:else}
        <Button variant="secondary" disabled={saving} onclick={() => (showSkipReason = true)}>
          Skip
        </Button>
      {/if}
      <Button disabled={saving} onclick={complete}>
        {saving ? 'Working' : 'Complete'}
      </Button>
    {:else}
      <Button disabled={saving} onclick={start}>
        {saving ? 'Starting' : 'Start session'}
      </Button>
    {/if}
  </div>
</div>
