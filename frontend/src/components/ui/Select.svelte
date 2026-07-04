<script lang="ts" generics="T extends string">
  import type { Snippet } from 'svelte'
  import type { HTMLSelectAttributes } from 'svelte/elements'

  let {
    value = $bindable(),
    children,
    ...rest
  }: {
    value?: T
    children: Snippet
  } & HTMLSelectAttributes = $props()
</script>

<select bind:value {...rest}>
  {@render children()}
</select>
