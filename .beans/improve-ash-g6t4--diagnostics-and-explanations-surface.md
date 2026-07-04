---
# improve-ash-g6t4
title: Diagnostics and explanations surface
status: completed
type: feature
priority: normal
created_at: 2026-07-04T22:29:07Z
updated_at: 2026-07-04T22:48:41Z
parent: improve-ash-0m50
blocked_by:
    - improve-ash-hmnn
---

Render today.diagnostics as actionable plain-English warnings on the Today page ('unknown target type on Track X'), with severity styling and a link toward the Plan/authoring route (placeholder page for now — the link target exists, the editor arrives in Phase 4). Render today.explanations (string[]) as the quiet 'why this projection looks like this' block. This is what makes the studio self-correcting per the roadmap — authoring problems must be visible where they bite.

## Summary of Changes

TodayPage renders today.diagnostics as severity-styled rows (error/warning/info soft backgrounds) with a "Review plan setup" text button navigating to the plan route, and today.explanations as a quiet <details> block ("Why today looks like this"). Verified visually for explanations (vial plan rest day shows the projector's no-work explanation); diagnostics verified against types only — demo plans are well-formed, so no diagnostic renders until malformed authored content exists.
