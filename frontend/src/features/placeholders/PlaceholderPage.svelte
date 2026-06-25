<script lang="ts">
  import { Hourglass } from '@lucide/svelte'
  import type { DashboardData } from '../../api/types'
  import { routeInfo, type AppRoute } from '../../app/routes'
  import Card from '../../components/ui/Card.svelte'
  import DemoPlanSetup from '../setup/DemoPlanSetup.svelte'

  let { route, data }: { route: AppRoute; data: DashboardData | null } = $props()

  let info = $derived(routeInfo(route))
</script>

<section class="page-stack">
  <Card>
    {#if data?.currentPlan}
      <div class="empty-state">
        <span class="empty-icon"><Hourglass size={26} /></span>
        <h2>{info.title} is queued up</h2>
        <p>
          This screen will use {data.currentPlan.name} once the next slice is ready. The app shell is
          already reserving the route and navigation shape.
        </p>
      </div>
    {:else}
      <DemoPlanSetup title="Install a demo plan first" />
    {/if}
  </Card>
</section>
