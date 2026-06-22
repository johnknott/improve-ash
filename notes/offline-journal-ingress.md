# Offline Journal Ingress

This note describes the minimal offline logging shape for the headless product
kernel. It is guided by `notes/full-rewrite-spec.md`, especially "Offline Event
Logging", and by the `EventInstance` model in `notes/spike-spec.md`.

The goal is resilient event capture, not full local-first sync. A client should
be able to record journal events while disconnected, submit them later, retry
submissions safely, and receive clear per-entry results. The server remains the
authority for validation, canonical records, and generated item effects.

## Scope

In scope:

- journal event logs created while online or offline
- client-generated operation identity
- idempotent retries
- original effective and recorded timestamps
- optional links to sessions, slots, direct goals, and items
- batch submission of a local pending-event outbox
- per-command acceptance, rejection, duplicate, and resolution-needed results

Out of scope for this spike:

- offline plan editing
- full local-first sync
- conflict-free replicated data types
- client-side effect generation as source of truth
- automatic medical, dose, supplement, or treatment advice

## Client Command Shape

Each pending journal operation should have a stable client identity. A later
server API can expose this directly or map it into a typed Ash action.

Required fields:

- `client_operation_id`: stable ID for this attempted write on the client.
- `idempotency_key`: stable retry key for the same logical write.
- `client_device_id`: stable ID for the device or app installation.
- `plan_id`: server plan ID when known.
- `event_type_id`: server event type ID when known.
- `effective_at`: when the logged thing happened.
- `recorded_at`: when the client recorded the pending log.
- `origin`: `offline_sync` for logs received from the pending outbox.

Optional fields:

- `client_event_id`: client-side provisional journal event ID.
- `plan_version_token`: opaque client snapshot marker, if available later.
- `session_occurrence_id`: if the log belongs to a session occurrence.
- `slot_result_id`: if the log satisfies or replaces a projected slot result.
- `direct_goal_id`: if the log satisfies a direct goal.
- `item_links`: item references plus roles, matching event type role rules.
- `summary`, `quantity`, `unit`, `payload`, and `note`.

The server should also stamp `received_at` or use its canonical inserted
timestamp. `recorded_at` remains the client's original recorded time; it should
not be overwritten with the receive time.

## Server Processing

For each operation in a batch, the server should:

1. Authenticate the actor and load the target plan.
2. Check idempotency for the actor, device, and idempotency key.
3. If already processed, return the original accepted or rejected result.
4. Validate that every referenced record exists and belongs to the same plan.
5. Validate event type roles, payload shape, and required links.
6. Interpret effect rules on the server from the canonical event type.
7. Persist the event, item links, item effects, and idempotency metadata in one
   transaction for that operation.
8. Return a per-operation result that the client can use to clear, keep, or
   mark the pending log for user attention.

Batch processing should not require all operations to succeed together. One bad
pending log should not roll back independent accepted logs. If commands depend
on each other, the client should submit them in dependency order and preserve
the failed dependent commands until the user or client resolves them.

## Idempotency Persistence

The next implementation pass can use fields on `EventInstance` if that stays
simple:

- `client_operation_id`
- `client_event_id`
- `client_device_id`
- `idempotency_key`

The key invariant is uniqueness for the authenticated owner and logical retry
key. A duplicate retry must not create a second event or second item effect.

If rejected operations also need stable duplicate responses, add a separate
operation receipt table later. For the first server shape, it is acceptable for
accepted events to carry the metadata and for rejected batch responses to be
recomputed deterministically from current validation where practical.

## Batch Result Shape

A batch response should include one result per submitted operation, preserving
input order.

Result statuses:

- `accepted`: a canonical event was created.
- `duplicate`: the operation was already accepted; the existing event is
  returned.
- `rejected`: the operation cannot be applied as submitted.
- `needs_resolution`: the operation references stale or ambiguous plan data and
  needs client or user intervention.

Useful result fields:

- `client_operation_id`
- `idempotency_key`
- `status`
- `event_instance_id`
- `diagnostics`
- `conflict_category`
- `server_recorded_at` or `received_at`

## Conflict Categories

Use stable categories so clients and tests do not need to parse prose.

- `duplicate_operation`: retry of an already accepted operation.
- `missing_plan_record`: referenced session, slot, goal, item, or event type no
  longer exists or is not visible to the actor.
- `archived_plan_record`: referenced authored content exists but is archived or
  inactive for new logs.
- `cross_plan_reference`: a referenced record belongs to another plan.
- `stale_session_state`: the referenced session occurrence or slot result has
  changed in a way that makes the log unsafe to apply automatically.
- `voided_correction_target`: the operation tries to correct or replace an
  event that is already voided or superseded.
- `invalid_payload`: event type requirements, item link roles, quantities, or
  units do not validate.
- `server_error`: unexpected failure after validation began.

`rejected` is appropriate for invalid or unauthorized data. `needs_resolution`
is appropriate when the client may be able to re-map the pending log to newer
plan data or ask the user what they intended.

Current spike behavior:

- Missing plans, event types, sessions, slots, direct goals, or linked items
  return `needs_resolution` with `missing_plan_record`.
- References to another plan return `needs_resolution` with
  `cross_plan_reference`.
- Archived plans or linked items return `needs_resolution` with
  `archived_plan_record`.
- Session occurrences that are already completed, missed, or skipped return
  `needs_resolution` with `stale_session_state`.
- Slot results that are already linked to another event, already completed, or
  no longer belong to the submitted session return `needs_resolution` with
  `stale_session_state`.
- Event types and direct goals do not yet have archive fields in this spike. If
  those fields are added, offline ingress should classify archived references as
  `archived_plan_record`.

## Timestamp Semantics

`effective_at` is when the thing happened. This drives timeline ordering and
state derivation.

`recorded_at` is when the client captured the log. This preserves the user's
original logging context, especially when they were offline.

`received_at` is when the server accepted or examined the operation. It is
useful for sync debugging and audit trails, but it should not replace either
`effective_at` or `recorded_at`.

If a client clock looks wrong, the server should accept or reject according to
explicit validation rules and return diagnostics. It should not silently rewrite
the user's effective timestamp.

## Relationship To Existing Commands

The generic journal logging command remains the canonical write path. Offline
ingress should normalize each pending operation into that command shape rather
than creating a second event-writing pathway.

That means dose logs, workout logs, direct goal logs, and future custom event
types should all flow through the same validation, item-link, effect-rule, and
correction semantics.

## Next Implementation Targets

The immediate Beans after this note are:

- add persisted idempotency metadata and uniqueness checks for accepted journal
  events
- add a batch ingress result model that can return mixed per-command outcomes
- define and test stale-reference handling for missing, archived, or changed
  plan records
