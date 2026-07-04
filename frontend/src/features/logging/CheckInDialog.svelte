<script lang="ts">
  import { Dialog } from 'bits-ui'
  import type { DashboardData } from '../../api/types'
  import { checkInDialogOpen } from '../../app/uiState'

  let { data }: { data: DashboardData | null } = $props()
</script>

<Dialog.Root open={$checkInDialogOpen} onOpenChange={(open) => checkInDialogOpen.set(open)}>
  <Dialog.Portal>
    <Dialog.Overlay class="dialog-overlay" />
    <Dialog.Content class="dialog-content small-dialog">
      <div class="dialog-header">
        <div>
          <Dialog.Title>Check-in is queued up</Dialog.Title>
          <Dialog.Description>
            {data?.currentPlan ? `This will use ${data.currentPlan.name} once the track/session model is ready.` : 'Select a plan before checking in.'}
          </Dialog.Description>
        </div>
        <Dialog.Close class="icon-button" aria-label="Close">×</Dialog.Close>
      </div>

      <div class="checkin-preview">
        <p>Queued up.</p>
        <p>The shell action is staying here, but the product flow is intentionally paused while the backend model is clarified.</p>
      </div>

      <div class="dialog-actions">
        <Dialog.Close class="primary-button">Close</Dialog.Close>
      </div>
    </Dialog.Content>
  </Dialog.Portal>
</Dialog.Root>
