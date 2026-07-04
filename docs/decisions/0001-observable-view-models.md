# 0001 — View models use the Observation framework (`@Observable`)

- **Date:** 2026-07-04
- **Status:** Accepted

## Context

CLAUDE.md mandates the Observation framework, but the MVP flow shipped with
`ObservableObject`/`@Published` plus manual `objectWillChange.send()` calls — a drift
that would compound with every new screen. Only one view model
(`AppFlowViewModel`) existed at decision time, so migration cost was at its minimum.

## Decision

Migrate now. `AppFlowViewModel` (and every future view model) uses `@Observable`.
Views hold it as `@State` at the owning root, `@Bindable` where two-way bindings are
needed, and a plain property where read-only.

## Alternatives considered

- **Defer until after OCR capture ships** — rejected: capture work adds screens, so the
  migration only gets bigger.
- **Amend CLAUDE.md to permit `ObservableObject`** — rejected: Observation is the
  current framework; the manual `objectWillChange.send()` calls were already a bug smell.

## Consequences

Removes the Combine dependency from the view-model layer and the manual
change-notification calls. Future view models (one per screen, per CLAUDE.md) follow
the same pattern with no per-property annotations.

## Non-goals

Splitting the monolithic `AppFlowViewModel` into per-screen view models — separate work.
