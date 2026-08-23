<script lang="ts">
  import { ArrowRight, Link2 } from '@lucide/svelte'
  import type { JournalEventDetail, JournalEventStatus } from '../../api/types'
  import Badge from '../../components/ui/Badge.svelte'
  import Button from '../../components/ui/Button.svelte'
  import { formatDateTime } from '../../lib/dates'

  let {
    event,
    onOpen,
  }: {
    event: JournalEventDetail
    onOpen: (event: JournalEventDetail) => void
  } = $props()

  const tones: Record<JournalEventStatus, string> = {
    active: 'good',
    corrected: 'info',
    voided: 'warning',
    skipped: 'neutral',
  }

  let quantity = $derived(
    event.quantity == null ? null : `${event.quantity}${event.unit ? ` ${event.unit}` : ''}`,
  )
  let linkedItemNames = $derived(
    event.itemLinks.map((link) => link.itemName).filter((name): name is string => Boolean(name)),
  )

  function label(value: string): string {
    return value.replaceAll('_', ' ')
  }
</script>

<article class="journal-event" aria-labelledby={`journal-event-${event.id}`}>
  <div class="journal-event-main">
    <div class="journal-event-heading">
      <div>
        <p class="journal-event-type">{event.eventTypeName ?? 'Journal event'}</p>
        <h2 id={`journal-event-${event.id}`}>{event.summary}</h2>
      </div>
      <Badge tone={tones[event.status]}>{label(event.status)}</Badge>
    </div>

    <div class="journal-event-meta">
      <time datetime={event.effectiveAt}>{formatDateTime(event.effectiveAt)}</time>
      {#if quantity}<span>{quantity}</span>{/if}
      {#if event.trackName}<span>{event.trackName}</span>{/if}
    </div>

    {#if event.note}
      <p class="journal-event-note">{event.note}</p>
    {/if}

    {#if linkedItemNames.length > 0 || event.correction.replaces || event.correction.replacedBy.length > 0}
      <div class="journal-event-context">
        {#if linkedItemNames.length > 0}
          <span><Link2 size={14} aria-hidden="true" /> {linkedItemNames.join(', ')}</span>
        {/if}
        {#if event.correction.replaces}
          <span>Corrects an earlier entry</span>
        {/if}
        {#if event.correction.replacedBy.length > 0}
          <span>Has a correction</span>
        {/if}
      </div>
    {/if}
  </div>

  <Button
    variant="secondary"
    class="journal-detail-button"
    aria-label={`View details for ${event.summary}`}
    onclick={() => onOpen(event)}
  >
    View details
    <ArrowRight size={16} aria-hidden="true" />
  </Button>
</article>
