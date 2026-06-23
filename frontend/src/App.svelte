<script lang="ts">
  import { onMount } from 'svelte'
  import AppShell from './app/AppShell.svelte'
  import { dashboardState, loadDashboard, resetDashboard } from './app/appState'
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
  <main class="loading-shell">
    <p>Loading Improve</p>
  </main>
{:else if !$authState.user}
  <LoginPage />
{:else if !$authState.user.fullName}
  <CompleteProfilePage />
{:else}
  <AppShell
    user={$authState.user}
    data={$dashboardState.data}
    loading={$dashboardState.loading}
    error={$dashboardState.error}
    onRetry={() => loadDashboard()}
  />
{/if}
