# 0002 — Active draft persists as Codable JSON in UserDefaults; SwiftData deferred to session history

- **Date:** 2026-07-04
- **Status:** Accepted

## Context

CLAUDE.md's tech-stack section said "Persistence: SwiftData", but the MVP persists
exactly one document — the active `SplitDraft` — as Codable JSON in UserDefaults
behind the `SessionRepository` protocol. SwiftData's value (queries, relationships,
migrations) buys nothing for a single working document, and the MVP explicitly
excludes expense history.

## Decision

Keep UserDefaults + Codable JSON for the active draft. Adopt SwiftData when (and only
when) session history ships post-MVP. The `SessionRepository` protocol is the seam:
a SwiftData-backed implementation replaces `UserDefaultsSessionRepository` without
touching view models.

## Alternatives considered

- **Migrate to SwiftData now** — rejected: pays modeling and migration cost for zero
  current benefit, during the week the camera/OCR path needs to be built.

## Consequences

CLAUDE.md's stack section is amended to describe this. New persisted fields on
`SplitDraft` must be optionals (or have decode defaults) so older saved drafts still
decode — see the review-lens "Codable evolution" check.

## Non-goals

The history feature itself, and any UserDefaults→SwiftData data migration (there is
nothing durable to migrate; the active draft is transient by design).
