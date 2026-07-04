<script lang="ts">
  import { Dialog } from 'bits-ui'
  import type { Snippet } from 'svelte'
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
    error?: string | null
    class?: string
    onClose: () => void
    onSubmit: () => void
    children: Snippet
  } = $props()
</script>

<Dialog.Root {open} onOpenChange={(next) => !next && onClose()}>
  <Dialog.Portal>
    <Dialog.Overlay class="dialog-overlay" />
    <Dialog.Content class="dialog-content {className}">
      <div class="dialog-header">
        <div>
          <Dialog.Title>{title}</Dialog.Title>
        </div>
        <Dialog.Close class="icon-button" aria-label="Close">×</Dialog.Close>
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
          <Button variant="secondary" disabled={busy} onclick={onClose}>{cancelLabel}</Button>
          <Button type="submit" disabled={busy}>{busy ? busyLabel : submitLabel}</Button>
        </div>
      </form>
    </Dialog.Content>
  </Dialog.Portal>
</Dialog.Root>
