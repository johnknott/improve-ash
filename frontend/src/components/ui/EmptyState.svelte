<script lang="ts">
  import type { Snippet } from 'svelte'

  let {
    title,
    message,
    icon,
  }: {
    title: string
    message: string
    icon?: Snippet
  } = $props()
</script>

<div class="empty-state">
  {#if icon}
    <span class="empty-icon">{@render icon()}</span>
  {/if}
  <h2>{title}</h2>
  <p>{message}</p>
</div>
