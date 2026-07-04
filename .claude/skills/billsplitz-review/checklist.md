# BillSplitz review lenses

Each lens: what to check, and the incident in this repo that created it.

## 1. Locale round-trips

Any `NumberFormatter` (or `Date`/number parsing) must be either display-only or pinned
to an explicit locale. Any format→parse round-trip must use one canonical locale on
both sides. Grep the diff for `NumberFormatter`, `Decimal(string:`, `String(format:`.

*Incident:* `editableString(for:)` used the device locale while `decimal(from:)`
assumed dot-decimal — on comma-decimal locales the tax/tip edit fields silently
multiplied values by 100.

## 2. Decimal discipline

No `Double` or `Float` anywhere near money — including test constants, JSON fixture
values (use integer cents), and intermediate arithmetic. `Decimal` literals must come
from `Decimal(string:)` or integer math, never floating-point literals.

*Incident:* standing CLAUDE.md rule; fixtures encode cents as integers for this reason.

## 3. Rounding reconciliation

Every allocation must sum exactly to its source total after rounding. Remainder
distribution must be deterministic and input-order-independent. If the diff touches
`SettlementCalculator`, the invariant tests (`SettlementInvariantTests`) must still
pass unmodified — weakening an invariant to make a diff green is itself a blocking finding.

*Incident:* remainder-cent tie-breaking depended on participant input order.

## 4. Data loss on navigation

Any code that rebuilds state (re-parse, re-fetch, reset) must preserve user edits, or
be gated on the source actually changing. Explicitly trace the back-then-forward path
for any flow-step change: what happens to items, assignments, and edited totals?

*Incident:* advancing from Receipt Capture unconditionally re-parsed, silently wiping
assignments and manual edits; the fix itself then had a trim mismatch (lens 7).

## 5. Codable evolution

New fields on persisted types (`SplitDraft` and everything it contains) must be
optional or have decode defaults, so drafts saved by older builds still decode.
Renaming or retyping a persisted field is a blocking finding unless a migration story
is stated.

*Incident:* `parsedReceiptText` was added as `String?` specifically so existing saved
drafts survive.

## 6. Doc/code drift

Does this diff make any claim in CLAUDE.md, the MVP spec, or `docs/decisions/` false?
Stale docs actively mislead future sessions. The fix belongs in the same diff.

*Incidents:* CLAUDE.md's test command named a simulator that didn't exist; the
`shareRatio` rule described semantics the code never had.

## 7. String comparison semantics

Any new string equality/matching must state its trimming and casing rule, and both
sides must apply it. Look for one side trimmed and the other raw.

*Incident:* the re-parse guard stored untrimmed text but compared trimmed — a trailing
newline in pasted receipts would have silently re-enabled the lens-4 data loss.
