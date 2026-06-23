<script lang="ts">
  import type { DashboardData } from '../../api/types'
  import Badge from '../../components/ui/Badge.svelte'
  import Card from '../../components/ui/Card.svelte'
  import EmptyState from '../../components/ui/EmptyState.svelte'
  import JsonBlock from '../../components/ui/JsonBlock.svelte'
  import LoadingState from '../../components/ui/LoadingState.svelte'
  import { formatKey, listField, roleList, ruleList } from '../../lib/modelDisplay'
  import DemoPlanSetup from '../setup/DemoPlanSetup.svelte'

  let { data, loading }: { data: DashboardData | null; loading: boolean } = $props()
</script>

<section class="page-stack">
  {#if loading}
    <LoadingState message="Loading event types" />
  {:else if data?.planDetail}
    {#if data.planDetail.eventTypes.length}
      {#each data.planDetail.eventTypes as eventType (eventType.id)}
        <Card class="model-card">
          <div class="section-heading">
            <div>
              <p class="eyebrow">{eventType.key}</p>
              <h2>{eventType.name}</h2>
            </div>
            <Badge tone="info">event</Badge>
          </div>

          {#if eventType.description}
            <p class="body-copy">{eventType.description}</p>
          {/if}

          <div class="model-grid">
            <div>
              <h3>Payload</h3>
              <div class="schema-row">
                <span>Required</span>
                <div class="chip-list">
                  {#each listField(eventType.payloadSchema, 'required') as field}
                    <span class="model-chip">{formatKey(field)}</span>
                  {:else}
                    <span class="muted">None</span>
                  {/each}
                </div>
              </div>
              <div class="schema-row">
                <span>Optional</span>
                <div class="chip-list">
                  {#each listField(eventType.payloadSchema, 'optional') as field}
                    <span class="model-chip">{formatKey(field)}</span>
                  {:else}
                    <span class="muted">None</span>
                  {/each}
                </div>
              </div>
            </div>

            <div>
              <h3>Item links</h3>
              <div class="model-list">
                {#each roleList(eventType.itemLinkRoles) as role}
                  <div class="mini-row">
                    <span>{role.role}</span>
                    <small>{role.itemTypeKey ?? 'any item'} {role.required ? 'required' : 'optional'}</small>
                  </div>
                {:else}
                  <p class="muted">No item links declared.</p>
                {/each}
              </div>
            </div>
          </div>

          <div class="model-section">
            <h3>Effect rules</h3>
            {#if ruleList(eventType.effectRules).length}
              <JsonBlock value={eventType.effectRules} />
            {:else}
              <p class="muted">No state effects for this event.</p>
            {/if}
          </div>
        </Card>
      {/each}
    {:else}
      <Card>
        <EmptyState title="No event types" message="This plan does not declare any loggable event shapes yet." />
      </Card>
    {/if}
  {:else}
    <Card>
      <DemoPlanSetup title="Install a plan to inspect event types" />
    </Card>
  {/if}
</section>
