<script lang="ts">
  import { Dialog } from 'bits-ui'
  import type { DashboardData } from '../../api/types'
  import { checkInDialogOpen } from '../../app/appState'

  let { data }: { data: DashboardData | null } = $props()
</script>

<Dialog.Root open={$checkInDialogOpen} onOpenChange={(open) => checkInDialogOpen.set(open)}>
  <Dialog.Portal>
    <Dialog.Overlay class="dialog-overlay" />
    <Dialog.Content class="dialog-content small-dialog">
      <div class="dialog-header">
        <div>
          <Dialog.Title>Check-in</Dialog.Title>
          <Dialog.Description>
            {data?.currentPlan ? `A lightweight check-in for ${data.currentPlan.name}.` : 'Select a plan before checking in.'}
          </Dialog.Description>
        </div>
        <Dialog.Close class="icon-button" aria-label="Close">×</Dialog.Close>
      </div>

      <div class="checkin-preview">
        <p>Check-ins are reserved for the next UI slice.</p>
        <p>The global action is wired now so we can hang the Ash action here when the domain model is ready.</p>
      </div>

      <div class="dialog-actions">
        <Dialog.Close class="primary-button">Done</Dialog.Close>
      </div>
    </Dialog.Content>
  </Dialog.Portal>
</Dialog.Root>
