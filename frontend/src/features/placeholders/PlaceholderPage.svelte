<script lang="ts">
  import type { DashboardData } from '../../api/types'
  import { routeInfo, type AppRoute } from '../../app/routes'
  import Card from '../../components/ui/Card.svelte'
  import EmptyState from '../../components/ui/EmptyState.svelte'

  let { route, data }: { route: AppRoute; data: DashboardData | null } = $props()

  let info = $derived(routeInfo(route))
</script>

<section class="page-stack">
  <Card>
    <EmptyState
      title={`${info.title} is queued up`}
      message={`This screen will use ${data?.currentPlan?.name ?? 'the current plan'} once the next slice is ready. The app shell is already reserving the route and navigation shape.`}
    />
  </Card>
</section>
