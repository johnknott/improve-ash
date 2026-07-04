<script lang="ts">
  import type { HTMLInputAttributes } from 'svelte/elements'

  // No fallback default so callers may bind an initially-undefined value.
  let {
    value = $bindable(),
    ...rest
  }: {
    value?: number | null
  } & HTMLInputAttributes = $props()
</script>

<input type="number" bind:value {...rest} />
