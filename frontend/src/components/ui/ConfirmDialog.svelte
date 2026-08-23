<script lang="ts">
  import { Dialog } from 'bits-ui'
  import { handleDialogOpenAutoFocus } from '../../lib/dialogFocus'
  import Button from './Button.svelte'

  let {
    open = $bindable(false),
    title,
    message,
    confirmLabel = 'Confirm',
    busyLabel = 'Working',
    cancelLabel = 'Cancel',
    danger = false,
    onConfirm,
  }: {
    open?: boolean
    title: string
    message: string
    confirmLabel?: string
    busyLabel?: string
    cancelLabel?: string
    danger?: boolean
    onConfirm: () => void | Promise<void>
  } = $props()

  let busy = $state(false)
  let error = $state<string | null>(null)
  let content = $state<HTMLElement | null>(null)

  async function confirm() {
    busy = true
    error = null

    try {
      await onConfirm()
      open = false
    } catch (caught) {
      error = caught instanceof Error ? caught.message : 'Something went wrong.'
    } finally {
      busy = false
    }
  }

  function close() {
    if (!busy) {
      error = null
      open = false
    }
  }
</script>

<Dialog.Root {open} onOpenChange={(next) => !next && close()}>
  <Dialog.Portal>
    <Dialog.Overlay class="dialog-overlay" />
    <Dialog.Content
      bind:ref={content}
      class="dialog-content small-dialog"
      onEscapeKeydown={(event) => busy && event.preventDefault()}
      onInteractOutside={(event) => busy && event.preventDefault()}
      onOpenAutoFocus={(event) => handleDialogOpenAutoFocus(event, () => content)}
    >
      <div class="dialog-header">
        <div>
          <Dialog.Title>{title}</Dialog.Title>
          <Dialog.Description>{message}</Dialog.Description>
        </div>
        <Dialog.Close class="icon-button" aria-label="Close" disabled={busy}>×</Dialog.Close>
      </div>

      {#if error}
        <p class="error inline-error" role="alert">{error}</p>
      {/if}

      <div class="dialog-actions confirm-actions">
        <Button
          variant="secondary"
          data-dialog-initial-focus
          disabled={busy}
          onclick={close}
        >
          {cancelLabel}
        </Button>
        <Button variant={danger ? 'danger' : 'primary'} disabled={busy} onclick={confirm}>
          {busy ? busyLabel : confirmLabel}
        </Button>
      </div>
    </Dialog.Content>
  </Dialog.Portal>
</Dialog.Root>
