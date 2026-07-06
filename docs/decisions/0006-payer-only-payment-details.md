# 0006 — Payment details live on the payer only

- **Date:** 2026-07-06
- **Status:** Accepted

## Context

V1 stored `paymentMethodType` and `paymentHandle` on every `Participant`, and the
share summary printed a handle per person. The design exploration (user flow v2 §1)
found this wrong for the product: exactly one person — the payer — needs to receive
money, so only their details matter. Collecting handles for everyone is friction with
no payoff. `Participant.displayColor` was also write-only in the codebase, and the
"Tab" design system renders people as ink/accent initials with no per-person color.

## Decision

`Participant` carries a name only. The draft gains `payerPaymentMethod:
PaymentMethodType?` and `payerPaymentHandle: String?` alongside the existing
`payerID`. Session Setup collects them in a dedicated Payer section; the share
summary prints one `PAY {PAYER} VIA {METHOD}` line (plus the handle when present)
and no per-person handles. `displayColor` is removed in the same change.

## Alternatives considered

- **A `Payer` struct** — rejected: it duplicates identity already held by `payerID`;
  two optional fields on the draft are the smaller change with identical semantics.
- **Keep per-participant fields, hide the UI** — rejected: dead model weight and a
  standing doc/code drift (review lens 6).

## Consequences

Removing Codable fields is decode-safe for old drafts (unknown keys are ignored);
the new payer fields are optionals, so v1 drafts decode with them nil. Pinned by a
compatibility test that decodes a v1-shaped JSON fixture.

## Non-goals

Payment-app deep links or request APIs (out of scope per CLAUDE.md); multiple payers.
