<script lang="ts">
  import type { Snippet } from 'svelte'
  import type { HTMLButtonAttributes } from 'svelte/elements'

  type Variant = 'primary' | 'secondary' | 'ghost' | 'danger' | 'text' | 'icon'

  let {
    variant = 'primary',
    disabled = false,
    class: className = '',
    children,
    ...rest
  }: {
    variant?: Variant
    class?: string
    children: Snippet
  } & HTMLButtonAttributes = $props()

  const variantClasses: Record<Variant, string> = {
    primary: 'primary-button',
    secondary: 'secondary-button',
    ghost: 'ghost-button',
    danger: 'danger-button',
    text: 'text-button',
    icon: 'icon-button',
  }
</script>

<button type="button" class="{variantClasses[variant]} {className}" {disabled} {...rest}>
  {@render children()}
</button>
