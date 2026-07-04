<script lang="ts">
  import { ClipboardList, PauseCircle, Target } from '@lucide/svelte'
  import type { TimeOffWindow, WorkItem } from '../../api/types'
  import {
    finishSession,
    skipWholeSession,
    startProjectedSession,
  } from '../../app/dashboardState'
  import { showToast } from '../../app/uiState'
  import Badge from '../../components/ui/Badge.svelte'
  import Button from '../../components/ui/Button.svelte'
  import Card from '../../components/ui/Card.svelte'
  import { formatDate } from '../../lib/dates'
  import QuickLogDialog from './QuickLogDialog.svelte'
  import SessionSlots from './SessionSlots.svelte'
  import TargetProgressView from './TargetProgressView.svelte'

  let { item }: { item: WorkItem } = $props()

  let quickLogOpen = $state(false)
  let busy = $state(false)

  let sessionState = $derived(item.session?.state ?? null)
  let canStart = $derived(
    item.kind === 'session' && item.status === 'planned' && Boolean(item.session),
  )
  let sessionOpen = $derived(item.status === 'started' || item.status === 'partial')

  async function runAction(action: () => Promise<void>) {
    busy = true

    try {
      await action()
    } catch (caught) {
      showToast(caught instanceof Error ? caught.message : 'That action failed.')
    } finally {
      busy = false
    }
  }

  function startThisSession() {
    if (item.session) {
      runAction(() => startProjectedSession(item.session!.sessionTemplateId))
    }
  }

  function completeThisSession() {
    if (sessionState?.sessionOccurrenceId) {
      runAction(() => finishSession(sessionState!.sessionOccurrenceId!))
    }
  }

  function skipThisSession() {
    if (sessionState?.sessionOccurrenceId) {
      runAction(() => skipWholeSession(sessionState!.sessionOccurrenceId!))
    }
  }

  type Tone = 'neutral' | 'good' | 'info' | 'warning'

  const statusTones: Record<string, Tone> = {
    planned: 'neutral',
    started: 'info',
    partial: 'info',
    completed: 'good',
    missed: 'warning',
    on_hold: 'neutral',
    skipped: 'neutral',
  }

  let tone = $derived(statusTones[item.status] ?? 'neutral')
  let statusLabel = $derived(
    item.status.replaceAll('_', ' ').replace(/^./, (first) => first.toUpperCase()),
  )
  let onHold = $derived(item.status === 'on_hold')
  let timeOffLine = $derived(timeOffSummary(item.session?.state.timeOffWindow ?? null))

  function timeOffSummary(window: TimeOffWindow | null): string {
    if (!window) {
      return ''
    }

    const mode = window.availability === 'fully_off' ? 'Fully off' : 'Partially off'
    const reason = window.reason ? ` — ${window.reason}` : ''
    const until = window.endsOn ? ` until ${formatDate(window.endsOn)}` : ''

    return `${mode}${reason}${until}`
  }
</script>

<Card class="work-card {onHold ? 'on-hold' : ''}">
  <div class="work-card-head">
    <span class="work-icon">
      {#if item.kind === 'session'}
        <ClipboardList size={17} />
      {:else}
        <Target size={17} />
      {/if}
    </span>

    <div class="work-card-title">
      <h3>{item.title}</h3>
      {#if item.explanation}
        <p class="work-explanation">{item.explanation}</p>
      {/if}
      {#if onHold && timeOffLine}
        <p class="time-off-line">
          <PauseCircle size={14} />
          <span>{timeOffLine}</span>
        </p>
      {/if}
    </div>

    <div class="work-card-side">
      <Badge {tone}>{statusLabel}</Badge>

      {#if item.kind === 'track' && item.canLog}
        <Button
          variant="secondary"
          class="compact-button"
          disabled={busy}
          onclick={() => (quickLogOpen = true)}
        >
          Log
        </Button>
      {:else if canStart && !onHold}
        <Button
          variant="secondary"
          class="compact-button"
          disabled={busy}
          onclick={startThisSession}
        >
          Start session
        </Button>
      {/if}
    </div>
  </div>

  {#if item.kind === 'track'}
    <TargetProgressView progress={item.targetProgress} provenance={item.provenance} />
  {/if}

  {#if item.session}
    <SessionSlots session={item.session} />

    {#if sessionOpen}
      <div class="session-actions">
        <Button variant="ghost" class="compact-button" disabled={busy} onclick={skipThisSession}>
          Skip session
        </Button>
        <Button class="compact-button" disabled={busy} onclick={completeThisSession}>
          Complete session
        </Button>
      </div>
    {/if}
  {/if}
</Card>

{#if item.kind === 'track' && item.canLog}
  <QuickLogDialog {item} bind:open={quickLogOpen} />
{/if}
