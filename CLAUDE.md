# CLAUDE.md

Project-specific guidance for AI agents working on BillSplitz. Read [AGENTS.md](AGENTS.md) for general behavioral guidelines, and [docs/superpowers/specs/2026-05-04-billsplitz-mvp-design.md](docs/superpowers/specs/2026-05-04-billsplitz-mvp-design.md) for the authoritative MVP design. For UI work: [docs/design/2026-07-05-billsplitz-design-system.md](docs/design/2026-07-05-billsplitz-design-system.md) owns how things look (the "Tab" neo-brutalist system — tokens, components, motion), and [docs/flows/2026-07-05-billsplitz-user-flow-v2.md](docs/flows/2026-07-05-billsplitz-user-flow-v2.md) owns what each screen does (states, validation, copy).

## What this is

BillSplitz is an **iPhone-only native iOS app** for splitting shared receipts. One person scans a receipt, assigns items to participants, and shares a settlement summary. The MVP is **local-first, single-device, no accounts, no backend**.

## Model division of labor

Spend top-tier model capacity on judgment, not execution. Roles, not model names:

- **Top tier** — architecture and UX decisions, adversarial diff review, writing task contracts, verification. Every substantive merge gets a top-tier diff review plus a green test suite.
- **Executor tier** — implementation from a written contract: bug description, fix approach, test requirements, file allowlist, style rules. Dispatch executor subagents on **disjoint file sets** to avoid write conflicts.
- **Mechanical tier** — fixtures, renames, doc syncing, applying precisely described changes.

Current ladder (Fable 5 unavailable after 2026-07-07): top = Opus 4.8, executor = Sonnet 5, mechanical = Haiku 4.5. Update this line when models change; leave the roles alone.

Because the top-executor capability gap is narrow, don't rely on a single review pass: money-math and data-loss-risk diffs get a second independent review with a different lens (or a cross-vendor reviewer), and correctness guarantees belong in invariant tests and hooks, not in review vigilance. Trivial single-file edits stay in the main thread — a subagent for a one-line change is waste.

## Tech stack — do not deviate without discussion

- **UI:** SwiftUI
- **View model observation:** Observation framework with `@Observable` (not `ObservableObject`)
- **Persistence:** Codable JSON in UserDefaults for the active draft, behind `SessionRepository`; SwiftData arrives with session history post-MVP ([decision 0002](docs/decisions/0002-persistence-userdefaults-json.md))
- **Receipt scanning:** VisionKit `VNDocumentCameraViewController`
- **OCR:** on-device Vision — primitive pending an on-device spike of `RecognizeDocumentsRequest` vs `VNRecognizeTextRequest` ([decision 0005](docs/decisions/0005-ocr-primitive-spike.md)); do not build `ReceiptOCRService` before the spike
- **Photo import fallback:** PhotosUI
- **Sharing:** `ShareLink` or a UIKit share sheet bridge
- **Testing:** XCTest and Swift Testing

**No third-party dependencies** unless a specific gap is identified and discussed.

## Build and platform constraints

- Architecture pattern: **MVVM**
- Deployment target: **iOS 26.1** (`IPHONEOS_DEPLOYMENT_TARGET = 26.1`)
- Device family: **iPhone only** — `TARGETED_DEVICE_FAMILY` must be `"1"`.

Required `Info.plist` privacy strings:

- `NSCameraUsageDescription` — for the document scanner
- `NSPhotoLibraryUsageDescription` — for the photo import fallback

## Project structure

```
BillSplitz/
├── Models/          // SwiftData @Model types
├── ViewModels/      // @Observable view models, one per screen
├── Views/           // SwiftUI views
└── Services/        // Pure / near-pure service layer (to be added)
```

The current `Models/ItemListModel.swift`, `ViewModels/ItemListViewModel.swift`, and `Views/ItemListView.swift` are Phase 0 prototype code and will be replaced as part of MVP Day 1 work. Don't extend them.

## Data model rules

The MVP defines six core types: `SplitSession`, `Participant`, `ReceiptItem`, `ItemAssignment`, `SplitRulePreset`, `SettlementLine`. See the spec for full field lists.

- **Keep `ReceiptItem` separate from `ItemAssignment`.** OCR cleanup and split math change for different reasons.
- **`SplitSession.subtotal`/`tax`/`tip` are cached/derived** from items + assignments. Don't treat them as the source of truth — recompute when items change.
- **`ItemAssignment.shareRatio`** is a positive `Decimal` weight (typically 1); `SettlementCalculator` normalizes weights per item. There is no sums-to-1 invariant ([decision 0003](docs/decisions/0003-shareratio-weights.md)).
- **`receiptImageRefs`** stores file paths inside the app sandbox, not raw blobs in SwiftData.

## Money math — strict rules

- **Use `Decimal`, never `Double` or `Float`, for any monetary value.** Floats accumulate error and will desync settlements from receipt totals.
- **Tax and tip are allocated proportionally to each participant's item subtotal**, not split evenly.
- **Rounding:** round each participant's item shares, tax share, and tip share to cents. Any remaining cent difference goes to the participant with the largest pre-rounded share so the totals reconcile to the receipt total exactly.
- **Single-currency only** for the MVP. `SplitSession.currencyCode` is set once at session creation and applies to every line.

## MVVM boundaries

One `@Observable` view model per screen:

- `SessionSetupViewModel`
- `ReceiptCaptureViewModel`
- `ReceiptReviewViewModel`
- `SplitBoardViewModel`
- `SettlementViewModel`

View models handle screen state, user intent, validation, and calls into services. **They do not contain OCR parsing or settlement math** — that lives in services and must stay testable without UI.

## Service layer

Keep pure or close to pure wherever possible:

- `ReceiptScanService` — scan / photo import
- `ReceiptOCRService` — text recognition
- `ReceiptParserService` — OCR lines → candidate items, subtotal, tax, tip
- `SplitRuleEngine` — preset-based default split behavior
- `SettlementCalculator` — per-person totals with tax/tip allocation
- `ShareExportService` — text + image output for messaging
- `SessionRepository` — SwiftData read/write

`SplitRuleEngine`, `ReceiptParserService`, and `SettlementCalculator` must be unit-testable without any view or device dependency.

## Testing

Risk-based, not strict TDD:

- **Unit tests required** for `ReceiptParserService`, `SplitRuleEngine`, `SettlementCalculator`. These contain the money math and parsing — bugs here break trust.
- **One or two UI smoke tests** for the happy path (capture → review → split → settle → share).
- **Manual device testing** for camera and OCR. Don't try to mock VisionKit.

Run tests:

```sh
xcodebuild test -project BillSplitz.xcodeproj -scheme BillSplitz \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

A versioned pre-push hook runs the unit tests (`-only-testing:BillSplitzTests`) before
any push; one-time setup per clone: `git config core.hooksPath .githooks`. The full
suite including UI tests remains required before merging. `git push --no-verify` is
for genuine emergencies only.

## Out of scope for the MVP

Do not add (without explicit discussion):

- User accounts or sign-in
- Cloud sync or backend
- Real-time / multi-device collaboration
- Direct Venmo / Zelle / Cash App API integration — the MVP shares plain text + screenshots and stores handles only
- Combining multiple receipts into one session
- Expense history beyond local session storage

## When in doubt

The MVP design spec is the source of truth for product and architecture decisions. Settled engineering choices live in [docs/decisions/](docs/decisions/) — consult them before re-litigating, and add a record whenever a choice affects more than one PR. If both are silent, surface it as a question rather than picking silently — see [AGENTS.md](AGENTS.md) §1.
