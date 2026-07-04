<script lang="ts">
  import { Dialog } from 'bits-ui'
  import type { DashboardData } from '../../api/types'
  import { closeLogDialog, logDialogOpen } from '../../app/uiState'

  let { data }: { data: DashboardData | null } = $props()
</script>

<Dialog.Root open={$logDialogOpen} onOpenChange={(open) => !open && closeLogDialog()}>
  <Dialog.Portal>
    <Dialog.Overlay class="dialog-overlay" />
    <Dialog.Content class="dialog-content small-dialog">
      <div class="dialog-header">
        <div>
          <Dialog.Title>Log is queued up</Dialog.Title>
          <Dialog.Description>
            {data?.currentPlan ? `Logging for ${data.currentPlan.name} will return after the backend track/session model settles.` : 'Select a plan before logging.'}
          </Dialog.Description>
        </div>
        <Dialog.Close class="icon-button" aria-label="Close">×</Dialog.Close>
      </div>

      <div class="checkin-preview">
        <p>Queued up.</p>
        <p>This popup is intentionally neutral so we do not keep designing around the wrong product primitives.</p>
      </div>

      <div class="dialog-actions">
        <button class="primary-button" type="button" onclick={closeLogDialog}>Close</button>
      </div>
    </Dialog.Content>
  </Dialog.Portal>
</Dialog.Root>
