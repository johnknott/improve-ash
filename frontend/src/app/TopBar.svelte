<script lang="ts">
  import { CalendarDays, CheckCircle2, ChevronLeft, ChevronRight, ClipboardPlus, Menu } from '@lucide/svelte'
  import {
    changeSelectedDate,
    checkInDialogOpen,
    openLogDialog,
    resetSelectedDate,
    selectedDate,
    stepSelectedDate,
  } from './appState'
  import type { AppRoute } from './routes'
  import { routeInfo } from './routes'

  let {
    route,
    onMenu
  }: {
    route: AppRoute
    onMenu: () => void
  } = $props()

  let info = $derived(routeInfo(route))
  let subtitle = $derived(info.subtitle)
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
    <div class="date-controls">
      <button class="icon-button" type="button" aria-label="Previous day" onclick={() => stepSelectedDate(-1)}>
        <ChevronLeft size={18} />
      </button>
      <label class="date-field">
        <CalendarDays size={17} />
        <input
          type="date"
          value={$selectedDate}
          onchange={(event) => changeSelectedDate(event.currentTarget.value)}
        />
      </label>
      <button class="icon-button" type="button" aria-label="Next day" onclick={() => stepSelectedDate(1)}>
        <ChevronRight size={18} />
      </button>
      <button class="secondary-button compact-button" type="button" onclick={resetSelectedDate}>Today</button>
    </div>
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
