<script lang="ts">
  let { class: className = '', children } = $props()
</script>

<section class={`card ${className}`}>
  {@render children?.()}
</section>
