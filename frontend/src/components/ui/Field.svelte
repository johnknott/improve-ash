<script lang="ts">
  import type { Snippet } from 'svelte'

  let {
    label,
    hint = '',
    error = null,
    children,
  }: {
    label: string
    hint?: string
    error?: string | null
    children: Snippet
  } = $props()
</script>

<label class="field" class:has-error={Boolean(error)}>
  <span class="field-label">{label}</span>
  {@render children()}
  {#if error}
    <span class="field-error" role="alert">{error}</span>
  {:else if hint}
    <span class="hint">{hint}</span>
  {/if}
</label>
