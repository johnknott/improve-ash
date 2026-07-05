<script lang="ts">
  import { Hourglass } from '@lucide/svelte'
  import type { DashboardData } from '../../api/types'
  import { routeInfo, type AppRoute } from '../../app/routes'
  import Card from '../../components/ui/Card.svelte'
  import EmptyState from '../../components/ui/EmptyState.svelte'
  import DemoPlanSetup from '../setup/DemoPlanSetup.svelte'

  let { route, data }: { route: AppRoute; data: DashboardData | null } = $props()

  // One-shot hook for testing the page error boundary:
  // sessionStorage.setItem('improve-crash-test', '1') then navigate here.
  if (import.meta.env.DEV && sessionStorage.getItem('improve-crash-test')) {
    sessionStorage.removeItem('improve-crash-test')
    throw new Error('Deliberate dev crash test (improve-crash-test)')
  }

  let info = $derived(routeInfo(route))
</script>

<section class="page-stack">
  <Card>
    {#if data?.currentPlan}
      <EmptyState
        title="{info.title} is queued up"
        message="This screen will use {data.currentPlan.name} once the next slice is ready. The app shell is already reserving the route and navigation shape."
      >
        {#snippet icon()}
          <Hourglass size={26} />
        {/snippet}
      </EmptyState>
    {:else}
      <DemoPlanSetup title="Install a demo plan first" />
    {/if}
  </Card>
</section>
