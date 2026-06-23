<script lang="ts">
  import { PlusCircle } from '@lucide/svelte'
  import type { DashboardData } from '../../api/types'
  import Badge from '../../components/ui/Badge.svelte'
  import Card from '../../components/ui/Card.svelte'
  import EmptyState from '../../components/ui/EmptyState.svelte'
  import LoadingState from '../../components/ui/LoadingState.svelte'
  import DemoPlanSetup from '../setup/DemoPlanSetup.svelte'
  import DirectGoalDialog from './DirectGoalDialog.svelte'
  import PlanItemRow from './PlanItemRow.svelte'

  let { data, loading }: { data: DashboardData | null; loading: boolean } = $props()
  let goalDialogOpen = $state(false)
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
            <p class="eyebrow">Goals</p>
            <h2>Direct goals</h2>
          </div>
          <button class="secondary-button compact-button" type="button" onclick={() => (goalDialogOpen = true)}>
            <PlusCircle size={16} />
            <span>Add goal</span>
          </button>
        </div>
        {#if data.planDetail.directGoals.length}
          <div class="model-list">
            {#each data.planDetail.directGoals as goal (goal.id)}
              <div class="mini-row">
                <div>
                  <strong>{goal.name}</strong>
                  <small>
                    {goal.target.quantity}{goal.target.unit ? ` ${goal.target.unit}` : ''}
                    {goal.eventTypeName ? ` · ${goal.eventTypeName}` : ''}
                  </small>
                </div>
                <Badge tone="info">{goal.schedule?.kind ?? 'scheduled'}</Badge>
              </div>
            {/each}
          </div>
        {:else}
          <EmptyState title="No goals yet" message="Add a daily goal to make work appear on Today." />
        {/if}
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
      <DemoPlanSetup title="Install a plan to inspect the model" />
    </Card>
  {/if}
</section>

<DirectGoalDialog data={data ?? null} open={goalDialogOpen} onClose={() => (goalDialogOpen = false)} />
