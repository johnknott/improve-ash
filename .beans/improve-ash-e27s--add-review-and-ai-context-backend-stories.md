---
# improve-ash-e27s
title: Add review and AI-context backend stories
status: done
type: task
priority: normal
tags:
    - backend
    - ai
created_at: 2026-06-24T12:17:07Z
updated_at: 2026-06-24T13:16:24Z
parent: improve-ash-qtdm
blocked_by:
    - improve-ash-gbxn
---

## Context

Review should start as readable structured backend output, with AI context proving what an assistant could see without requiring AI to operate the product.

## Tasks

- [x] Add a review story that reads journal history and proposes structured changes deterministically.
- [x] Keep review output product-facing: observations, suggested changes, and reasons.
- [x] Update read-only AshAI/context helpers to use track/session/item/state vocabulary.
- [x] Add tests that AI context reads naturally and respects ownership boundaries.

## Acceptance

- [x] A review story can show useful plan improvement context without calling an LLM or writing product data.
