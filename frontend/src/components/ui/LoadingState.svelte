<script lang="ts">
  let { message = 'Loading' } = $props<{ message?: string }>()
</script>

<div
  class="loading-state"
  role="status"
  aria-live="polite"
  aria-atomic="true"
>
  <p>{message}</p>
  <div class="loading-skeleton" aria-hidden="true">
    <div class="loading-skeleton-row">
      <span class="loading-skeleton-icon"></span>
      <span class="loading-skeleton-copy">
        <span class="loading-skeleton-line loading-skeleton-line-short"></span>
        <span class="loading-skeleton-line"></span>
      </span>
    </div>
    <div class="loading-skeleton-row">
      <span class="loading-skeleton-icon"></span>
      <span class="loading-skeleton-copy">
        <span class="loading-skeleton-line loading-skeleton-line-medium"></span>
        <span class="loading-skeleton-line"></span>
      </span>
    </div>
  </div>
</div>
