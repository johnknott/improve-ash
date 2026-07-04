<script lang="ts">
  import type { HTMLInputAttributes } from 'svelte/elements'

  // No fallback default so callers may bind an initially-undefined value
  // (e.g. an object property that gets seeded after mount) without tripping
  // Svelte's props_invalid_value error.
  let {
    value = $bindable(),
    ...rest
  }: {
    value?: string
  } & HTMLInputAttributes = $props()
</script>

<input type="text" bind:value {...rest} />
