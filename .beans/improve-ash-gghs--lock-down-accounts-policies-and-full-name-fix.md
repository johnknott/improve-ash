---
# improve-ash-gghs
title: 'Lock down Accounts: policies and full_name fix'
status: completed
type: bug
priority: normal
created_at: 2026-07-04T13:20:04Z
updated_at: 2026-07-04T13:27:08Z
parent: improve-ash-fd57
---

Add Ash policies to User/Token (self-only read/update, no open list_users), bypass for AshAuthentication interactions, and fix the full_name resource/DB nullability mismatch. (notes/fable-todo.md item #5)

## Summary of Changes

- Added `Ash.Policy.Authorizer` to `Improve.Accounts.User`: AshAuthentication
  interactions bypass, create open (signup path), read/update/destroy
  self-only. `list_users`/`get_user_by_email` no longer expose other users;
  actor-less reads are forbidden.
- Added `Ash.Policy.Authorizer` to `Improve.Accounts.Token`: AshAuthentication
  bypass, everything else forbidden. Logout token revocation still works via
  the bypass.
- System-level lookups (`Stories.user!`, web test helpers) now pass
  `authorize?: false` explicitly.
- New test `test/improve/accounts_policy_test.exs` covering cross-user read
  and write isolation, actor-less forbiddance, self access, and token
  lockdown.
- **full_name finding was a false positive**: the audit misread the `down`
  clause of migration 20260623111144 — the `up` makes `full_name` nullable,
  matching the resource. No fix needed; corrected notes/fable-todo.md.
