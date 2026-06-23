<script lang="ts">
  import { DropdownMenu } from 'bits-ui'
  import type { Plan } from '../api/types'
  import { selectedPlanId, loadDashboard } from './appState'

  let { plans, currentPlan }: { plans: Plan[]; currentPlan: Plan | null } = $props()

  async function selectPlan(planId: string) {
    selectedPlanId.set(planId)
    await loadDashboard(planId)
  }
</script>

<DropdownMenu.Root>
  <DropdownMenu.Trigger class="plan-switcher" disabled={plans.length <= 1}>
    <span class="plan-switcher-label">Current plan</span>
    <strong>{currentPlan?.name ?? 'No active plan'}</strong>
    <span>{currentPlan?.dayLabel ?? 'Create or import a plan'}</span>
  </DropdownMenu.Trigger>

  {#if plans.length > 1}
    <DropdownMenu.Portal>
      <DropdownMenu.Content class="dropdown-content" sideOffset={8}>
        {#each plans as plan (plan.id)}
          <DropdownMenu.Item class="dropdown-item" onclick={() => selectPlan(plan.id)}>
            <span>{plan.name}</span>
            <small>{plan.dayLabel}</small>
          </DropdownMenu.Item>
        {/each}
      </DropdownMenu.Content>
    </DropdownMenu.Portal>
  {/if}
</DropdownMenu.Root>
