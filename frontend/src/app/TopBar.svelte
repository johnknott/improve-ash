<script lang="ts">
  import { CheckCircle2, ClipboardPlus, Menu } from '@lucide/svelte'
  import type { DashboardData } from '../api/types'
  import { checkInDialogOpen, openLogDialog } from './appState'
  import type { AppRoute } from './routes'
  import { routeInfo } from './routes'

  let {
    route,
    data,
    onMenu
  }: {
    route: AppRoute
    data: DashboardData | null
    onMenu: () => void
  } = $props()

  let info = $derived(routeInfo(route))
  let subtitle = $derived(data?.currentPlan?.dayLabel ?? info.subtitle)
</script>

<header class="topbar">
  <button class="icon-button mobile-menu" type="button" aria-label="Open navigation" onclick={onMenu}>
    <Menu size={20} />
  </button>

  <div class="topbar-title">
    <p class="eyebrow">Improve</p>
    <h1>{info.title}</h1>
    <p>{subtitle}</p>
  </div>

  <div class="topbar-actions">
    <button class="secondary-button" type="button" onclick={() => checkInDialogOpen.set(true)}>
      <CheckCircle2 size={18} />
      <span>Check-in</span>
    </button>
    <button class="primary-button" type="button" onclick={() => openLogDialog()}>
      <ClipboardPlus size={18} />
      <span>Log</span>
    </button>
  </div>
</header>
