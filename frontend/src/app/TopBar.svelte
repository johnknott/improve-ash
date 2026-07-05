<script lang="ts">
  import {
    CalendarDays,
    CheckCircle2,
    ChevronLeft,
    ChevronRight,
    ClipboardPlus,
    Menu,
    PenLine,
  } from '@lucide/svelte'
  import { DropdownMenu } from 'bits-ui'
  import {
    changeSelectedDate,
    resetSelectedDate,
    selectedDate,
    stepSelectedDate,
    today,
  } from './dashboardState'
  import { checkInDialogOpen, openLogDialog, openTrackLog } from './uiState'
  import { todayIso } from '../lib/dates'
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
  let isSelectedToday = $derived($selectedDate === todayIso())
  let loggableTracks = $derived(
    ($today?.work ?? []).filter((item) => item.kind === 'track' && item.canLog),
  )

  function trackTargetSummary(item: (typeof loggableTracks)[number]): string {
    const target = (item.target ?? {}) as Record<string, unknown>

    if (target.quantity != null) {
      return `${target.quantity}${typeof target.unit === 'string' ? ` ${target.unit}` : ''}`
    }

    return ''
  }

  function openDatePicker(event: MouseEvent & { currentTarget: HTMLInputElement }) {
    try {
      event.currentTarget.showPicker()
    } catch {
      // browsers without showPicker fall back to native focus behaviour
    }
  }
</script>

<header class="topbar">
  <div class="topbar-inner">
    <div class="topbar-left">
      <button class="icon-button mobile-menu" type="button" aria-label="Open navigation" onclick={onMenu}>
        <Menu size={20} />
      </button>
      <div class="topbar-title">
        <h1>{info.title}</h1>
      </div>
    </div>

    <div class="topbar-actions">
      {#if isSelectedToday}
        <span class="today-slot" aria-hidden="true"></span>
      {:else}
        <button class="secondary-button compact-button today-button" type="button" onclick={resetSelectedDate}>
          Today
        </button>
      {/if}
      <div class="date-controls">
        <button class="icon-button" type="button" aria-label="Previous day" onclick={() => stepSelectedDate(-1)}>
          <ChevronLeft size={18} />
        </button>
        <label class="date-field">
          <CalendarDays size={16} />
          <input
            type="date"
            value={$selectedDate}
            onclick={openDatePicker}
            onchange={(event) => changeSelectedDate(event.currentTarget.value)}
          />
        </label>
        <button class="icon-button" type="button" aria-label="Next day" onclick={() => stepSelectedDate(1)}>
          <ChevronRight size={18} />
        </button>
      </div>
      <button class="secondary-button" type="button" onclick={() => checkInDialogOpen.set(true)}>
        <CheckCircle2 size={18} />
        <span>Check-in</span>
      </button>
      <DropdownMenu.Root>
        <DropdownMenu.Trigger class="primary-button">
          <ClipboardPlus size={18} />
          <span>Log</span>
        </DropdownMenu.Trigger>

        <DropdownMenu.Portal>
          <DropdownMenu.Content class="dropdown-content log-menu" align="end" sideOffset={8}>
            {#if loggableTracks.length > 0}
              <p class="dropdown-heading">Scheduled today</p>
              {#each loggableTracks as item (item.id)}
                <DropdownMenu.Item class="dropdown-item" onclick={() => openTrackLog(item)}>
                  <span class="log-menu-title">{item.title}</span>
                  {#if trackTargetSummary(item)}
                    <small>{trackTargetSummary(item)}</small>
                  {/if}
                </DropdownMenu.Item>
              {/each}
              <div class="dropdown-separator"></div>
            {/if}

            <DropdownMenu.Item
              class="dropdown-item dropdown-action"
              onclick={() => openLogDialog()}
            >
              <PenLine size={16} />
              <span>Something else…</span>
            </DropdownMenu.Item>
          </DropdownMenu.Content>
        </DropdownMenu.Portal>
      </DropdownMenu.Root>
    </div>
  </div>
</header>
