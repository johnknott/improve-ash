<script lang="ts">
  let { message = 'Loading' } = $props<{ message?: string }>()
</script>

<div class="loading-state">
  <div class="loading-dot"></div>
  <p>{message}</p>
</div>
