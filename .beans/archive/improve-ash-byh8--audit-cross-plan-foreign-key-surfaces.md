---
# improve-ash-byh8
title: Audit cross-plan foreign key surfaces
status: completed
type: task
priority: high
created_at: 2026-06-22T21:38:29Z
updated_at: 2026-06-22T21:44:09Z
parent: improve-ash-dcal
---

Map every action/helper that accepts plan_id plus another foreign ID. Acceptance: create a checklist of resources/actions that need same-plan validation, grouped by Plans, Sessions, and Journal.

## Work Checklist

- [x] Inspect plan definition resources and create/update actions.
- [x] Inspect session resources and workflow helpers.
- [x] Inspect journal resources and workflow helpers.
- [x] Identify same-plan validation gaps and existing protections.
- [x] Record grouped hardening checklist for follow-up beans.

## Existing Protections

The current policy pattern is consistent and useful: resources authorize reads and writes through the submitted row plan, generally with `expr(plan.user_id == ^actor(:id))`. Existing migrations also create normal foreign keys, so referenced records must exist.

The gap is same-plan integrity. A create can submit `plan_id` for one plan and a foreign ID from another plan. The policy only proves the actor can write to the submitted plan; normal single-column foreign keys only prove the referenced row exists. This is especially important for users who own multiple plans, and it also prevents accidental cross-user references if an ID leaks into a request.

Current tests cover cross-user ownership boundaries. They do not yet cover same-owner, two-plan mixed-ID writes.

## Hardening Checklist

### Plans

- `Improve.Plans.Item.create`: ensure `item_type_id` belongs to the submitted `plan_id`.
- `Improve.Plans.PoolMembership.create`: ensure both `pool_id` and `item_id` belong to the submitted `plan_id`.
- `Improve.Plans.Environment.create/update`: ensure every `available_item_ids` entry belongs to the environment plan. This field is an array, not a relationship, so it needs explicit validation or a future join table.
- `Improve.Plans.SessionTemplate.create/update`: ensure optional `environment_id` is nil or belongs to the same plan.
- `Improve.Plans.SessionSlot.create/update`: ensure `session_template_id` and `pool_id` both belong to the same plan as the slot.
- `Improve.Plans.DirectGoal.create/update`: ensure `event_type_id` belongs to the same plan as the goal.
- `Improve.Plans.Schedule.create/update`: ensure `owner_id` exists and belongs to the submitted plan, using `owner_type` to choose `SessionTemplate` or `DirectGoal`. This currently accepts arbitrary UUIDs.
- `Improve.Plans.EventType`: no direct foreign IDs, but `item_link_roles` and `effect_rules` reference authored roles/types by key. Keep this mostly in authored-content diagnostics unless later schemas introduce IDs.

### Sessions

- `Improve.Sessions.SessionOccurrence.create_projected`: ensure `session_template_id` belongs to the submitted `plan_id`.
- `Improve.Sessions.SlotResult.create`: ensure `session_occurrence_id`, `session_slot_id`, `recommended_item_id`, `actual_item_id`, and optional `event_instance_id` all belong to the submitted `plan_id`.
- `Improve.Sessions.SlotResult.complete/swap`: ensure accepted `actual_item_id` and `event_instance_id` belong to the existing slot result plan.
- `Improve.Sessions.start_projected_session!/2`: continue treating this as orchestration, but rely on resource-level validations so arbitrary projected structs cannot create cross-plan occurrences or slot results.

### Journal

- `Improve.Journal.EventInstance.log`: ensure `event_type_id`, optional `session_occurrence_id`, optional `slot_result_id`, optional `direct_goal_id`, and optional `replaces_event_instance_id` all belong to the submitted `plan_id`.
- `Improve.Journal.EventItemLink.create`: ensure `event_instance_id` and `item_id` both belong to the submitted `plan_id`.
- `Improve.Journal.ItemEffect.create`: ensure `item_id`, `event_instance_id`, and optional `replaces_item_effect_id` all belong to the submitted `plan_id`.
- `Improve.Journal.log_session_item_event!/2`: resource validations should protect against mismatched `slot_result`, `item`, `event_type`, and `session_occurrence` structs.
- `Improve.Journal.log_dose_event!/2` and `correct_dose_event!/2`: resource validations should protect against mismatched `plan`, `event_type`, `source_vial`, original event, and original effect structs until these move onto the generic event pathway.

## Follow-Up Guidance

Implement the hardening with focused negative tests first. The important test shape is one actor owning two plans, then trying to create rows on plan A with foreign IDs from plan B. Add cross-user mixed-ID cases where cheap, but same-owner mixed-plan tests are the missing coverage.

Before adding Ash validations or changes, check the installed Ash and AshPostgres docs for the current versions. Prefer resource-level checks for user-facing actions, and consider database reinforcement only where it is practical without fighting AshPostgres generated migrations.

## Summary of Changes

Audited the cross-plan foreign key surfaces across `Plans`, `Sessions`, and `Journal`, identified existing protections, and recorded the concrete validation checklist for the follow-up same-plan hardening beans.
