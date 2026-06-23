<script lang="ts">
  import type { DashboardData } from '../../api/types'
  import Badge from '../../components/ui/Badge.svelte'
  import Card from '../../components/ui/Card.svelte'
  import EmptyState from '../../components/ui/EmptyState.svelte'
  import LoadingState from '../../components/ui/LoadingState.svelte'
  import PlanItemRow from './PlanItemRow.svelte'

  let { data, loading }: { data: DashboardData | null; loading: boolean } = $props()
</script>

<section class="page-stack">
  {#if loading}
    <LoadingState message="Loading plan" />
  {:else if data?.planDetail}
    <div class="plan-grid">
      <Card>
        <div class="section-heading">
          <div>
            <p class="eyebrow">Current plan</p>
            <h2>{data.planDetail.summary.name}</h2>
          </div>
          <Badge tone={data.planDetail.summary.status === 'active' ? 'good' : 'neutral'}>
            {data.planDetail.summary.status}
          </Badge>
        </div>
        <p class="body-copy">{data.planDetail.summary.intention}</p>
        <dl class="metric-grid compact">
          <div>
            <dt>Schedule</dt>
            <dd>{data.planDetail.summary.startsOn} to {data.planDetail.summary.endsOn}</dd>
          </div>
          <div>
            <dt>Source</dt>
            <dd>{data.planDetail.summary.sourceKind}</dd>
          </div>
        </dl>
      </Card>

      <Card>
        <div class="section-heading">
          <div>
            <p class="eyebrow">Event model</p>
            <h2>Event types</h2>
          </div>
          <span>{data.planDetail.eventTypes.length}</span>
        </div>
        <div class="chip-list">
          {#each data.planDetail.eventTypes as eventType (eventType.id)}
            <span class="model-chip">{eventType.name}</span>
          {/each}
        </div>
      </Card>
    </div>

    <Card class="list-card">
      <div class="section-heading">
        <div>
          <p class="eyebrow">Inventory</p>
          <h2>Items</h2>
        </div>
        <span>{data.planDetail.items.length}</span>
      </div>

      {#if data.planDetail.items.length}
        <div class="plan-item-list">
          {#each data.planDetail.items as item (item.id)}
            <PlanItemRow {item} />
          {/each}
        </div>
      {:else}
        <EmptyState title="No items yet" message="Plan items will appear here once authored." />
      {/if}
    </Card>
  {:else}
    <Card>
      <EmptyState title="No plan selected" message="Install a demo plan to see the plan model." />
    </Card>
  {/if}
</section>
