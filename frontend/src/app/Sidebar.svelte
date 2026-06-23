<script lang="ts">
  import type { CurrentUser } from '../features/auth/authClient'
  import type { DashboardData } from '../api/types'
  import { logoutCurrentUser } from '../features/auth/authStore'
  import PlanSwitcher from './PlanSwitcher.svelte'
  import { activeRoute, navigate, type AppRoute } from './routes'

  let {
    data,
    user,
    open = false,
    onNavigate = () => {}
  }: {
    data: DashboardData | null
    user: CurrentUser
    open?: boolean
    onNavigate?: () => void
  } = $props()

  const mainNav: Array<{ id: AppRoute; label: string }> = [
    { id: 'today', label: 'Today' },
    { id: 'journal', label: 'Journal' },
    { id: 'calendar', label: 'Calendar' },
  ]

  const planNav: Array<{ id: AppRoute; label: string }> = [
    { id: 'plan', label: 'Plan' },
    { id: 'progress', label: 'Progress' },
    { id: 'sessions', label: 'Sessions' },
    { id: 'inventory', label: 'Inventory' },
  ]

  const setupNav: Array<{ id: AppRoute; label: string }> = [
    { id: 'event-types', label: 'Event Types' },
    { id: 'resource-types', label: 'Resource Types' },
  ]

  function go(route: AppRoute) {
    navigate(route)
    onNavigate()
  }
</script>

<aside class:open class="sidebar">
  <div class="brand">
    <div class="brand-mark">I</div>
    <div>
      <strong>Improve</strong>
      <span>Daily operating system</span>
    </div>
  </div>

  <PlanSwitcher plans={data?.plans ?? []} currentPlan={data?.currentPlan ?? null} />

  <nav class="nav-groups" aria-label="Primary">
    <div class="nav-group">
      <p>Main</p>
      {#each mainNav as item}
        <button class:active={$activeRoute === item.id} type="button" onclick={() => go(item.id)}>
          {item.label}
        </button>
      {/each}
    </div>

    <div class="nav-group">
      <p>Current plan</p>
      {#each planNav as item}
        <button class:active={$activeRoute === item.id} type="button" onclick={() => go(item.id)}>
          {item.label}
        </button>
      {/each}
    </div>

    <div class="nav-group">
      <p>Setup</p>
      {#each setupNav as item}
        <button class:active={$activeRoute === item.id} type="button" onclick={() => go(item.id)}>
          {item.label}
        </button>
      {/each}
    </div>
  </nav>

  <div class="sidebar-footer">
    <button type="button" class:active={$activeRoute === 'resource-types'} onclick={() => go('resource-types')}>
      Settings
    </button>

    <div class="user-chip">
      <span>{user.fullName?.slice(0, 1) ?? user.email.slice(0, 1).toUpperCase()}</span>
      <div>
        <strong>{user.fullName ?? user.email}</strong>
        <small>{user.email}</small>
      </div>
    </div>

    <button type="button" class="logout-button" onclick={logoutCurrentUser}>Logout</button>
  </div>
</aside>
