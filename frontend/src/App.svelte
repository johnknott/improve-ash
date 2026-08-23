<script lang="ts">
  import { onMount } from 'svelte'
  import AppShell from './app/AppShell.svelte'
  import { dashboardData, dashboardStatus, loadDashboard, resetDashboard } from './app/dashboardState'
  import DevErrorBadge from './components/DevErrorBadge.svelte'
  import LoadingState from './components/ui/LoadingState.svelte'
  import CompleteProfilePage from './features/auth/CompleteProfilePage.svelte'
  import LoginPage from './features/auth/LoginPage.svelte'
  import { authState, loadCurrentUser } from './features/auth/authStore'

  let loadedUserId = $state<string | null>(null)

  onMount(() => {
    loadCurrentUser()
  })

  $effect(() => {
    const user = $authState.user

    if (user && user.fullName && loadedUserId !== user.id) {
      loadedUserId = user.id
      loadDashboard()
    }

    if ((!user || !user.fullName) && loadedUserId) {
      loadedUserId = null
      resetDashboard()
    }
  })
</script>

{#if $authState.loading}
  <main class="loading-shell" aria-busy="true">
    <div class="auth-panel auth-loading-panel">
      <p class="eyebrow">Improve</p>
      <LoadingState message="Opening your space" />
    </div>
  </main>
{:else if !$authState.user}
  <LoginPage />
{:else if !$authState.user.fullName}
  <CompleteProfilePage />
{:else}
  <AppShell
    user={$authState.user}
    data={$dashboardData}
    loading={$dashboardStatus.loading}
    refreshing={$dashboardStatus.refreshing}
    error={$dashboardStatus.error}
    onRetry={() => loadDashboard()}
  />
{/if}

{#if import.meta.env.DEV}
  <DevErrorBadge />
{/if}
