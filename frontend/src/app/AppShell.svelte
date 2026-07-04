<script lang="ts">
  import type { Component } from 'svelte'
  import type { DashboardData } from '../api/types'
  import type { CurrentUser } from '../features/auth/authClient'
  import CheckInDialog from '../features/logging/CheckInDialog.svelte'
  import LogDialog from '../features/logging/LogDialog.svelte'
  import PlaceholderPage from '../features/placeholders/PlaceholderPage.svelte'
  import NewPlanDialog from '../features/plans/NewPlanDialog.svelte'
  import TodayPage from '../features/today/TodayPage.svelte'
  import { toastMessage } from './uiState'
  import Sidebar from './Sidebar.svelte'
  import TopBar from './TopBar.svelte'
  import { activeRoute, type AppRoute } from './routes'

  // Routes without a real page yet fall back to PlaceholderPage.
  const pages: Partial<Record<AppRoute, Component>> = {
    today: TodayPage,
  }

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

      {#if pages[$activeRoute.route]}
        {@const Page = pages[$activeRoute.route]!}
        <Page />
      {:else}
        <PlaceholderPage route={$activeRoute.route} {data} />
      {/if}
    </div>
  </main>
</div>

<LogDialog {data} />
<CheckInDialog {data} />
<NewPlanDialog />

{#if $toastMessage}
  <div class="toast" role="status">{$toastMessage}</div>
{/if}
