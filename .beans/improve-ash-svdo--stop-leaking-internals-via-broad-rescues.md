---
# improve-ash-svdo
title: Stop leaking internals via broad rescues
status: completed
type: bug
priority: normal
created_at: 2026-07-04T13:20:04Z
updated_at: 2026-07-04T13:35:03Z
parent: improve-ash-fd57
---

~10 catch-all rescue blocks in UiApi turn programming errors into client-visible 422s with raw exception text. Rescue only expected error types; let the rest 500 and log. (notes/fable-todo.md item #15)

## Summary of Changes

Every affected rescue already had a narrow clause for expected errors
(`ArgumentError`, `Ash.Error.Invalid`, `Ash.Error.Forbidden`, sometimes
`KeyError`) followed by a catch-all doing the identical thing — the catch-all
made the narrow clause dead and swallowed programming errors. Removed the
nine catch-all clauses and narrowed the two symbolic ones
(`:install_failed`/`:start_failed`) to the same expected-error lists.
Unexpected exceptions now propagate to a logged 500 instead of a 422 with
raw exception text. The intentional `ArgumentError` rescue around
`String.to_existing_atom` is unchanged. Full suite green, including the
malformed-payload negative tests.

Follow-up (already tracked): improve-ash-awdf (structured API errors) will
replace the remaining `Exception.message/1` strings with a proper error
envelope.
