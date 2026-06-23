<script lang="ts">
  import { onMount } from 'svelte'
  import LoginPage from './features/auth/LoginPage.svelte'
  import { authState, loadCurrentUser, logoutCurrentUser } from './features/auth/authStore'

  onMount(() => {
    loadCurrentUser()
  })
</script>

{#if $authState.loading}
  <main class="loading-shell">
    <p>Loading Improve</p>
  </main>
{:else if !$authState.user}
  <LoginPage />
{:else}
  <main class="app-shell">
    <header>
      <div>
        <p class="eyebrow">Improve</p>
        <h1>Today</h1>
      </div>

      <div class="account">
        <span>{$authState.user.email}</span>
        <button type="button" onclick={logoutCurrentUser}>Log out</button>
      </div>
    </header>

    <section class="today-panel">
      <h2>Ready for the first real screen</h2>
      <p>
        Auth is live. The next pass can hang the Today projection and story-backed flows here.
      </p>
    </section>
  </main>
{/if}
