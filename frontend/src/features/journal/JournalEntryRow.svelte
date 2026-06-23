<script lang="ts">
  import { Clock3 } from '@lucide/svelte'
  import type { JournalEntry } from '../../api/types'
  import Badge from '../../components/ui/Badge.svelte'
  import { formatDateTime } from '../../lib/dates'

  let { entry }: { entry: JournalEntry } = $props()
</script>

<article class="journal-row">
  <div class="journal-row-main">
    <div class="journal-row-title">
      <h3>{entry.summary}</h3>
      <Badge tone={entry.status === 'voided' ? 'warning' : 'neutral'}>{entry.status}</Badge>
    </div>
    <p>
      {entry.eventTypeName ?? 'Event'}
      {#if entry.quantity}
        · {entry.quantity}{entry.unit ? ` ${entry.unit}` : ''}
      {/if}
    </p>
    {#if entry.note}
      <p class="journal-note">{entry.note}</p>
    {/if}
  </div>
  <time class="journal-time" datetime={entry.effectiveAt}>
    <Clock3 size={16} />
    {formatDateTime(entry.effectiveAt)}
  </time>
</article>
