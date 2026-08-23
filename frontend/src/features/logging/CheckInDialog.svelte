<script lang="ts">
  import { Dialog } from 'bits-ui'
  import { ClipboardCheck } from '@lucide/svelte'
  import type { WorkItem } from '../../api/types'
  import { today } from '../../app/dashboardState'
  import { checkInDialogOpen, showToast } from '../../app/uiState'
  import Button from '../../components/ui/Button.svelte'
  import { formatDate } from '../../lib/dates'
  import { focusDialogTarget, handleDialogOpenAutoFocus } from '../../lib/dialogFocus'
  import { selectedDate } from '../../app/dashboardState'
  import CheckInSessionStep from './CheckInSessionStep.svelte'
  import TrackLogForm from '../today/TrackLogForm.svelte'

  const REMAINING = ['planned', 'started', 'partial']

  // stage: intro → one step per remaining item → done.
  // The queue is frozen at Start so completing an item (which refreshes the
  // dashboard and drops it from `today.work`) doesn't reshuffle the wizard
  // mid-sweep; we just walk the frozen list by index.
  let stage = $state<'intro' | 'steps' | 'done'>('intro')
  let queue = $state<WorkItem[]>([])
  let index = $state(0)
  let handled = $state(0)
  let seeded = $state(false)
  let content = $state<HTMLElement | null>(null)
  let busy = $state(false)

  let work = $derived($today?.work ?? [])
  let remaining = $derived(work.filter((item) => REMAINING.includes(item.status)))
  let alreadyLogged = $derived(work.filter((item) => item.status === 'completed').length)
  let current = $derived(queue[index] ?? null)

  $effect(() => {
    if ($checkInDialogOpen && !seeded) {
      stage = 'intro'
      queue = []
      index = 0
      handled = 0
      busy = false
      seeded = true
    }

    if (!$checkInDialogOpen) {
      seeded = false
    }
  })

  function close() {
    if (busy) {
      return
    }

    checkInDialogOpen.set(false)
  }

  function start() {
    queue = remaining
    index = 0
    handled = 0
    stage = queue.length > 0 ? 'steps' : 'done'
    focusDialogTarget(() => content)
  }

  function advance() {
    if (index + 1 < queue.length) {
      index += 1
    } else {
      stage = 'done'
    }

    focusDialogTarget(() => content)
  }

  function onStepFinished() {
    handled += 1
    advance()
  }

  function back() {
    if (index > 0) {
      index -= 1
    } else {
      stage = 'intro'
    }

    focusDialogTarget(() => content)
  }

  function finishSweep() {
    if (handled > 0) {
      showToast('Check-in saved.')
    }
    close()
  }
</script>

<Dialog.Root open={$checkInDialogOpen} onOpenChange={(next) => !next && close()}>
  <Dialog.Portal>
    <Dialog.Overlay class="dialog-overlay" />
    <Dialog.Content
      bind:ref={content}
      class="dialog-content small-dialog"
      aria-busy={busy}
      onEscapeKeydown={(event) => busy && event.preventDefault()}
      onInteractOutside={(event) => busy && event.preventDefault()}
      onOpenAutoFocus={(event) => handleDialogOpenAutoFocus(event, () => content)}
    >
      {#if stage === 'intro'}
        <div class="dialog-header">
          <div>
            <Dialog.Title>Check-in for {formatDate($selectedDate)}</Dialog.Title>
            <Dialog.Description>Work through what's left, one at a time.</Dialog.Description>
          </div>
          <Dialog.Close class="icon-button" aria-label="Close" disabled={busy}>×</Dialog.Close>
        </div>

        <div class="checkin-intro">
          <span class="checkin-intro-icon"><ClipboardCheck size={22} /></span>
          <div class="checkin-counts">
            <div class="checkin-count">
              <strong>{work.length}</strong>
              <span>targets</span>
            </div>
            <div class="checkin-count">
              <strong>{alreadyLogged}</strong>
              <span>already logged</span>
            </div>
            <div class="checkin-count">
              <strong>{remaining.length}</strong>
              <span>to review</span>
            </div>
          </div>
        </div>

        <div class="dialog-actions">
          <Button
            variant="secondary"
            data-dialog-initial-focus={remaining.length === 0 ? true : undefined}
            onclick={close}
          >
            Not now
          </Button>
          <Button
            data-dialog-initial-focus={remaining.length > 0 ? true : undefined}
            disabled={remaining.length === 0}
            onclick={start}
          >
            {remaining.length === 0 ? 'All done' : 'Start check-in'}
          </Button>
        </div>
      {:else if stage === 'steps' && current}
        <div class="dialog-header">
          <div>
            <Dialog.Title>{current.title}</Dialog.Title>
            <Dialog.Description>{index + 1} of {queue.length}</Dialog.Description>
          </div>
          <Dialog.Close class="icon-button" aria-label="Close" disabled={busy}>×</Dialog.Close>
        </div>

        {#key current.id}
          {#if current.kind === 'session'}
            <CheckInSessionStep
              item={current}
              onFinished={onStepFinished}
              onBack={back}
              onLeave={advance}
              onBusyChange={(next) => (busy = next)}
            />
          {:else}
            <TrackLogForm
              item={current}
              onFinished={onStepFinished}
              onBack={back}
              onLeave={advance}
              onBusyChange={(next) => (busy = next)}
            />
          {/if}
        {/key}
      {:else}
        <div class="dialog-header">
          <div>
            <Dialog.Title>Check-in complete</Dialog.Title>
            <Dialog.Description>
              {handled === 0
                ? 'Nothing left to sweep today.'
                : `${handled} ${handled === 1 ? 'item' : 'items'} handled.`}
            </Dialog.Description>
          </div>
          <Dialog.Close class="icon-button" aria-label="Close" disabled={busy}>×</Dialog.Close>
        </div>

        <div class="checkin-done">
          <span class="checkin-intro-icon"><ClipboardCheck size={22} /></span>
          <p>You're on top of today.</p>
        </div>

        <div class="dialog-actions">
          <Button data-dialog-initial-focus onclick={finishSweep}>Done</Button>
        </div>
      {/if}
    </Dialog.Content>
  </Dialog.Portal>
</Dialog.Root>
