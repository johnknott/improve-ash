<script lang="ts">
  import { CheckCircle2, Info, Link2, PencilLine } from '@lucide/svelte'
  import { Dialog } from 'bits-ui'
  import type {
    JournalEventDetail,
    JournalEventStatus,
    JournalItemEffect,
  } from '../../api/types'
  import { planDetail } from '../../app/dashboardState'
  import Badge from '../../components/ui/Badge.svelte'
  import Button from '../../components/ui/Button.svelte'
  import JsonBlock from '../../components/ui/JsonBlock.svelte'
  import { formatDateTime } from '../../lib/dates'
  import { focusDialogTarget, handleDialogOpenAutoFocus } from '../../lib/dialogFocus'
  import JournalCorrectionForm from './JournalCorrectionForm.svelte'

  let {
    event,
    onClose,
    onCorrected,
  }: {
    event: JournalEventDetail | null
    onClose: () => void
    onCorrected: () => void
  } = $props()

  let content = $state<HTMLElement | null>(null)
  let mode = $state<'details' | 'correction'>('details')
  let correctionBusy = $state(false)

  let eventType = $derived(
    event ? ($planDetail?.eventTypes.find((candidate) => candidate.id === event.eventTypeId) ?? null) : null,
  )

  $effect(() => {
    event?.id
    mode = 'details'
    correctionBusy = false
  })

  const tones: Record<JournalEventStatus, string> = {
    active: 'good',
    corrected: 'info',
    voided: 'warning',
    skipped: 'neutral',
  }

  function label(value: string): string {
    return value.replaceAll('_', ' ')
  }

  function hasValues(value: Record<string, unknown> | null): boolean {
    return Boolean(value && Object.keys(value).length > 0)
  }

  function effectQuantity(effect: JournalItemEffect): string | null {
    return effect.quantity == null
      ? null
      : `${effect.quantity}${effect.unit ? ` ${effect.unit}` : ''}`
  }

  function startCorrection() {
    mode = 'correction'
    focusDialogTarget(() => content, '[data-correction-first-focus]')
  }

  function cancelCorrection() {
    mode = 'details'
    focusDialogTarget(() => content, '[data-journal-fix-action]')
  }

  function correctionSaved() {
    onCorrected()
    onClose()
  }
</script>

<Dialog.Root
  open={event !== null}
  onOpenChange={(open) => !open && !correctionBusy && onClose()}
>
  <Dialog.Portal>
    <Dialog.Overlay class="dialog-overlay" />
    {#if event}
      <Dialog.Content
        bind:ref={content}
        class="dialog-content journal-detail-dialog"
        aria-busy={correctionBusy}
        onEscapeKeydown={(closeEvent) => correctionBusy && closeEvent.preventDefault()}
        onInteractOutside={(closeEvent) => correctionBusy && closeEvent.preventDefault()}
        onOpenAutoFocus={(focusEvent) => handleDialogOpenAutoFocus(focusEvent, () => content)}
      >
        <div class="dialog-header journal-detail-header">
          <div>
            <p class="eyebrow">{event.eventTypeName ?? 'Journal event'}</p>
            <Dialog.Title>{mode === 'correction' ? 'Fix this entry' : event.summary}</Dialog.Title>
            <Dialog.Description>
              {mode === 'correction'
                ? 'Change the recorded details and keep the original in your history.'
                : `Happened ${formatDateTime(event.effectiveAt)}`}
            </Dialog.Description>
          </div>
          <Dialog.Close
            class="icon-button"
            data-dialog-initial-focus
            aria-label={mode === 'correction' ? 'Close correction' : 'Close event details'}
            disabled={correctionBusy}
          >×</Dialog.Close>
        </div>

        <div class="journal-detail-body">
          {#if mode === 'correction'}
            <JournalCorrectionForm
              {event}
              {eventType}
              onCancel={cancelCorrection}
              onSaved={correctionSaved}
              onBusyChange={(busy) => (correctionBusy = busy)}
            />
          {:else}
          <div class="journal-detail-status">
            <Badge tone={tones[event.status]}>{label(event.status)}</Badge>
            {#if event.correction.eligible}
              <span class="journal-correction-available">
                <CheckCircle2 size={15} aria-hidden="true" />
                Correction available
              </span>
            {:else if event.correction.unavailableReason}
              <span class="journal-correction-unavailable">
                <Info size={15} aria-hidden="true" />
                {event.correction.unavailableReason}
              </span>
            {/if}
          </div>

          {#if event.correction.eligible}
            <div class="journal-detail-actions">
              <Button data-journal-fix-action onclick={startCorrection}>
                <PencilLine size={16} aria-hidden="true" />
                Fix this entry
              </Button>
            </div>
          {/if}

          <section class="journal-detail-section" aria-labelledby="journal-recorded-details">
            <h2 id="journal-recorded-details">Recorded details</h2>
            <dl class="journal-detail-list">
              <div><dt>Event type</dt><dd>{event.eventTypeName ?? event.eventTypeKey}</dd></div>
              {#if event.trackName}<div><dt>Track</dt><dd>{event.trackName}</dd></div>{/if}
              {#if event.quantity != null}
                <div>
                  <dt>Amount</dt>
                  <dd>{event.quantity}{event.unit ? ` ${event.unit}` : ''}</dd>
                </div>
              {/if}
              <div><dt>Happened</dt><dd><time datetime={event.effectiveAt}>{formatDateTime(event.effectiveAt)}</time></dd></div>
              <div><dt>Recorded</dt><dd><time datetime={event.recordedAt}>{formatDateTime(event.recordedAt)}</time></dd></div>
              <div><dt>Source</dt><dd>{label(event.origin)}</dd></div>
              {#if event.correctedAt}
                <div><dt>Corrected</dt><dd><time datetime={event.correctedAt}>{formatDateTime(event.correctedAt)}</time></dd></div>
              {/if}
              {#if event.voidedAt}
                <div><dt>Voided</dt><dd><time datetime={event.voidedAt}>{formatDateTime(event.voidedAt)}</time></dd></div>
              {/if}
            </dl>
            {#if event.note}<p class="journal-detail-note">{event.note}</p>{/if}
          </section>

          {#if hasValues(event.payload)}
            <section class="journal-detail-section" aria-labelledby="journal-event-payload">
              <h2 id="journal-event-payload">Event information</h2>
              <JsonBlock value={event.payload} />
            </section>
          {/if}

          {#if event.itemLinks.length > 0}
            <section class="journal-detail-section" aria-labelledby="journal-linked-items">
              <h2 id="journal-linked-items">Linked items</h2>
              <ul class="journal-detail-items">
                {#each event.itemLinks as link (link.id)}
                  <li>
                    <Link2 size={15} aria-hidden="true" />
                    <span><strong>{link.itemName ?? link.itemKey ?? 'Item'}</strong> · {label(link.role)}</span>
                  </li>
                {/each}
              </ul>
            </section>
          {/if}

          {#if event.itemEffects.length > 0}
            <section class="journal-detail-section" aria-labelledby="journal-state-changes">
              <h2 id="journal-state-changes">State changes</h2>
              <ul class="journal-effect-list">
                {#each event.itemEffects as effect (effect.id)}
                  <li>
                    <div class="journal-effect-heading">
                      <strong>{effect.itemName ?? effect.itemKey ?? 'Item'}</strong>
                      <Badge tone={effect.status === 'active' ? 'good' : 'neutral'}>{label(effect.status)}</Badge>
                    </div>
                    <p>
                      {label(effect.effectType)}{#if effectQuantity(effect)} · {effectQuantity(effect)}{/if}
                    </p>
                    {#if effect.voidedAt}
                      <small>Voided {formatDateTime(effect.voidedAt)}</small>
                    {/if}
                    {#if hasValues(effect.payload)}<JsonBlock value={effect.payload} />{/if}
                  </li>
                {/each}
              </ul>
            </section>
          {/if}

          {#if event.correction.replaces || event.correction.replacedBy.length > 0}
            <section class="journal-detail-section" aria-labelledby="journal-correction-history">
              <h2 id="journal-correction-history">Correction history</h2>
              {#if event.correction.replaces}
                <p>
                  This entry replaces “{event.correction.replaces.summary}” from
                  {formatDateTime(event.correction.replaces.effectiveAt)}.
                </p>
              {/if}
              {#if event.correction.replacedBy.length > 0}
                <ul class="journal-correction-list">
                  {#each event.correction.replacedBy as replacement (replacement.id)}
                    <li>
                      Replaced by “{replacement.summary}” from {formatDateTime(replacement.effectiveAt)}.
                    </li>
                  {/each}
                </ul>
              {/if}
            </section>
          {/if}

          {#if hasValues(event.targetSnapshot)}
            <details class="journal-target-snapshot">
              <summary>Recorded target snapshot</summary>
              <JsonBlock value={event.targetSnapshot} />
            </details>
          {/if}
          {/if}
        </div>
      </Dialog.Content>
    {/if}
  </Dialog.Portal>
</Dialog.Root>
