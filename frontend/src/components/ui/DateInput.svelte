<script lang="ts">
  import type { HTMLInputAttributes } from 'svelte/elements'

  // No fallback default so callers may bind an initially-undefined value.
  let {
    value = $bindable(),
    ...rest
  }: {
    value?: string
  } & HTMLInputAttributes = $props()
</script>

<input type="date" bind:value {...rest} />
