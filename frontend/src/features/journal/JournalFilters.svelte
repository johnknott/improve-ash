<script lang="ts">
  import { RotateCcw, Search } from '@lucide/svelte'
  import type {
    JournalEventStatus,
    JournalFilters,
    JournalPageData,
  } from '../../api/types'
  import Button from '../../components/ui/Button.svelte'
  import Select from '../../components/ui/Select.svelte'

  let {
    filters,
    options,
    busy = false,
    dirty = false,
    onChange,
    onApply,
    onClear,
  }: {
    filters: JournalFilters
    options: JournalPageData['filterOptions']
    busy?: boolean
    dirty?: boolean
    onChange: (filters: JournalFilters) => void
    onApply: () => void
    onClear: () => void
  } = $props()

  function update<K extends keyof JournalFilters>(key: K, value: JournalFilters[K]) {
    onChange({ ...filters, [key]: value })
  }
</script>

<form
  class="journal-filters"
  aria-label="Filter journal"
  onsubmit={(event) => {
    event.preventDefault()
    onApply()
  }}
>
  <div class="journal-filter-grid">
    <label class="field">
      <span class="field-label">Status</span>
      <Select
        value={filters.status ?? ''}
        disabled={busy}
        onchange={(event) =>
          update('status', (event.currentTarget.value || null) as JournalEventStatus | null)}
      >
        <option value="">All statuses</option>
        {#each options.statuses as option (option.value)}
          <option value={option.value}>{option.label}</option>
        {/each}
      </Select>
    </label>

    <label class="field">
      <span class="field-label">Event type</span>
      <Select
        value={filters.eventTypeId ?? ''}
        disabled={busy}
        onchange={(event) => update('eventTypeId', event.currentTarget.value || null)}
      >
        <option value="">All event types</option>
        {#each options.eventTypes as option (option.id)}
          <option value={option.id}>{option.name}</option>
        {/each}
      </Select>
    </label>

    <label class="field">
      <span class="field-label">Track</span>
      <Select
        value={filters.trackId ?? ''}
        disabled={busy}
        onchange={(event) => update('trackId', event.currentTarget.value || null)}
      >
        <option value="">All tracks</option>
        {#each options.tracks as option (option.id)}
          <option value={option.id}>{option.name}</option>
        {/each}
      </Select>
    </label>

    <label class="field">
      <span class="field-label">Item</span>
      <Select
        value={filters.itemId ?? ''}
        disabled={busy}
        onchange={(event) => update('itemId', event.currentTarget.value || null)}
      >
        <option value="">All items</option>
        {#each options.items as option (option.id)}
          <option value={option.id}>{option.name}</option>
        {/each}
      </Select>
    </label>
  </div>

  <div class="journal-filter-actions">
    <Button variant="secondary" disabled={busy} onclick={onClear}>
      <RotateCcw size={16} aria-hidden="true" />
      Clear
    </Button>
    <Button type="submit" disabled={busy || !dirty}>
      <Search size={16} aria-hidden="true" />
      {busy ? 'Applying…' : 'Apply filters'}
    </Button>
  </div>
</form>
