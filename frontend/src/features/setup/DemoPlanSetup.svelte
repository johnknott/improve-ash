<script lang="ts">
  import { Dumbbell, FlaskConical } from '@lucide/svelte'
  import { installDemoPlan, installingDemoPlan } from '../../app/appState'

  let {
    title = 'Start with a demo plan',
    message = 'Install one of the demo plans to populate Today, Journal, Plan, and the setup screens.'
  }: {
    title?: string
    message?: string
  } = $props()
</script>

<div class="demo-plan-setup">
  <div>
    <p class="eyebrow">No active plan</p>
    <h2>{title}</h2>
    <p>{message}</p>
  </div>

  <div class="demo-plan-actions">
    <button class="secondary-button demo-plan-button" type="button" disabled={!!$installingDemoPlan} onclick={() => installDemoPlan('gym')}>
      <Dumbbell size={18} />
      <span>{$installingDemoPlan === 'gym' ? 'Installing training' : 'Install Training Demo'}</span>
    </button>
    <button
      class="secondary-button demo-plan-button"
      type="button"
      disabled={!!$installingDemoPlan}
      onclick={() => installDemoPlan('vial_inventory')}
    >
      <FlaskConical size={18} />
      <span>{$installingDemoPlan === 'vial_inventory' ? 'Installing inventory' : 'Install Inventory Demo'}</span>
    </button>
  </div>
</div>
