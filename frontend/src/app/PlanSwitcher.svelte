<script lang="ts">
  import { Check, ChevronDown, ListChecks, Plus } from '@lucide/svelte'
  import { DropdownMenu } from 'bits-ui'
  import type { Plan } from '../api/types'
  import { selectedPlanId, loadDashboard, openNewPlanDialog } from './appState'

  let { plans, currentPlan }: { plans: Plan[]; currentPlan: Plan | null } = $props()

  async function selectPlan(planId: string) {
    selectedPlanId.set(planId)
    await loadDashboard(planId)
  }
</script>

<DropdownMenu.Root>
  <DropdownMenu.Trigger class="plan-switcher">
    <ListChecks class="plan-switcher-icon" size={18} />
    <span class="plan-switcher-copy">
      <strong>{currentPlan?.name ?? 'No plan'}</strong>
      <span>{currentPlan?.dayLabel ?? 'Create or import a plan'}</span>
    </span>
    <ChevronDown class="plan-switcher-icon" size={16} />
  </DropdownMenu.Trigger>

  <DropdownMenu.Portal>
    <DropdownMenu.Content class="dropdown-content" sideOffset={8}>
      {#if plans.length}
        {#each plans as plan (plan.id)}
          <DropdownMenu.Item class="dropdown-item" onclick={() => selectPlan(plan.id)}>
            <span class="plan-option">
              <span>{plan.name}</span>
              {#if plan.id === currentPlan?.id}
                <Check size={15} />
              {/if}
            </span>
            <small>{plan.dayLabel}</small>
          </DropdownMenu.Item>
        {/each}
        <div class="dropdown-separator"></div>
      {/if}

      <DropdownMenu.Item class="dropdown-item dropdown-action" onclick={openNewPlanDialog}>
        <Plus size={16} />
        <span>New plan</span>
      </DropdownMenu.Item>
    </DropdownMenu.Content>
  </DropdownMenu.Portal>
</DropdownMenu.Root>

<style>
  .plan-option {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 0.5rem;
    color: inherit;
    font-weight: 600;
  }

  .plan-option :global(svg) {
    color: var(--brand-strong);
  }
</style>
