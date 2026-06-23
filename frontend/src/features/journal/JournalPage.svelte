<script lang="ts">
  import type { DashboardData } from '../../api/types'
  import Card from '../../components/ui/Card.svelte'
  import EmptyState from '../../components/ui/EmptyState.svelte'
  import LoadingState from '../../components/ui/LoadingState.svelte'
  import DemoPlanSetup from '../setup/DemoPlanSetup.svelte'
  import JournalEntryRow from './JournalEntryRow.svelte'

  let { data, loading }: { data: DashboardData | null; loading: boolean } = $props()
</script>

<section class="page-stack">
  {#if !loading && !data?.currentPlan}
    <Card>
      <DemoPlanSetup title="Install a plan to start journaling" />
    </Card>
  {:else}
    <div class="toolbar-line">
      <label>
        Plan
        <select disabled>
          <option>{data?.currentPlan?.name ?? 'No plan selected'}</option>
        </select>
      </label>
      <label>
        View
        <select disabled>
          <option>Recent events</option>
        </select>
      </label>
    </div>

    <Card class="list-card">
      <div class="section-heading">
        <div>
          <p class="eyebrow">Journal</p>
          <h2>Recent entries</h2>
        </div>
        <span>{data?.journal.length ?? 0} shown</span>
      </div>

      {#if loading}
        <LoadingState message="Loading journal" />
      {:else if data?.journal.length}
        <div class="journal-list">
          {#each data.journal as entry (entry.id)}
            <JournalEntryRow {entry} />
          {/each}
        </div>
      {:else}
        <EmptyState title="Nothing logged yet" message="Events you log from Today will appear here." />
      {/if}
    </Card>
  {/if}
</section>
