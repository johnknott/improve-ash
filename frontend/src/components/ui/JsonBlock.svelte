<script lang="ts">
  let { value }: { value: unknown } = $props()

  let text = $derived(JSON.stringify(value ?? {}, null, 2))
</script>

<pre class="json-block">{text}</pre>
