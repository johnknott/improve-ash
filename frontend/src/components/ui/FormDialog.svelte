<script lang="ts">
  import { Dialog } from 'bits-ui'
  import type { Snippet } from 'svelte'
  import { dialogFirstFieldSelector, handleDialogOpenAutoFocus } from '../../lib/dialogFocus'
  import Button from './Button.svelte'

  // The shared dialog-form shell: header with close, a form that submits on
  // Enter, a general error line, and cancel/submit actions that disable
  // while busy. Field content comes in through the children snippet.
  let {
    open,
    title,
    submitLabel,
    busyLabel = 'Saving',
    cancelLabel = 'Cancel',
    busy = false,
    submitDisabled = false,
    error = null,
    class: className = '',
    onClose,
    onSubmit,
    children,
  }: {
    open: boolean
    title: string
    submitLabel: string
    busyLabel?: string
    cancelLabel?: string
    busy?: boolean
    submitDisabled?: boolean
    error?: string | null
    class?: string
    onClose: () => void
    onSubmit: () => void
    children: Snippet
  } = $props()

  let content = $state<HTMLElement | null>(null)
</script>

<Dialog.Root {open} onOpenChange={(next) => !next && onClose()}>
  <Dialog.Portal>
    <Dialog.Overlay class="dialog-overlay" />
    <Dialog.Content
      bind:ref={content}
      class="dialog-content {className}"
      onEscapeKeydown={(event) => busy && event.preventDefault()}
      onInteractOutside={(event) => busy && event.preventDefault()}
      onOpenAutoFocus={(event) =>
        handleDialogOpenAutoFocus(event, () => content, dialogFirstFieldSelector)}
    >
      <div class="dialog-header">
        <div>
          <Dialog.Title>{title}</Dialog.Title>
        </div>
        <Dialog.Close class="icon-button" aria-label="Close" disabled={busy}>×</Dialog.Close>
      </div>

      <form
        class="dialog-form"
        onsubmit={(event) => {
          event.preventDefault()
          onSubmit()
        }}
      >
        {@render children()}

        {#if error}
          <p class="error inline-error" role="alert">{error}</p>
        {/if}

        <div class="dialog-actions">
          <Button
            variant="secondary"
            data-dialog-initial-focus
            disabled={busy}
            onclick={onClose}
          >
            {cancelLabel}
          </Button>
          <Button type="submit" disabled={busy || submitDisabled}>
            {busy ? busyLabel : submitLabel}
          </Button>
        </div>
      </form>
    </Dialog.Content>
  </Dialog.Portal>
</Dialog.Root>
