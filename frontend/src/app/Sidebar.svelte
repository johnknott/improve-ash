<script lang="ts">
  import { ChevronUp, LogOut, Settings } from '@lucide/svelte'
  import { DropdownMenu } from 'bits-ui'
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
    <DropdownMenu.Root>
      <DropdownMenu.Trigger class="user-chip">
        <span>{user.fullName?.slice(0, 1) ?? user.email.slice(0, 1).toUpperCase()}</span>
        <div>
          <strong>{user.fullName ?? user.email}</strong>
          <small>{user.email}</small>
        </div>
        <ChevronUp class="user-menu-icon" size={16} />
      </DropdownMenu.Trigger>

      <DropdownMenu.Portal>
        <DropdownMenu.Content class="dropdown-content user-menu-content" side="top" align="start" sideOffset={8}>
          <DropdownMenu.Item class="dropdown-item dropdown-action" onclick={() => go('resource-types')}>
            <Settings size={16} />
            <span>Settings</span>
          </DropdownMenu.Item>
          <div class="dropdown-separator"></div>
          <DropdownMenu.Item class="dropdown-item dropdown-danger" onclick={logoutCurrentUser}>
            <LogOut size={16} />
            <span>Logout</span>
          </DropdownMenu.Item>
        </DropdownMenu.Content>
      </DropdownMenu.Portal>
    </DropdownMenu.Root>
  </div>
</aside>
