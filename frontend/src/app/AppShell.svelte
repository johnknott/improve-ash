<script lang="ts">
  import type { Component } from 'svelte'
  import type { DashboardData } from '../api/types'
  import Button from '../components/ui/Button.svelte'
  import Card from '../components/ui/Card.svelte'
  import type { CurrentUser } from '../features/auth/authClient'
  import CheckInDialog from '../features/logging/CheckInDialog.svelte'
  import LogDialog from '../features/logging/LogDialog.svelte'
  import PlaceholderPage from '../features/placeholders/PlaceholderPage.svelte'
  import NewPlanDialog from '../features/plans/NewPlanDialog.svelte'
  import TodayPage from '../features/today/TodayPage.svelte'
  import TrackLogDialog from '../features/today/TrackLogDialog.svelte'
  import { reportBoundaryError } from '../lib/devErrors'
  import { closeTrackLog, resetUiState, toastMessage, trackLogItem } from './uiState'
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

  function errorMessage(caught: unknown): string {
    return caught instanceof Error ? caught.message : String(caught)
  }
</script>

{#snippet dialogFailed(caught: unknown, reset: () => void)}
  <div class="dialog-boundary-fallback" role="alert">
    <span>A dialog crashed: {errorMessage(caught)}</span>
    <button
      type="button"
      onclick={() => {
        resetUiState()
        reset()
      }}
    >
      Dismiss
    </button>
  </div>
{/snippet}

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

      <svelte:boundary onerror={(caught) => reportBoundaryError(caught)}>
        {#if pages[$activeRoute.route]}
          {@const Page = pages[$activeRoute.route]!}
          <Page />
        {:else}
          <PlaceholderPage route={$activeRoute.route} {data} />
        {/if}

        {#snippet failed(caught, reset)}
          <section class="page-stack">
            <Card>
              <div class="boundary-fallback" role="alert">
                <strong>This page crashed.</strong>
                <p>{errorMessage(caught)}</p>
                <Button variant="secondary" onclick={reset}>Try again</Button>
              </div>
            </Card>
          </section>
        {/snippet}
      </svelte:boundary>
    </div>
  </main>
</div>

<svelte:boundary onerror={(caught) => reportBoundaryError(caught)} failed={dialogFailed}>
  <LogDialog />
</svelte:boundary>

<svelte:boundary onerror={(caught) => reportBoundaryError(caught)} failed={dialogFailed}>
  {#if $trackLogItem}
    <TrackLogDialog item={$trackLogItem} onClose={closeTrackLog} />
  {/if}
</svelte:boundary>

<svelte:boundary onerror={(caught) => reportBoundaryError(caught)} failed={dialogFailed}>
  <CheckInDialog />
</svelte:boundary>

<svelte:boundary onerror={(caught) => reportBoundaryError(caught)} failed={dialogFailed}>
  <NewPlanDialog />
</svelte:boundary>

{#if $toastMessage}
  <div class="toast" role="status">{$toastMessage}</div>
{/if}
