<script lang="ts">
  import type { DashboardData, ItemType, PlanItem } from '../../api/types'
  import Badge from '../../components/ui/Badge.svelte'
  import Card from '../../components/ui/Card.svelte'
  import EmptyState from '../../components/ui/EmptyState.svelte'
  import JsonBlock from '../../components/ui/JsonBlock.svelte'
  import LoadingState from '../../components/ui/LoadingState.svelte'
  import DemoPlanSetup from '../setup/DemoPlanSetup.svelte'

  let { data, loading }: { data: DashboardData | null; loading: boolean } = $props()

  let itemTypes = $derived(data?.planDetail?.itemTypes ?? [])
  let items = $derived(data?.planDetail?.items ?? [])

  function itemsForType(itemType: ItemType): PlanItem[] {
    return items.filter((item) => item.typeId === itemType.id)
  }
</script>

<section class="page-stack">
  {#if loading}
    <LoadingState message="Loading inventory" />
  {:else if data?.planDetail}
    {#if items.length}
      {#each itemTypes as itemType (itemType.id)}
        <Card class="list-card">
          <div class="section-heading">
            <div>
              <p class="eyebrow">{itemType.key}</p>
              <h2>{itemType.name}</h2>
            </div>
            <span>{itemsForType(itemType).length}</span>
          </div>

          <div class="plan-item-list">
            {#each itemsForType(itemType) as item (item.id)}
              <article class="inventory-row">
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
                <JsonBlock value={item.facts} />
              </article>
            {:else}
              <EmptyState title="No items" message="No items of this type are authored in the current plan." />
            {/each}
          </div>
        </Card>
      {/each}
    {:else}
      <Card>
        <EmptyState title="No inventory" message="This plan has no authored items yet." />
      </Card>
    {/if}
  {:else}
    <Card>
      <DemoPlanSetup title="Install a plan to inspect inventory" />
    </Card>
  {/if}
</section>
