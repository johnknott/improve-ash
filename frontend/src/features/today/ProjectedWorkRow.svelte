<script lang="ts">
  import { ClipboardPlus } from '@lucide/svelte'
  import type { ProjectedWork } from '../../api/types'
  import { openLogDialog } from '../../app/appState'
  import Badge from '../../components/ui/Badge.svelte'

  let { work }: { work: ProjectedWork } = $props()

  let targetText = $derived(
    work.target.quantity
      ? `${work.target.quantity}${work.target.unit ? ` ${work.target.unit}` : ''}`
      : work.eventTypeName
        ? work.eventTypeName
        : work.kind === 'session'
          ? 'Session work'
          : 'Goal'
  )

  let tone = $derived(work.status === 'completed' ? 'good' : work.kind === 'session' ? 'info' : 'neutral')
</script>

<article class="work-row">
  <div class="work-row-main">
    <div class="work-row-title">
      <h3>{work.title}</h3>
      <Badge {tone}>{work.status}</Badge>
    </div>
    <p>{targetText}</p>
    {#if work.explanation}
      <small>{work.explanation}</small>
    {/if}
    {#if work.session?.recommendations.length}
      <div class="chip-list compact-chips">
        {#each work.session.recommendations as item}
          <span class="model-chip">{item.name}</span>
        {/each}
      </div>
    {/if}
  </div>
  <button class="secondary-button compact-button" type="button" disabled={!work.canLog} onclick={() => openLogDialog(work)}>
    <ClipboardPlus size={16} />
    <span>{work.status === 'completed' ? 'Done' : 'Log'}</span>
  </button>
</article>
