<script lang="ts">
  import { ClipboardList, PauseCircle, Target } from '@lucide/svelte'
  import type { TimeOffWindow, WorkItem } from '../../api/types'
  import Badge from '../../components/ui/Badge.svelte'
  import Card from '../../components/ui/Card.svelte'
  import { formatDate } from '../../lib/dates'
  import SessionSlots from './SessionSlots.svelte'
  import TargetProgressView from './TargetProgressView.svelte'

  let { item }: { item: WorkItem } = $props()

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

    <Badge {tone}>{statusLabel}</Badge>
  </div>

  {#if item.kind === 'track'}
    <TargetProgressView progress={item.targetProgress} provenance={item.provenance} />
  {/if}

  {#if item.session}
    <SessionSlots session={item.session} />
  {/if}
</Card>
