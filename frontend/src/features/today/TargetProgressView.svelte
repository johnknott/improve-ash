<script lang="ts">
  import type {
    ChecklistTargetProgress,
    TargetProvenance,
    WorkItemTargetProgress,
  } from '../../api/types'
  import Badge from '../../components/ui/Badge.svelte'

  let {
    progress,
    provenance = null,
  }: {
    progress: WorkItemTargetProgress
    provenance?: TargetProvenance | null
  } = $props()

  // The union has no discriminant field; narrow by each variant's
  // distinctive keys. Sessions send {} and render nothing.
  let hasProgress = $derived('completedEventCount' in progress)
  let checklist = $derived(
    'completedItems' in progress ? (progress as ChecklistTargetProgress) : null,
  )
  let label = $derived(hasProgress ? String(progress.label ?? '') : '')

  function plannedSummary(planned: TargetProvenance['planned']): string {
    const quantity = 'quantity' in planned ? planned.quantity : null
    const unit = 'unit' in planned ? planned.unit : null

    if (quantity == null) {
      return ''
    }

    return unit ? ` (planned: ${quantity} ${unit})` : ` (planned: ${quantity})`
  }
</script>

{#if hasProgress && label}
  <div class="target-progress">
    <p class="target-progress-label">{label}</p>

    {#if checklist}
      <ul class="checklist-chips">
        {#each checklist.requiredItems as itemKey (itemKey)}
          <li class:done={checklist.completedItems.includes(itemKey)}>
            {itemKey.replaceAll('_', ' ')}
          </li>
        {/each}
      </ul>
    {/if}

    {#if provenance?.adjusted}
      <div class="target-provenance">
        <Badge tone="info">Adjusted</Badge>
        <span>
          {provenance.reason ?? 'Target adjusted by an evaluator'}{plannedSummary(
            provenance.planned,
          )}
        </span>
      </div>
    {/if}
  </div>
{/if}
