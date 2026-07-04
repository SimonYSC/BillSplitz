# 0005 — OCR primitive: spike `RecognizeDocumentsRequest` vs `VNRecognizeTextRequest` before building ReceiptOCRService

- **Date:** 2026-07-04
- **Status:** Pending (decision is the spike; the winner gets recorded here)

## Context

CLAUDE.md specifies Vision's `VNRecognizeTextRequest`, which returns flat text
observations; on two-column receipts the item name and price can arrive as separate
observations, pushing row-pairing complexity into our parser. iOS 26 added
`RecognizeDocumentsRequest`
(<https://developer.apple.com/documentation/vision/recognizedocumentsrequest>), which
returns document structure — tables, rows, lists — and Apple's WWDC25 session 272
(<https://developer.apple.com/videos/play/wwdc2025/272/>) demonstrates it on receipt
rows. BillSplitz targets iOS 26.1, so the newer API is available everywhere the app runs.

## Decision

Run a one-day on-device spike before any `ReceiptOCRService` work: both APIs against
the same 5 real photographed receipts (mix of restaurant styles, at least one
two-column and one crumpled). Compare: row integrity (name paired with price), item
recall, tax/tip line fidelity, garbage rate. Record the winner by amending this
record's Status to Accepted with the results table; amend CLAUDE.md's OCR line to match.

The spike's raw outputs become the first entries in the golden receipt corpus
(`BillSplitzTests/Fixtures/receipts/`), so the fixture input shape matches the chosen API.

## Alternatives considered

- **Commit to `RecognizeDocumentsRequest` without a spike** — rejected: likely winner,
  but untested on our receipt distribution, and the corpus shape depends on the answer.
- **Stay on `VNRecognizeTextRequest`** — rejected as a default: proven, but chooses the
  harder parsing problem without evidence it is necessary.

## Consequences

Blocks `ReceiptOCRService` implementation (deliberately — one day of evidence beats a
week of parser workarounds). Requires a physical device and real receipts; camera/OCR
cannot be simulator-tested per CLAUDE.md.

## Non-goals

Parser (`ReceiptParserService`) design — it consumes text lines either way; only the
line-production strategy is at stake here.
