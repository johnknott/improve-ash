# Projection Output Shape

This spike now treats projected work as a typed list instead of only a list of
projected session occurrences.

`project_today` still returns `projected_session_occurrences` for compatibility
with the existing session-start workflow. It also returns `projected_work`, where
each entry has:

- `kind`: `:session` or `:direct_goal`
- `status`: `:planned`, `:completed`, `:missed`, `:skipped`, or
  `:partially_completed`
- `planned_for`: the date this work belongs to
- `owner_type` and `owner_id`: the authored definition that produced the work
- `title`: a display-friendly name
- `payload`: kind-specific projected data
- `explanation`: a plain-English reason this work appeared

Session work stores the existing projected session occurrence in
`payload.session_occurrence` and exposes its slot recommendations in
`payload.recommendations`.

Direct goal work stores the direct goal identity, target, completion policy,
missed policy, event type, and completed event IDs under `payload`. Direct goal
projection is intentionally not implemented by this note; it gives the next
projection Beans a stable output contract to fill.

Projection remains pure: it calculates and explains, and it must not create
session occurrences, direct goal history, or journal events.
