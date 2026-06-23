---
# improve-ash-87xs
title: Move app UI API out of Phoenix controller
status: completed
type: feature
priority: normal
created_at: 2026-06-23T16:06:41Z
updated_at: 2026-06-23T16:16:01Z
---

Move the product-shaped UI API out of Phoenix and into Improve.App.UiApi.\n\n- [x] Extract dashboard and command orchestration from AppController into an Improve.App module\n- [x] Keep Phoenix controller thin: auth, params, status mapping, json\n- [x] Preserve current dashboard/session/journal behavior and tests\n- [x] Run frontend/backend verification\n\nImplemented in lib/improve/app/ui_api.ex with ImproveWeb.AppController reduced to a thin adapter.
