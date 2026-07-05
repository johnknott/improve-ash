<script lang="ts">
  import { Dialog } from 'bits-ui'
  import type { WorkItem } from '../../api/types'
  import TrackLogForm from './TrackLogForm.svelte'

  // Mounted only while an item is set (see uiState.trackLogItem), so the
  // form seeds fresh on every open.
  let { item, onClose }: { item: WorkItem; onClose: () => void } = $props()
</script>

<Dialog.Root open={true} onOpenChange={(next) => !next && onClose()}>
  <Dialog.Portal>
    <Dialog.Overlay class="dialog-overlay" />
    <Dialog.Content class="dialog-content small-dialog">
      <div class="dialog-header">
        <div>
          <Dialog.Title>Log {item.title}</Dialog.Title>
          <Dialog.Description>{item.planName}</Dialog.Description>
        </div>
        <Dialog.Close class="icon-button" aria-label="Close">×</Dialog.Close>
      </div>

      <TrackLogForm {item} onFinished={onClose} onCancel={onClose} />
    </Dialog.Content>
  </Dialog.Portal>
</Dialog.Root>
