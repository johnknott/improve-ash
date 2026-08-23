export const dialogInitialFocusSelector = '[data-dialog-initial-focus]:not([disabled])'

export const dialogFirstFieldSelector = [
  'input:not([disabled]):not([type="hidden"])',
  'select:not([disabled])',
  'textarea:not([disabled])',
  dialogInitialFocusSelector,
].join(', ')

type DialogRoot = HTMLElement | null | (() => HTMLElement | null)

function resolveRoot(root: DialogRoot): HTMLElement | null {
  return typeof root === 'function' ? root() : root
}

export function focusDialogTarget(
  root: DialogRoot,
  selector = dialogInitialFocusSelector,
): void {
  requestAnimationFrame(() => {
    const content = resolveRoot(root)
    const target = content?.querySelector<HTMLElement>(selector)

    if (target) {
      target.focus()
    } else {
      content?.focus()
    }
  })
}

export function handleDialogOpenAutoFocus(
  event: Event,
  root: DialogRoot,
  selector = dialogInitialFocusSelector,
): void {
  event.preventDefault()
  focusDialogTarget(root, selector)
}
