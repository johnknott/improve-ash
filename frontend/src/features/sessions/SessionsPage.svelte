<script lang="ts">
  import type { DashboardData, Pool, ProjectedWork, SessionTemplate } from '../../api/types'
  import { selectedSessionWorkId } from '../../app/appState'
  import Badge from '../../components/ui/Badge.svelte'
  import Card from '../../components/ui/Card.svelte'
  import EmptyState from '../../components/ui/EmptyState.svelte'
  import JsonBlock from '../../components/ui/JsonBlock.svelte'
  import LoadingState from '../../components/ui/LoadingState.svelte'
  import { formatKey } from '../../lib/modelDisplay'
  import DemoPlanSetup from '../setup/DemoPlanSetup.svelte'
  import SessionDetail from './SessionDetail.svelte'

  let { data, loading }: { data: DashboardData | null; loading: boolean } = $props()

  let slots = $derived(data?.planDetail?.sessionSlots ?? [])
  let schedules = $derived(data?.planDetail?.schedules ?? [])
  let pools = $derived(data?.planDetail?.pools ?? [])
  let memberships = $derived(data?.planDetail?.poolMemberships ?? [])
  let items = $derived(data?.planDetail?.items ?? [])
  let selectedWork = $derived(findSelectedSession(data, $selectedSessionWorkId))

  function slotsForTemplate(template: SessionTemplate) {
    return slots
      .filter((slot) => slot.sessionTemplateId === template.id)
      .toSorted((a, b) => a.position - b.position)
  }

  function scheduleForTemplate(template: SessionTemplate) {
    return schedules.find((schedule) => schedule.ownerType === 'session_template' && schedule.ownerId === template.id)
  }

  function itemsForPool(pool: Pool) {
    const itemIds = memberships.filter((membership) => membership.poolId === pool.id).map((membership) => membership.itemId)
    return items.filter((item) => itemIds.includes(item.id))
  }

  function findSelectedSession(dashboard: DashboardData | null, selectedId: string | null): ProjectedWork | null {
    const sessions = dashboard?.today?.work.filter((work) => work.kind === 'session') ?? []

    if (selectedId) {
      return sessions.find((work) => work.id === selectedId) ?? null
    }

    return null
  }
</script>

{#if data && selectedWork}
  <SessionDetail {data} work={selectedWork} />
{:else}
<section class="page-stack">
  {#if loading}
    <LoadingState message="Loading sessions" />
  {:else if data?.planDetail}
    {#if data.planDetail.sessionTemplates.length}
      {#each data.planDetail.sessionTemplates as template (template.id)}
        <Card class="model-card">
          <div class="section-heading">
            <div>
              <p class="eyebrow">{template.key}</p>
              <h2>{template.name}</h2>
            </div>
            <Badge tone="info">session</Badge>
          </div>

          {#if template.description}
            <p class="body-copy">{template.description}</p>
          {/if}

          {@const schedule = scheduleForTemplate(template)}
          {#if schedule}
            <div class="mini-row schedule-row">
              <span>{formatKey(schedule.kind)}</span>
              <small>{schedule.startsOn}{schedule.endsOn ? ` to ${schedule.endsOn}` : ''}</small>
            </div>
          {/if}

          <div class="model-section">
            <h3>Slots</h3>
            <div class="model-list">
              {#each slotsForTemplate(template) as slot (slot.id)}
                <div class="session-slot-row">
                  <div>
                    <strong>{slot.name}</strong>
                    <small>{slot.poolName ?? 'Pool'} · {slot.count} pick{slot.count === 1 ? '' : 's'}</small>
                  </div>
                  {#if slot.optional}
                    <Badge tone="neutral">optional</Badge>
                  {/if}
                </div>
              {:else}
                <p class="muted">No slots authored for this template.</p>
              {/each}
            </div>
          </div>
        </Card>
      {/each}

      <Card class="list-card">
        <div class="section-heading">
          <div>
            <p class="eyebrow">Recommendation pools</p>
            <h2>Pools</h2>
          </div>
          <span>{pools.length}</span>
        </div>

        <div class="model-card-grid">
          {#each pools as pool (pool.id)}
            <div class="pool-card">
              <h3>{pool.name}</h3>
              {#if pool.description}
                <p>{pool.description}</p>
              {/if}
              <div class="chip-list">
                {#each itemsForPool(pool) as item (item.id)}
                  <span class="model-chip">{item.name}</span>
                {:else}
                  <span class="muted">No members</span>
                {/each}
              </div>
            </div>
          {/each}
        </div>
      </Card>
    {:else}
      <Card>
        <EmptyState title="No sessions" message="This plan does not define session templates." />
      </Card>
    {/if}
  {:else}
    <Card>
      <DemoPlanSetup title="Install a plan to inspect sessions" />
    </Card>
  {/if}
</section>
{/if}
