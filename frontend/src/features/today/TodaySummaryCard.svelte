<script lang="ts">
  import type { TodayProjection } from '../../api/types'
  import Card from '../../components/ui/Card.svelte'
  import { formatDate } from '../../lib/dates'

  let { today }: { today: TodayProjection } = $props()
</script>

<Card class="summary-card">
  <div class="section-heading">
    <div>
      <p class="eyebrow">Today</p>
      <h2>{formatDate(today.date)}</h2>
    </div>
    <span>{today.remaining} remaining</span>
  </div>

  <dl class="metric-grid">
    <div>
      <dt>Total</dt>
      <dd>{today.total}</dd>
    </div>
    <div>
      <dt>Completed</dt>
      <dd>{today.completed}</dd>
    </div>
    <div>
      <dt>Remaining</dt>
      <dd>{today.remaining}</dd>
    </div>
  </dl>

  {#if today.diagnostics.length}
    <div class="diagnostic-list">
      {#each today.diagnostics as diagnostic}
        <p>{diagnostic}</p>
      {/each}
    </div>
  {/if}
</Card>
