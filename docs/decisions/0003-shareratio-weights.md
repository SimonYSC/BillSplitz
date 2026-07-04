# 0003 — `ItemAssignment.shareRatio` is a positive weight, normalized by the calculator

- **Date:** 2026-07-04
- **Status:** Accepted

## Context

CLAUDE.md defined `shareRatio` as a fraction in [0, 1] with ratios per item summing
to 1. The shipped code stores weight `1` for every assignee and
`SettlementCalculator` normalizes weights per item. The documented invariant was
false, and the weight model is the better one: adding or removing an assignee needs
no re-normalization pass over sibling assignments.

## Decision

`shareRatio` is a positive `Decimal` weight (typically 1). Shares are
weight / (sum of weights for that item), computed inside `SettlementCalculator`.
There is no sums-to-1 invariant. CLAUDE.md's data-model rule is amended accordingly.

## Alternatives considered

- **Enforce normalized fractions in code to match the doc** — rejected: adds
  re-normalization logic to every assignment mutation site for no correctness gain.

## Consequences

Weighted (uneven) splits later are a UI problem only — the engine already supports
weights > 1. A rename to `shareWeight` would be more honest; deferred as an optional
mechanical pass since the type is persisted via Codable.

## Non-goals

Uneven-split UI, and the `shareWeight` rename itself.
