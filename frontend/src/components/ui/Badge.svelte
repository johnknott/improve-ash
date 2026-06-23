<script lang="ts">
  let { tone = 'neutral', children } = $props()
</script>

<span class={`badge badge-${tone}`}>
  {@render children?.()}
</span>
