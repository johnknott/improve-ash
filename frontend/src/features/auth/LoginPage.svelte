<script lang="ts">
  import { onDestroy, tick } from 'svelte'
  import { PinInput, REGEXP_ONLY_DIGITS } from 'bits-ui'
  import Button from '../../components/ui/Button.svelte'
  import { requestLoginCode, verifyLoginCode } from './authClient'
  import { setCurrentUser } from './authStore'

  const resendCooldownSeconds = 30

  let step: 'email' | 'code' = $state('email')
  let email = $state('')
  let code = $state('')
  let loading = $state(false)
  let error = $state<string | null>(null)
  let resendCooldown = $state(0)
  let codeInput = $state<HTMLInputElement | null>(null)
  let cooldownTimer: number | undefined

  let canSubmitEmail = $derived(email.trim().length > 0 && !loading)
  let canSubmitCode = $derived(normalizeCode(code).length === 6 && !loading)

  $effect(() => {
    if (step === 'code') {
      tick().then(() => codeInput?.focus())
    }
  })

  onDestroy(() => {
    window.clearInterval(cooldownTimer)
  })

  async function submitEmail() {
    if (!canSubmitEmail) return

    loading = true
    error = null

    try {
      await requestLoginCode(email)
      step = 'code'
      startResendCooldown()
    } catch (err) {
      error = requestErrorMessage(err)
    } finally {
      loading = false
    }
  }

  async function submitCode() {
    if (!canSubmitCode) return

    loading = true
    error = null

    try {
      const user = await verifyLoginCode(email, normalizeCode(code))
      setCurrentUser(user)
    } catch (err) {
      code = ''
      error = verifyErrorMessage(err)
    } finally {
      loading = false
    }
  }

  async function resendCode() {
    if (loading || resendCooldown > 0) return

    loading = true
    error = null
    code = ''

    try {
      await requestLoginCode(email)
      startResendCooldown()
      await tick()
      codeInput?.focus()
    } catch (err) {
      error = requestErrorMessage(err)
    } finally {
      loading = false
    }
  }

  function editEmail() {
    step = 'email'
    code = ''
    error = null
  }

  function normalizeCode(value: string) {
    return value.replace(/\D/g, '').slice(0, 6)
  }

  function transformPastedCode(value: string) {
    return normalizeCode(value)
  }

  function startResendCooldown() {
    window.clearInterval(cooldownTimer)
    resendCooldown = resendCooldownSeconds

    cooldownTimer = window.setInterval(() => {
      resendCooldown = Math.max(0, resendCooldown - 1)

      if (resendCooldown === 0) {
        window.clearInterval(cooldownTimer)
      }
    }, 1000)
  }

  function requestErrorMessage(err: unknown) {
    if (err instanceof Error && err.message.includes('wait')) {
      return 'Please wait before trying again.'
    }

    return 'We could not send a code right now.'
  }

  function verifyErrorMessage(err: unknown) {
    if (err instanceof Error && err.message.includes('wait')) {
      return 'Please wait before trying again.'
    }

    return 'That code was invalid or expired.'
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

        <Button type="submit" disabled={!canSubmitEmail}>
          {loading ? 'Sending code' : 'Continue'}
        </Button>
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
        <PinInput.Root
          bind:value={code}
          bind:inputRef={codeInput}
          class="pin-root"
          disabled={loading}
          inputId="code"
          maxlength={6}
          pattern={REGEXP_ONLY_DIGITS}
          pasteTransformer={transformPastedCode}
          pushPasswordManagerStrategy="none"
        >
          {#snippet children({ cells })}
            {#each cells as cell, index (index)}
              <PinInput.Cell {cell} class="pin-cell">
                {#if cell.char !== null}
                  <span>{cell.char}</span>
                {/if}

                {#if cell.hasFakeCaret}
                  <span class="pin-caret"></span>
                {/if}
              </PinInput.Cell>
            {/each}
          {/snippet}
        </PinInput.Root>

        <Button type="submit" disabled={!canSubmitCode}>
          {loading ? 'Checking code' : 'Enter Improve'}
        </Button>

        {#if resendCooldown > 0}
          <p class="hint">Resend code in {resendCooldown}s</p>
        {:else}
          <button type="button" class="text-button resend-button" disabled={loading} onclick={resendCode}>
            Resend code
          </button>
        {/if}
      </form>
    {/if}

    {#if error}
      <p class="error" role="alert">{error}</p>
    {/if}
  </div>
</section>
