# 0004 — `.settled` is set only when the flow completes

- **Date:** 2026-07-04
- **Status:** Accepted

## Context

`updateSessionStatus(for:)` marked the session `.settled` the moment the user
*entered* the Settlement screen, so a draft abandoned there read as settled. Harmless
today, but wrong the moment session history or a status badge exists.

## Decision

The settlement and share steps map to `.splittingItems`. `.settled` is written exactly
once, in `finishSharing()`, when the user completes the flow.

## Alternatives considered

- **Keep and document the current behavior** — rejected: the fix is a two-line change
  plus one test, cheaper than the confusion it prevents.

## Consequences

`SplitSessionStatus` values become trustworthy for any future history/badge feature.

## Non-goals

Adding new status cases (e.g. a dedicated `.settling`).
