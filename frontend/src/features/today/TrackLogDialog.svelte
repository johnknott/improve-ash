<script lang="ts">
  import { Dialog } from 'bits-ui'
  import type { WorkItem } from '../../api/types'
  import { handleDialogOpenAutoFocus } from '../../lib/dialogFocus'
  import TrackLogForm from './TrackLogForm.svelte'

  // Mounted only while an item is set (see uiState.trackLogItem), so the
  // form seeds fresh on every open.
  let { item, onClose }: { item: WorkItem; onClose: () => void } = $props()
  let content = $state<HTMLElement | null>(null)
  let busy = $state(false)
  const opener =
    typeof document !== 'undefined' && document.activeElement instanceof HTMLElement
      ? document.activeElement
      : null

  function focusOpener() {
    requestAnimationFrame(() => {
      const target = opener?.isConnected
        ? opener
        : document.querySelector<HTMLElement>('[data-global-log-trigger]')

      target?.focus()
    })
  }

  function restoreLogFocus(event: Event) {
    event.preventDefault()
    focusOpener()
  }

  function close() {
    onClose()
    focusOpener()
  }
</script>

<Dialog.Root open={true} onOpenChange={(next) => !next && close()}>
  <Dialog.Portal>
    <Dialog.Overlay class="dialog-overlay" />
    <Dialog.Content
      bind:ref={content}
      class="dialog-content small-dialog"
      aria-busy={busy}
      onCloseAutoFocus={restoreLogFocus}
      onEscapeKeydown={(event) => busy && event.preventDefault()}
      onInteractOutside={(event) => busy && event.preventDefault()}
      onOpenAutoFocus={(event) => handleDialogOpenAutoFocus(event, () => content)}
    >
      <div class="dialog-header">
        <div>
          <Dialog.Title>Log {item.title}</Dialog.Title>
          <Dialog.Description>{item.planName}</Dialog.Description>
        </div>
        <Dialog.Close class="icon-button" aria-label="Close" disabled={busy}>×</Dialog.Close>
      </div>

      <TrackLogForm
        {item}
        onFinished={close}
        onCancel={close}
        onBusyChange={(next) => (busy = next)}
      />
    </Dialog.Content>
  </Dialog.Portal>
</Dialog.Root>
