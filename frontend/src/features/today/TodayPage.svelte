<script lang="ts">
  import { Leaf, TriangleAlert } from '@lucide/svelte'
  import { currentPlan, dashboardStatus, today } from '../../app/dashboardState'
  import { navigate } from '../../app/routes'
  import Button from '../../components/ui/Button.svelte'
  import Card from '../../components/ui/Card.svelte'
  import EmptyState from '../../components/ui/EmptyState.svelte'
  import LoadingState from '../../components/ui/LoadingState.svelte'
  import DemoPlanSetup from '../setup/DemoPlanSetup.svelte'
  import UpcomingStrip from './UpcomingStrip.svelte'
  import WorkItemCard from './WorkItemCard.svelte'

  function severityClass(severity: string | undefined): string {
    if (severity === 'error') return 'diagnostic-error'
    if (severity === 'info') return 'diagnostic-info'
    return 'diagnostic-warning'
  }
</script>

<section class="page-stack">
  {#if $dashboardStatus.loading}
    <Card>
      <LoadingState message="Loading today" />
    </Card>
  {:else if !$currentPlan}
    <Card>
      <DemoPlanSetup title="Install a demo plan first" />
    </Card>
  {:else if $today}
    {#if $today.diagnostics.length > 0}
      <section class="diagnostics-block" aria-label="Plan warnings">
        {#each $today.diagnostics as diagnostic, index (index)}
          <div class="diagnostic {severityClass(diagnostic.severity)}">
            <TriangleAlert size={15} />
            <span>{diagnostic.message ?? 'This plan has an authoring problem.'}</span>
          </div>
        {/each}
        <Button variant="text" onclick={() => navigate('plan')}>Review plan setup</Button>
      </section>
    {/if}

    {#if $today.work.length > 0}
      <header class="today-summary">
        <strong>{$today.completed} of {$today.total} done</strong>
        {#if $today.remaining > 0}
          <span>{$today.remaining} remaining</span>
        {:else}
          <span>all wrapped up</span>
        {/if}
      </header>

      <div class="work-list">
        {#each $today.work as item (item.id)}
          <WorkItemCard {item} />
        {/each}
      </div>
    {:else}
      <Card>
        <EmptyState
          title="Rest day"
          message={$today.upcoming.length > 0
            ? 'Nothing is scheduled for this date. Enjoy the space — the plan picks back up below.'
            : 'Nothing is scheduled for this date.'}
        >
          {#snippet icon()}
            <Leaf size={26} />
          {/snippet}
        </EmptyState>
      </Card>
    {/if}

    <UpcomingStrip upcoming={$today.upcoming} />

    {#if $today.explanations.length > 0}
      <details class="explanations-block">
        <summary>Why today looks like this</summary>
        <ul>
          {#each $today.explanations as explanation, index (index)}
            <li>{explanation}</li>
          {/each}
        </ul>
      </details>
    {/if}
  {/if}
</section>
