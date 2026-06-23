<script lang="ts">
  import type { PlanItem } from '../../api/types'
  import Badge from '../../components/ui/Badge.svelte'

  let { item }: { item: PlanItem } = $props()
</script>

<article class="plan-item-row">
  <div>
    <h3>{item.name}</h3>
    <p>{item.key}</p>
  </div>
  <div class="row-actions">
    {#if item.stateful}
      <Badge tone="good">stateful</Badge>
    {/if}
    {#if item.archived}
      <Badge tone="warning">archived</Badge>
    {/if}
  </div>
</article>
