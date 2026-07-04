<script lang="ts">
  import type { DashboardData } from '../api/types'
  import type { CurrentUser } from '../features/auth/authClient'
  import CheckInDialog from '../features/logging/CheckInDialog.svelte'
  import LogDialog from '../features/logging/LogDialog.svelte'
  import PlaceholderPage from '../features/placeholders/PlaceholderPage.svelte'
  import NewPlanDialog from '../features/plans/NewPlanDialog.svelte'
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
    <TopBar route={$activeRoute.route} onMenu={() => (sidebarOpen = true)} />

    <div class="app-content">
      {#if error}
        <section class="error-banner">
          <div>
            <strong>Could not load Improve.</strong>
            <p>{error}</p>
          </div>
          <button class="secondary-button" type="button" onclick={onRetry}>Try again</button>
        </section>
      {/if}

      <PlaceholderPage route={$activeRoute.route} {data} />
    </div>
  </main>
</div>

<LogDialog {data} />
<CheckInDialog {data} />
<NewPlanDialog />

{#if $toastMessage}
  <div class="toast" role="status">{$toastMessage}</div>
{/if}
