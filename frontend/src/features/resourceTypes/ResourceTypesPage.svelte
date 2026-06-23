<script lang="ts">
  import type { DashboardData } from '../../api/types'
  import Badge from '../../components/ui/Badge.svelte'
  import Card from '../../components/ui/Card.svelte'
  import EmptyState from '../../components/ui/EmptyState.svelte'
  import JsonBlock from '../../components/ui/JsonBlock.svelte'
  import LoadingState from '../../components/ui/LoadingState.svelte'
  import { formatKey, hasEntries, listField } from '../../lib/modelDisplay'
  import DemoPlanSetup from '../setup/DemoPlanSetup.svelte'

  let { data, loading }: { data: DashboardData | null; loading: boolean } = $props()
</script>

<section class="page-stack">
  {#if loading}
    <LoadingState message="Loading resource types" />
  {:else if data?.planDetail}
    {#if data.planDetail.itemTypes.length}
      <div class="model-card-grid">
        {#each data.planDetail.itemTypes as itemType (itemType.id)}
          <Card class="model-card">
            <div class="section-heading">
              <div>
                <p class="eyebrow">{itemType.key}</p>
                <h2>{itemType.name}</h2>
              </div>
              <Badge tone="neutral">{itemType.itemCount} items</Badge>
            </div>

            {#if itemType.description}
              <p class="body-copy">{itemType.description}</p>
            {/if}

            <div class="schema-row">
              <span>Required facts</span>
              <div class="chip-list">
                {#each listField(itemType.factsSchema, 'required') as field}
                  <span class="model-chip">{formatKey(field)}</span>
                {:else}
                  <span class="muted">None</span>
                {/each}
              </div>
            </div>

            <div class="schema-row">
              <span>Optional facts</span>
              <div class="chip-list">
                {#each listField(itemType.factsSchema, 'optional') as field}
                  <span class="model-chip">{formatKey(field)}</span>
                {:else}
                  <span class="muted">None</span>
                {/each}
              </div>
            </div>

            {#if hasEntries(itemType.displayHints)}
              <div class="model-section">
                <h3>Display hints</h3>
                <JsonBlock value={itemType.displayHints} />
              </div>
            {/if}
          </Card>
        {/each}
      </div>
    {:else}
      <Card>
        <EmptyState title="No resource types" message="This plan does not define tracked resource types yet." />
      </Card>
    {/if}
  {:else}
    <Card>
      <DemoPlanSetup title="Install a plan to inspect resource types" />
    </Card>
  {/if}
</section>
