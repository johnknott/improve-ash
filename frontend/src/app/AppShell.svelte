<script lang="ts">
  import { onMount, tick, type Component } from 'svelte'
  import type { DashboardData } from '../api/types'
  import Button from '../components/ui/Button.svelte'
  import Card from '../components/ui/Card.svelte'
  import LoadingState from '../components/ui/LoadingState.svelte'
  import type { CurrentUser } from '../features/auth/authClient'
  import CheckInDialog from '../features/logging/CheckInDialog.svelte'
  import LogDialog from '../features/logging/LogDialog.svelte'
  import JournalPage from '../features/journal/JournalPage.svelte'
  import PlaceholderPage from '../features/placeholders/PlaceholderPage.svelte'
  import NewPlanDialog from '../features/plans/NewPlanDialog.svelte'
  import TodayPage from '../features/today/TodayPage.svelte'
  import TrackLogDialog from '../features/today/TrackLogDialog.svelte'
  import { reportBoundaryError } from '../lib/devErrors'
  import { closeTrackLog, resetUiState, toastMessage, trackLogItem } from './uiState'
  import Sidebar from './Sidebar.svelte'
  import TopBar from './TopBar.svelte'
  import { activeRoute, routeInfo, type AppRoute } from './routes'

  // Routes without a real page yet fall back to PlaceholderPage.
  const pages: Partial<Record<AppRoute, Component>> = {
    today: TodayPage,
    journal: JournalPage,
  }

  let {
    user,
    data,
    loading,
    refreshing,
    error,
    onRetry
  }: {
    user: CurrentUser
    data: DashboardData | null
    loading: boolean
    refreshing: boolean
    error: string | null
    onRetry: () => void
  } = $props()

  let sidebarOpen = $state(false)
  let compactViewport = $state(false)
  let busy = $derived(loading || refreshing)
  let pageTitle = $derived(routeInfo($activeRoute.route).title)

  onMount(() => {
    const compactQuery = window.matchMedia('(max-width: 960px)')

    async function syncCompactViewport() {
      const nextCompactViewport = compactQuery.matches
      const focusedInSidebar =
        nextCompactViewport &&
        !compactViewport &&
        document.activeElement instanceof HTMLElement &&
        document.querySelector('#app-sidebar')?.contains(document.activeElement)
      const focusedOnMobileMenu =
        !nextCompactViewport &&
        compactViewport &&
        document.activeElement instanceof HTMLElement &&
        document.activeElement.matches('.mobile-menu')

      compactViewport = nextCompactViewport

      if (!compactViewport) {
        sidebarOpen = false
      }

      if (focusedInSidebar) {
        await tick()
        document.querySelector<HTMLButtonElement>('.mobile-menu')?.focus()
      } else if (focusedOnMobileMenu) {
        await tick()
        const sidebar = document.querySelector<HTMLElement>('#app-sidebar')
        const target =
          sidebar?.querySelector<HTMLElement>('[aria-current="page"]') ??
          sidebar?.querySelector<HTMLElement>('button:not(:disabled)')

        target?.focus()
      }
    }

    function closeOnEscape(event: KeyboardEvent) {
      if (!event.defaultPrevented && event.key === 'Escape' && compactViewport && sidebarOpen) {
        event.preventDefault()
        closeSidebar()
      }
    }

    syncCompactViewport()
    compactQuery.addEventListener('change', syncCompactViewport)
    window.addEventListener('keydown', closeOnEscape)

    return () => {
      compactQuery.removeEventListener('change', syncCompactViewport)
      window.removeEventListener('keydown', closeOnEscape)
    }
  })

  async function openSidebar() {
    sidebarOpen = true
    await tick()
    document.querySelector<HTMLElement>('#app-sidebar button:not(:disabled)')?.focus()
  }

  async function closeSidebar() {
    const restoreFocus = compactViewport && sidebarOpen
    sidebarOpen = false

    if (restoreFocus) {
      await tick()
      document.querySelector<HTMLButtonElement>('.mobile-menu')?.focus()
    }
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
  {#if compactViewport && sidebarOpen}
    <button class="sidebar-scrim" type="button" aria-label="Close navigation" onclick={closeSidebar}></button>
  {/if}

  <Sidebar
    {data}
    {user}
    {busy}
    {loading}
    compact={compactViewport}
    open={sidebarOpen}
    onNavigate={closeSidebar}
  />

  <main class="app-main" aria-busy={busy} inert={compactViewport && sidebarOpen ? true : undefined}>
    <TopBar
      route={$activeRoute.route}
      {busy}
      {refreshing}
      {sidebarOpen}
      onMenu={openSidebar}
    />

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
        {#if loading}
          <section class="page-stack">
            <Card>
              <LoadingState message={`Loading ${pageTitle.toLowerCase()}`} />
            </Card>
          </section>
        {:else if data && pages[$activeRoute.route]}
          {@const Page = pages[$activeRoute.route]!}
          <Page />
        {:else if data}
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
