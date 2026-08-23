<script lang="ts">
  import { Leaf, TriangleAlert } from '@lucide/svelte'
  import type { Today } from '../../api/types'
  import { currentPlan, today } from '../../app/dashboardState'
  import { navigate } from '../../app/routes'
  import Button from '../../components/ui/Button.svelte'
  import Card from '../../components/ui/Card.svelte'
  import EmptyState from '../../components/ui/EmptyState.svelte'
  import DemoPlanSetup from '../setup/DemoPlanSetup.svelte'
  import UpcomingStrip from './UpcomingStrip.svelte'
  import WorkItemCard from './WorkItemCard.svelte'

  function severityClass(severity: string | undefined): string {
    if (severity === 'error') return 'diagnostic-error'
    if (severity === 'info') return 'diagnostic-info'
    return 'diagnostic-warning'
  }

  function todaySummary(day: Today): string[] {
    const parts = [
      [day.completed, 'done'],
      [day.skipped, 'skipped'],
      [day.missed, 'missed'],
      [day.onHold, 'on hold'],
      [day.remaining, 'remaining'],
    ] as const

    const visible = parts
      .filter(([count]) => count > 0)
      .map(([count, label]) => `${count} ${label}`)

    return visible.length > 0 ? visible : [`${day.total} scheduled`]
  }
</script>

<section class="page-stack">
  {#if !$currentPlan}
    <Card>
      <DemoPlanSetup title="Install a demo plan first" />
    </Card>
  {:else if $today}
    {@const errorDiagnostics = $today.diagnostics.filter((d) => d.severity === 'error')}
    {@const noteDiagnostics = $today.diagnostics.filter((d) => d.severity !== 'error')}
    {@const summary = todaySummary($today)}

    {#if errorDiagnostics.length > 0}
      <section class="diagnostics-block" aria-label="Plan problems">
        {#each errorDiagnostics as diagnostic, index (index)}
          <div class="diagnostic {severityClass(diagnostic.severity)}">
            <TriangleAlert size={15} />
            <span>{diagnostic.message ?? 'This plan has an authoring problem.'}</span>
          </div>
        {/each}
        <Button variant="text" onclick={() => navigate('plan')}>Review plan setup</Button>
      </section>
    {/if}

    {#if $today.work.length > 0 || noteDiagnostics.length > 0}
      <div class="today-overview">
        {#if $today.work.length > 0}
          <header class="today-summary" aria-label={summary.join(', ')}>
            {#each summary as part, index (part)}
              {#if index > 0}
                <span class="today-summary-separator" aria-hidden="true">·</span>
              {/if}
              <span class:today-summary-primary={index === 0}>{part}</span>
            {/each}
          </header>
        {/if}

        {#if noteDiagnostics.length > 0}
          <details class="schedule-notes">
            <summary>
              {noteDiagnostics.length}
              {noteDiagnostics.length === 1 ? 'scheduling note' : 'scheduling notes'}
            </summary>
            <div class="schedule-notes-body">
              {#each noteDiagnostics as diagnostic, index (index)}
                <div class="diagnostic {severityClass(diagnostic.severity)}">
                  <TriangleAlert size={15} />
                  <span>{diagnostic.message}</span>
                </div>
              {/each}
              <Button variant="text" onclick={() => navigate('plan')}>Review plan setup</Button>
            </div>
          </details>
        {/if}
      </div>
    {/if}

    {#if $today.work.length > 0}
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
  {/if}
</section>
