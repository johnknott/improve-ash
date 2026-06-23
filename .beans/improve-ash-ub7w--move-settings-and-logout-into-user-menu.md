---
# improve-ash-ub7w
title: Move settings and logout into user menu
status: completed
type: feature
priority: normal
created_at: 2026-06-23T18:29:21Z
updated_at: 2026-06-23T18:30:07Z
---

Tidy the bottom-left account area.\n\n- [x] Turn the user chip into a dropdown/select-style menu\n- [x] Move Settings into the menu\n- [x] Move Logout into the menu\n- [x] Keep navigation behavior intact\n- [x] Run frontend verification\n\n## Summary of Changes\n\nThe sidebar footer now has a single account dropdown using Bits UI DropdownMenu. Settings and Logout moved into that menu, and the separate footer buttons were removed.\n\nVerified with npm run check and npm run build.
