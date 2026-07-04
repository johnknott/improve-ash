<script lang="ts">
  import type { HTMLInputAttributes } from 'svelte/elements'

  let {
    value = $bindable(''),
    ...rest
  }: {
    value?: string
  } & HTMLInputAttributes = $props()
</script>

<input type="text" bind:value {...rest} />
