# Plan Draft Schema

Plan drafts are portable authored plan documents. They use stable keys instead
of database IDs so plans can be exported, edited, compared, shared, and imported
without leaking internal persistence details.

The current draft schema is defined in `Improve.Planning.PlanDraft`.

Top-level identity:

- `schema`: `"improve.plan_draft"`
- `version`: current integer schema version
- `key`
- `name`
- optional `intention`, `starts_on`, `ends_on`, `status`, `source`, and
  `display_hints`

Major collections:

- `item_types`
- `items`
- `pools`
- `environments`
- `event_types`
- `session_templates`
- `direct_goals`
- `schedules`
- `sample_events`

Reference fields use stable keys:

- items use `item_type_key`
- pools use `item_keys`
- environments use `available_item_keys`
- session templates use `environment_key`
- session slots use `pool_key`
- direct goals use `event_type_key`
- schedules use `owner_type` plus `owner_key`
- sample events use `event_type_key` and optionally `direct_goal_key`

Direct goals carry their first useful policy surface directly in the draft:

- `target`
- `completion_policy`
- `missed_policy`

Schedules currently support:

- `every_day`
- `selected_weekdays`
- `times_per_week`

Future draft import/export work should treat `PlanDraft.schema/0` as the source
of truth for section names, stable references, supported owner types, and the
first useful policy fields.
