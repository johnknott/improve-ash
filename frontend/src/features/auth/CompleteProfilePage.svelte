<script lang="ts">
  import { completeCurrentUserProfile } from './authStore'

  let fullName = $state('')
  let saving = $state(false)
  let error = $state<string | null>(null)

  let canSubmit = $derived(fullName.trim().length > 0 && !saving)

  async function handleSubmit() {
    if (!canSubmit) {
      return
    }

    saving = true
    error = null

    try {
      await completeCurrentUserProfile(fullName.trim())
    } catch {
      error = 'Please enter your name.'
    } finally {
      saving = false
    }
  }
</script>

<section class="auth-shell">
  <div class="auth-panel">
    <p class="eyebrow">Welcome</p>
    <h1>What should we call you?</h1>
    <p class="hint">This helps Improve feel a little more like your space.</p>

    <form onsubmit={(event) => { event.preventDefault(); handleSubmit() }}>
      <label for="full-name">Full name</label>
      <input
        id="full-name"
        bind:value={fullName}
        autocomplete="name"
        disabled={saving}
        placeholder="John Knott"
      />

      <button type="submit" disabled={!canSubmit}>
        {saving ? 'Saving' : 'Continue'}
      </button>
    </form>

    {#if error}
      <p class="error" role="alert">{error}</p>
    {/if}
  </div>
</section>
