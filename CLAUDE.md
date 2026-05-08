# CLAUDE.md

Project-specific guidance for AI agents working on BillSplitz. Read [AGENTS.md](AGENTS.md) for general behavioral guidelines, and [docs/superpowers/specs/2026-05-04-billsplitz-mvp-design.md](docs/superpowers/specs/2026-05-04-billsplitz-mvp-design.md) for the authoritative MVP design.

## What this is

BillSplitz is an **iPhone-only native iOS app** for splitting shared receipts. One person scans a receipt, assigns items to participants, and shares a settlement summary. The MVP is **local-first, single-device, no accounts, no backend**.

## Tech stack — do not deviate without discussion

- **UI:** SwiftUI
- **View model observation:** Observation framework with `@Observable` (not `ObservableObject`)
- **Persistence:** SwiftData
- **Receipt scanning:** VisionKit `VNDocumentCameraViewController`
- **OCR:** Vision `VNRecognizeTextRequest` (on-device only)
- **Photo import fallback:** PhotosUI
- **Sharing:** `ShareLink` or a UIKit share sheet bridge
- **Testing:** XCTest and Swift Testing

**No third-party dependencies** unless a specific gap is identified and discussed.

## Build and platform constraints

- Architecture pattern: **MVVM**
- Deployment target: **iOS 26.1** (`IPHONEOS_DEPLOYMENT_TARGET = 26.1`)
- Device family: **iPhone only** — `TARGETED_DEVICE_FAMILY` must be `"1"` (the project currently has `"1,2,7"`; fix this before MVP work).

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
- **`ItemAssignment.shareRatio`** is a fraction in `[0, 1]`. Ratios across all assignments for a single `ReceiptItem` must sum to 1.
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
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Out of scope for the MVP

Do not add (without explicit discussion):

- User accounts or sign-in
- Cloud sync or backend
- Real-time / multi-device collaboration
- Direct Venmo / Zelle / Cash App API integration — the MVP shares plain text + screenshots and stores handles only
- Combining multiple receipts into one session
- Expense history beyond local session storage

## When in doubt

The MVP design spec is the source of truth for product and architecture decisions. If the spec is silent on something, surface it as a question rather than picking silently — see [AGENTS.md](AGENTS.md) §1.
