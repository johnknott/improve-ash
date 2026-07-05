<script lang="ts">
  import { clearDevErrors, devErrors } from '../lib/devErrors'

  let errorCount = $derived(
    $devErrors.filter((entry) => entry.kind !== 'console.warn').length,
  )
  let label = $derived.by(() => {
    const total = $devErrors.length
    return `${total} ${total === 1 ? 'problem' : 'problems'}`
  })

  function dumpAndClear() {
    // console.info is not teed into the buffer, so this cannot recurse.
    console.info('[improve] captured problems:', $devErrors)
    clearDevErrors()
  }
</script>

{#if $devErrors.length > 0}
  <button
    class="dev-error-badge"
    class:warnings-only={errorCount === 0}
    type="button"
    title="Click to dump details to the console and clear"
    onclick={dumpAndClear}
  >
    {label}
  </button>
{/if}
