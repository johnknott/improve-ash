---
# improve-ash-1xm9
title: Model track skips in the journal
status: completed
type: feature
priority: normal
created_at: 2026-07-05T11:39:29Z
updated_at: 2026-07-05T11:47:56Z
parent: improve-ash-o39y
---

A skipped track day becomes an honest journal record: EventInstance with a skipped status (excluded from completion evaluators, which filter status == :active), carrying an optional reason. Domain: skip_track helper mirroring log_track; projector marks the track :skipped for that date with the reason in its context line. HTTP: POST /app/skip-track returning a [today, journal] patch. Controller test + check Ash/AshPostgres docs for the status-constraint migration pattern.

## Summary of Changes
Skips are honest journal records: EventInstance status gains :skipped (loggable statuses are :active/:skipped; voided/corrected stay transition-only). LogEventCommand carries status; EventContract skips payload/item-link validation for skips (they record a decision, not data); completion evaluators exclude them automatically (status == :active filter). Logging.skip_track!/App.skip_track! mirror log_track (track key, optional reason -> note, local-day effective time, idempotency). Projector: a skip event marks the track :skipped for that date with "Skipped X — reason." as the explanation; a real completion the same day wins over the skip. HTTP: POST /app/skip-track -> [today, journal] patch. Controller test covers skip-with-reason -> skipped status + journal note -> log-track override -> completed.

Bonus repo heal: ash_postgres.generate_migrations had been crashing since the drift work (proposals identity missing identity_wheres_to_sql) — fixed, reconciled the stale snapshots against reality (all DDL already existed via hand migrations), renamed the divergence index to Ash's expected name, and the migrations --check now passes for the first time since 2026-07-04.

309 tests green; TS contracts regenerated (status union includes "skipped").
