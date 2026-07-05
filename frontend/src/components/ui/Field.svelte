<script lang="ts">
  import type { Snippet } from 'svelte'

  let {
    label,
    hint = '',
    error = null,
    optional = false,
    children,
  }: {
    label: string
    hint?: string
    error?: string | null
    optional?: boolean
    children: Snippet
  } = $props()
</script>

<label class="field" class:has-error={Boolean(error)}>
  <span class="field-label">
    {label}{#if optional}<em class="field-optional">optional</em>{/if}
  </span>
  {@render children()}
  {#if error}
    <span class="field-error" role="alert">{error}</span>
  {:else if hint}
    <span class="hint">{hint}</span>
  {/if}
</label>
