---
# improve-ash-h81d
title: Identify the first real evaluator dependency
status: completed
type: task
priority: normal
created_at: 2026-06-24T20:38:31Z
updated_at: 2026-06-24T23:23:38Z
parent: improve-ash-o1ro
blocked_by:
    - improve-ash-z91i
---

Do not build dependency graph machinery in the abstract. First identify a concrete evaluator that needs another evaluator output, such as adaptation consuming a derived metric.

Done when the dependency is described with real inputs, outputs, and why direct calculation inside the consumer would be wrong.



## Ready

Ready as the next design-only backend step after Layer 2 customization. The concrete dependency is marathon adaptation consuming a derived training-load metric. This should produce a short note, not runtime code.

## Checklist

- [x] Add a concrete evaluator-dependency note under notes/.
- [x] Confirm producer inputs exist in Plans.projection_input/2.
- [x] Map consumer outputs to the Layer 3 marathon scenarios.
- [x] Explain why inline load calculation inside adaptation would be wrong.
- [x] Spell out implications for 38rj and 44nx without implementing them.
- [x] Complete the bean with a summary.



## Summary of Changes

Added notes/derived-metric-and-adaptation-evaluators.md as the concrete evaluator dependency design for the adaptive marathon plan. The note identifies recent_load_km as the first derived-metric producer and marathon_adaptation as the consumer, using as_of_date for bounded 7-day load calculation. It specifies producer input/output, consumer input/output, life events as ordinary journal events, time-off windows as plan structure, and maps the consumer to the four Layer 3 marathon scenarios.

The note explains why adaptation must not inline training-load calculation: reuse by Review/AshAI, bounded declared inputs, visible ordering/caching, future sandboxing, isolated tests, and the existing hermeticity rule. It also spells out the minimal next steps for 38rj and 44nx: capability descriptors with provides/requires, then a two-node recent_load_metric -> marathon_adaptation graph with ordering and cached producer output.

No runtime code, migrations, or tests were added. Validation was by cross-checking the note against extension-points-plan.md, Plans.projection_input/2, and the Layer 3 block in 10_adaptive_marathon.exs.
