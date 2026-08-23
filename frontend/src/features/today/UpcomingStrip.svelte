<script lang="ts">
  import type { WorkItem } from '../../api/types'
  import { formatDate } from '../../lib/dates'

  let { upcoming }: { upcoming: WorkItem[] } = $props()

  let days = $derived(
    Object.entries(
      upcoming.reduce<Record<string, WorkItem[]>>((grouped, item) => {
        ;(grouped[item.plannedFor] ??= []).push(item)
        return grouped
      }, {}),
    ).sort(([a], [b]) => a.localeCompare(b)),
  )
</script>

{#if days.length > 0}
  <section class="upcoming-strip" aria-label="Upcoming work">
    <h2 class="upcoming-title">Coming up</h2>
    <div class="upcoming-days">
      {#each days as [date, items] (date)}
        <div class="upcoming-day">
          <time class="upcoming-date" datetime={date}>{formatDate(date)}</time>
          <ul>
            {#each items as item (item.id)}
              <li>{item.title}</li>
            {/each}
          </ul>
        </div>
      {/each}
    </div>
  </section>
{/if}
