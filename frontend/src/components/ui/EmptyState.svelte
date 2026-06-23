<script lang="ts">
  let { title, message } = $props<{ title: string; message: string }>()
</script>

<div class="empty-state">
  <h2>{title}</h2>
  <p>{message}</p>
</div>
