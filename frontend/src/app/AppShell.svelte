<script lang="ts">
  import type { DashboardData } from '../api/types'
  import type { CurrentUser } from '../features/auth/authClient'
  import EventTypesPage from '../features/eventTypes/EventTypesPage.svelte'
  import InventoryEventDialog from '../features/inventory/InventoryEventDialog.svelte'
  import InventoryPage from '../features/inventory/InventoryPage.svelte'
  import CheckInDialog from '../features/logging/CheckInDialog.svelte'
  import LogDialog from '../features/logging/LogDialog.svelte'
  import SessionSlotLogDialog from '../features/logging/SessionSlotLogDialog.svelte'
  import JournalPage from '../features/journal/JournalPage.svelte'
  import PlaceholderPage from '../features/placeholders/PlaceholderPage.svelte'
  import NewPlanDialog from '../features/plans/NewPlanDialog.svelte'
  import PlanPage from '../features/plan/PlanPage.svelte'
  import ResourceTypesPage from '../features/resourceTypes/ResourceTypesPage.svelte'
  import SessionsPage from '../features/sessions/SessionsPage.svelte'
  import TodayPage from '../features/today/TodayPage.svelte'
  import { toastMessage } from './appState'
  import Sidebar from './Sidebar.svelte'
  import TopBar from './TopBar.svelte'
  import { activeRoute } from './routes'

  let {
    user,
    data,
    loading,
    error,
    onRetry
  }: {
    user: CurrentUser
    data: DashboardData | null
    loading: boolean
    error: string | null
    onRetry: () => void
  } = $props()

  let sidebarOpen = $state(false)

  function closeSidebar() {
    sidebarOpen = false
  }
</script>

<div class="app-frame">
  {#if sidebarOpen}
    <button class="sidebar-scrim" type="button" aria-label="Close navigation" onclick={closeSidebar}></button>
  {/if}

  <Sidebar {data} {user} open={sidebarOpen} onNavigate={closeSidebar} />

  <main class="app-main">
    <TopBar route={$activeRoute} onMenu={() => (sidebarOpen = true)} />

    {#if error}
      <section class="error-banner">
        <div>
          <strong>Could not load Improve.</strong>
          <p>{error}</p>
        </div>
        <button class="secondary-button" type="button" onclick={onRetry}>Try again</button>
      </section>
    {/if}

    {#if $activeRoute === 'today'}
      <TodayPage {data} {loading} />
    {:else if $activeRoute === 'journal'}
      <JournalPage {data} {loading} />
    {:else if $activeRoute === 'plan'}
      <PlanPage {data} {loading} />
    {:else if $activeRoute === 'sessions'}
      <SessionsPage {data} {loading} />
    {:else if $activeRoute === 'inventory'}
      <InventoryPage {data} {loading} />
    {:else if $activeRoute === 'event-types'}
      <EventTypesPage {data} {loading} />
    {:else if $activeRoute === 'resource-types'}
      <ResourceTypesPage {data} {loading} />
    {:else}
      <PlaceholderPage route={$activeRoute} {data} />
    {/if}
  </main>
</div>

<LogDialog {data} />
<SessionSlotLogDialog {data} />
<CheckInDialog {data} />
<InventoryEventDialog {data} />
<NewPlanDialog />

{#if $toastMessage}
  <div class="toast" role="status">{$toastMessage}</div>
{/if}
