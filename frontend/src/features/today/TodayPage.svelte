<script lang="ts">
  import type { DashboardData } from '../../api/types'
  import Card from '../../components/ui/Card.svelte'
  import EmptyState from '../../components/ui/EmptyState.svelte'
  import LoadingState from '../../components/ui/LoadingState.svelte'
  import { greeting } from '../../lib/dates'
  import JournalEntryRow from '../journal/JournalEntryRow.svelte'
  import DemoPlanSetup from '../setup/DemoPlanSetup.svelte'
  import ProjectedWorkRow from './ProjectedWorkRow.svelte'
  import TodaySummaryCard from './TodaySummaryCard.svelte'

  let { data, loading }: { data: DashboardData | null; loading: boolean } = $props()
</script>

<section class="page-stack">
  {#if loading}
    <LoadingState message="Loading today's plan" />
  {:else if data?.today}
    <section class="today-hero">
      <div>
        <p class="eyebrow">{greeting()}</p>
        <h2>{data.currentPlan?.name ?? 'Today'}</h2>
        <p>{data.currentPlan?.intention ?? 'Your current plan is ready.'}</p>
      </div>
    </section>

    <div class="dashboard-grid">
      <TodaySummaryCard today={data.today} />

      <Card class="list-card primary-list">
        <div class="section-heading">
          <div>
            <p class="eyebrow">Work</p>
            <h2>Due today</h2>
          </div>
          <span>{data.today.work.length}</span>
        </div>

        {#if data.today.work.length}
          <div class="work-list">
            {#each data.today.work as work (work.id)}
              <ProjectedWorkRow {work} />
            {/each}
          </div>
        {:else}
          <EmptyState title="Nothing due today" message="No scheduled work is projected for this plan today." />
        {/if}
      </Card>
    </div>

    <div class="dashboard-grid secondary-grid">
      <Card class="list-card">
        <div class="section-heading">
          <div>
            <p class="eyebrow">Next</p>
            <h2>Upcoming</h2>
          </div>
          <span>{data.today.upcoming.length}</span>
        </div>

        {#if data.today.upcoming.length}
          <div class="work-list compact-list">
            {#each data.today.upcoming as work (work.id)}
              <ProjectedWorkRow {work} />
            {/each}
          </div>
        {:else}
          <EmptyState title="No upcoming work" message="The next few days are clear for this plan." />
        {/if}
      </Card>

      <Card class="list-card">
        <div class="section-heading">
          <div>
            <p class="eyebrow">Journal</p>
            <h2>Recent</h2>
          </div>
          <span>{data.journal.length}</span>
        </div>

        {#if data.journal.length}
          <div class="journal-list">
            {#each data.journal.slice(0, 3) as entry (entry.id)}
              <JournalEntryRow {entry} />
            {/each}
          </div>
        {:else}
          <EmptyState title="No events yet" message="Logged work will show up here as journal history." />
        {/if}
      </Card>
    </div>
  {:else}
    <Card>
      <DemoPlanSetup title="Install a plan to see Today" />
    </Card>
  {/if}
</section>
