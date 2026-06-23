<script lang="ts">
  import { requestLoginCode, verifyLoginCode } from './authClient'
  import { setCurrentUser } from './authStore'

  let step: 'email' | 'code' = $state('email')
  let email = $state('')
  let code = $state('')
  let loading = $state(false)
  let error = $state<string | null>(null)

  async function submitEmail() {
    loading = true
    error = null

    try {
      await requestLoginCode(email)
      step = 'code'
    } catch (err) {
      error = err instanceof Error ? err.message : 'We could not send a code right now.'
    } finally {
      loading = false
    }
  }

  async function submitCode() {
    loading = true
    error = null

    try {
      const user = await verifyLoginCode(email, code)
      setCurrentUser(user)
    } catch (err) {
      error = err instanceof Error ? err.message : 'That code was invalid or expired.'
    } finally {
      loading = false
    }
  }

  function editEmail() {
    step = 'email'
    code = ''
    error = null
  }
</script>

<section class="auth-shell">
  <div class="auth-panel">
    <p class="eyebrow">Improve</p>
    <h1>Continue with email</h1>

    {#if step === 'email'}
      <form
        onsubmit={(event) => {
          event.preventDefault()
          submitEmail()
        }}
      >
        <label for="email">Email</label>
        <input
          id="email"
          bind:value={email}
          type="email"
          autocomplete="email"
          inputmode="email"
          placeholder="you@example.com"
          required
        />

        <button type="submit" disabled={loading}>
          {loading ? 'Sending code' : 'Continue'}
        </button>
      </form>
    {:else}
      <form
        onsubmit={(event) => {
          event.preventDefault()
          submitCode()
        }}
      >
        <div class="email-row">
          <span>{email}</span>
          <button type="button" class="text-button" onclick={editEmail}>Edit</button>
        </div>

        <label for="code">Code</label>
        <input
          id="code"
          bind:value={code}
          type="text"
          autocomplete="one-time-code"
          inputmode="numeric"
          maxlength="6"
          pattern="[0-9]{6}"
          placeholder="123456"
          required
        />

        <button type="submit" disabled={loading}>
          {loading ? 'Checking code' : 'Enter Improve'}
        </button>
      </form>
    {/if}

    {#if error}
      <p class="error" role="alert">{error}</p>
    {/if}
  </div>
</section>
