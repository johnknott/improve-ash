---
# improve-ash-rkcw
title: Build vial inventory workflow UI
status: completed
type: feature
priority: normal
created_at: 2026-06-23T16:06:48Z
updated_at: 2026-06-23T16:16:01Z
---

Build the inventory/vial workflow after the app API cleanup.\n\n- [x] Show derived current vial quantity in Inventory\n- [x] Log a dose from Inventory using the app API\n- [x] Correct a dose by voiding/replacing the event and effect\n- [x] Surface item effects and dose history clearly\n- [x] Run frontend/backend verification\n\nInventory now uses derived item state from the app API and calls explicit log-dose/correct-dose commands.
