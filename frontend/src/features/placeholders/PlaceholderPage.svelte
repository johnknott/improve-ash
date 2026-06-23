<script lang="ts">
  import type { DashboardData } from '../../api/types'
  import { routeInfo, type AppRoute } from '../../app/routes'
  import Card from '../../components/ui/Card.svelte'
  import EmptyState from '../../components/ui/EmptyState.svelte'
  import DemoPlanSetup from '../setup/DemoPlanSetup.svelte'

  let { route, data }: { route: AppRoute; data: DashboardData | null } = $props()

  let info = $derived(routeInfo(route))
</script>

<section class="page-stack">
  <Card>
    {#if data?.currentPlan}
      <EmptyState
        title={`${info.title} is queued up`}
        message={`This screen will use ${data.currentPlan.name} once the next slice is ready. The app shell is already reserving the route and navigation shape.`}
      />
    {:else}
      <DemoPlanSetup title="Install a demo plan first" />
    {/if}
  </Card>
</section>
