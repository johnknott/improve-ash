<script lang="ts">
  import { Pencil, PlusCircle } from '@lucide/svelte'
  import type { DashboardData, ItemType, JournalEntry, PlanItem } from '../../api/types'
  import { openDoseDialog } from '../../app/appState'
  import Badge from '../../components/ui/Badge.svelte'
  import Card from '../../components/ui/Card.svelte'
  import EmptyState from '../../components/ui/EmptyState.svelte'
  import JsonBlock from '../../components/ui/JsonBlock.svelte'
  import LoadingState from '../../components/ui/LoadingState.svelte'
  import { formatDateTime } from '../../lib/dates'
  import DemoPlanSetup from '../setup/DemoPlanSetup.svelte'

  let { data, loading }: { data: DashboardData | null; loading: boolean } = $props()

  let itemTypes = $derived(data?.planDetail?.itemTypes ?? [])
  let items = $derived(data?.planDetail?.items ?? [])

  function itemsForType(itemType: ItemType): PlanItem[] {
    return items.filter((item) => item.typeId === itemType.id)
  }

  function doseHistoryFor(item: PlanItem): JournalEntry[] {
    return (data?.journal ?? []).filter((entry) =>
      entry.itemLinks.some((link) => link.itemId === item.id && link.role === 'source_vial')
    )
  }

  function canLogDose(item: PlanItem): boolean {
    return item.stateful && (data?.planDetail?.eventTypes ?? []).some((eventType) => eventType.key === 'take_dose')
  }

  function currentQuantity(item: PlanItem): string | null {
    const quantity = stateValue(item.state?.calculatedState.current_quantity)
    const unit = stateValue(item.state?.calculatedState.unit)

    if (!quantity) {
      return null
    }

    return unit ? `${quantity} ${unit}` : quantity
  }

  function stateValue(value: unknown): string | null {
    if (typeof value === 'string') {
      return value
    }

    if (typeof value === 'number') {
      return String(value)
    }

    return null
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
                  {#if currentQuantity(item)}
                    <strong class="inventory-quantity">{currentQuantity(item)}</strong>
                  {/if}
                </div>
                <div class="row-actions">
                  {#if item.stateful}
                    <Badge tone="good">stateful</Badge>
                  {/if}
                  {#if item.archived}
                    <Badge tone="warning">archived</Badge>
                  {/if}
                  {#if canLogDose(item)}
                    <button class="secondary-button compact-button" type="button" onclick={() => openDoseDialog(item)}>
                      <PlusCircle size={16} />
                      <span>Log dose</span>
                    </button>
                  {/if}
                </div>
                <div class="inventory-detail">
                  <JsonBlock value={item.facts} />

                  {#if item.state?.activeEffects.length}
                    <div class="inventory-subsection">
                      <p class="muted">Active effects</p>
                      <div class="chip-list compact-chips">
                        {#each item.state.activeEffects as effect (effect.id)}
                          <span class="model-chip">
                            {effect.effectType}
                            {#if effect.quantity}
                              {effect.quantity}{effect.unit ? ` ${effect.unit}` : ''}
                            {/if}
                          </span>
                        {/each}
                      </div>
                    </div>
                  {/if}

                  {#if doseHistoryFor(item).length}
                    <div class="inventory-subsection">
                      <p class="muted">Dose history</p>
                      <div class="inventory-history">
                        {#each doseHistoryFor(item) as entry (entry.id)}
                          <div class="mini-row">
                            <div>
                              <strong>{entry.quantity}{entry.unit ? ` ${entry.unit}` : ''}</strong>
                              <small>{formatDateTime(entry.effectiveAt)} · {entry.status}</small>
                            </div>
                            {#if entry.status === 'active'}
                              <button
                                class="secondary-button compact-button"
                                type="button"
                                onclick={() => openDoseDialog(item, entry)}
                              >
                                <Pencil size={15} />
                                <span>Correct</span>
                              </button>
                            {/if}
                          </div>
                        {/each}
                      </div>
                    </div>
                  {/if}

                  {#if item.state?.warnings.length}
                    <div class="inventory-subsection">
                      {#each item.state.warnings as warning}
                        <p class="error inline-error">{warning}</p>
                      {/each}
                    </div>
                  {/if}
                </div>
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
