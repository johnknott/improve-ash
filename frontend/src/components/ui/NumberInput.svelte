<script lang="ts">
  import type { HTMLInputAttributes } from 'svelte/elements'

  let {
    value = $bindable(null),
    ...rest
  }: {
    value?: number | null
  } & HTMLInputAttributes = $props()
</script>

<input type="number" bind:value {...rest} />
