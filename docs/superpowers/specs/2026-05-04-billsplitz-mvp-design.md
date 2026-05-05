# BillSplitz MVP Design

## Summary

BillSplitz is an iPhone-only native iOS app for splitting shared receipts. The MVP solves one narrow problem: one person pays for a meal or group purchase, scans the receipt, assigns items to participants, and shares a clean summary of who owes what. The app is local-first, works on a single device, and does not require accounts or backend sync.

The MVP should be functional within one week and good enough for TestFlight. App Store submission is possible in that window, but it should be treated as a stretch goal because review timing and polish risk are outside engineering control.

## Product Goals

- Reduce the time and manual effort needed to split a receipt after a shared meal or group purchase.
- Replace ad hoc spreadsheet math with a guided mobile workflow.
- Let one user move from receipt capture to shareable settlement in a few minutes.
- Support common split patterns such as shared appetizers and desserts with individual mains and drinks.

## Out of Scope for MVP

- User accounts
- Cloud sync
- Real-time collaboration
- In-app money movement
- Direct third-party payment requests through Zelle, Venmo, or Cash App APIs
- Multi-device shared editing
- Expense history beyond local session storage

## Current Repo Assessment

The current repository is a SwiftUI starter app, not an MVP foundation.

- `ContentView` and `CameraView` are placeholders.
- The current item list flow is a prototype with hard-coded data.
- The data model does not separate receipt items from assignments or settlement.
- Tests are scaffolds only.

Recommendation: keep the existing Xcode project, targets, and folder structure, but rebuild most application code inside that shell.

## Recommended Approach

### Option 1: Keep the project and rebuild the app layer

Preserve the existing Xcode project and replace the current screens, models, and view models with the real MVP architecture.

Pros:

- Fastest path to a working iPhone app
- Reuses the current app target and test targets
- Avoids unnecessary project setup churn

Cons:

- Most existing feature code will be discarded

### Option 2: Patch the current prototype incrementally

Extend the current sample code into the final product.

Pros:

- Looks cheaper at first glance

Cons:

- The current model boundaries are wrong for receipts, participants, assignments, and settlement
- More rework and hidden complexity than a controlled rebuild

### Option 3: Start a fresh Xcode app

Create a new project and migrate only the name and branding.

Pros:

- Clean slate

Cons:

- Costs time without solving a real problem
- Duplicates structure that already exists

Recommendation: Option 1.

## Platform and Technical Constraints

- Target platform: iPhone-only native iOS
- Deployment target: iOS 17+
- Architecture pattern: MVVM
- Persistence model: local-first, single-device
- OCR strategy: on-device OCR only for the MVP, with AI retry reserved for a later version if accuracy proves insufficient

The MVP should not depend on backend infrastructure. It should be able to complete the main flow entirely on-device.

## Recommended Tech Stack

- UI: SwiftUI
- View model observation: Observation framework with `@Observable`
- Persistence: SwiftData
- Receipt scanning: VisionKit `VNDocumentCameraViewController`
- OCR: Vision `VNRecognizeTextRequest`
- Photo import fallback: PhotosUI
- Sharing: `ShareLink` or a UIKit share sheet bridge
- Testing: XCTest and Apple Testing

External dependencies are not recommended for v1 unless a specific gap appears. Avoiding third-party packages keeps setup simple and reduces App Store risk.

## MVP User Flow

### 1. New Session

The user creates a split session, adds participant names, and optionally stores payment handles such as a Venmo username, Zelle email or phone number, or Cash App cashtag. The user selects a default split preset, such as shared appetizers and desserts with individual mains and drinks.

### 2. Scan and Review

The app scans or imports a receipt image, runs OCR, and produces candidate receipt lines. The user reviews and corrects the output by editing names, deleting noise, fixing prices, and changing item categories where needed.

### 3. Split Board

The app shows cleaned receipt items grouped by category. Each item can be assigned to one participant, split among selected participants, or marked as shared by everyone. The preset rule engine should prefill the expected behavior for common categories.

### 4. Settlement and Share

The app calculates each participant's subtotal, tax share, tip share, and total owed. The user can then share a screenshot card or plain-text summary to any messaging app.

Rounding rule: item shares, tax, and tip should be rounded to cents per participant, and any remaining cent difference should be assigned to the participant with the largest pre-rounded share so the final totals always reconcile to the receipt total.

## What to Cut to Hit One Week

- No accounts or sign-in
- No backend or sync
- No collaborative editing
- No direct payment API integrations
- No support for combining multiple receipts into one session
- No debt-tracking ledger unless time remains

This keeps the MVP aligned with the real problem: scan the receipt, assign items quickly, and share the result.

## Data Model

### SplitSession

Represents one bill-splitting workflow.

Fields:

- `id`
- `createdAt`
- `title`
- `currencyCode`
- `subtotal`
- `tax`
- `tip`
- `status`
- `receiptImageRefs`

### Participant

Represents one person in the session.

Fields:

- `id`
- `name`
- `paymentMethodType`
- `paymentHandle`
- `displayColor`

### ReceiptItem

Represents one cleaned item derived from OCR.

Fields:

- `id`
- `rawText`
- `normalizedName`
- `quantity`
- `unitPrice`
- `category`
- `assignmentMode`

### ItemAssignment

Represents how a receipt item is allocated.

Fields:

- `id`
- `receiptItemID`
- `participantID`
- `shareRatio`

### SplitRulePreset

Represents default split behavior.

Examples:

- shared appetizers and desserts
- individual mains
- individual drinks

### SettlementLine

Represents the final amount a participant owes.

Fields:

- `participantID`
- `itemSubtotal`
- `taxShare`
- `tipShare`
- `grandTotal`

Key design choice: keep `ReceiptItem` separate from `ItemAssignment`. OCR cleanup and split math change for different reasons and should not be coupled.

## MVVM Boundaries

Each major screen owns one focused view model.

- `SessionSetupViewModel`
- `ReceiptCaptureViewModel`
- `ReceiptReviewViewModel`
- `SplitBoardViewModel`
- `SettlementViewModel`

View models handle screen state, user intent, validation, and calls into services. They should not contain low-level OCR parsing or settlement math.

## Service Layer

### ReceiptScanService

Coordinates scanning or photo import and returns images for OCR.

### ReceiptOCRService

Runs text recognition on receipt images and returns raw recognized lines.

### ReceiptParserService

Normalizes OCR output into candidate items, subtotal lines, tax lines, and tip lines.

### SplitRuleEngine

Applies default split behavior based on category and preset.

### SettlementCalculator

Calculates per-person totals, including tax and tip allocation.

### ShareExportService

Builds shareable text and image output for messaging apps.

### SessionRepository

Stores and loads sessions from SwiftData.

The service layer should be pure or close to pure wherever possible. `SplitRuleEngine`, `ReceiptParserService`, and `SettlementCalculator` should be easy to test without UI.

## Payment Request Strategy

The MVP should not depend on direct Zelle, Venmo, or Cash App request APIs.

Instead, the app should:

- store participant payment handles
- generate a clear plain-text payment summary
- generate a screenshot card for sharing
- optionally provide copy or open-app helpers where practical

This avoids building around payment flows that are inconsistent across providers or outside the intended use of their official developer tooling.

## Default Split Strategy

The MVP should support one smart preset out of the box:

- appetizers and desserts split evenly among all selected diners
- mains assigned to individuals
- drinks assigned to individuals unless manually changed

The user must always be able to override the preset. Presets should accelerate the common case, not hide the math or make corrections difficult.

## Error Handling and Edge Cases

- OCR can produce noisy lines, merged lines, or incorrect prices
- Receipts may omit clear categories
- Users may need to add an item manually when OCR misses it
- Tax and tip may need manual override
- Some receipts may list service fees or discounts that do not fit the default model

The MVP should prefer correction over automation. When confidence is low, the app should present editable output rather than pretending the result is final. Service fees or discounts that do not fit the default model should be editable as separate shared or assigned adjustment lines.

## Testing Strategy

Strict TDD is not recommended for this one-week MVP. It will slow UI and OCR iteration without enough payoff.

Recommended strategy:

- unit tests for `ReceiptParserService`
- unit tests for `SplitRuleEngine`
- unit tests for `SettlementCalculator`
- one or two UI smoke tests for the happy path
- manual device testing with several real receipts

This is a risk-based testing approach. Focus automated coverage on money math, parsing, and deterministic rules. Use manual testing for camera and OCR behavior.

## One-Week Build Plan

### Day 1

Replace placeholders with the real app structure, navigation, SwiftData models, and base repositories.

### Day 2

Implement receipt capture and photo import. Run OCR and persist the receipt image and raw text lines.

### Day 3

Build the receipt review screen. Support editing, deleting, and normalizing OCR output into structured receipt items.

### Day 4

Build the split board, participant assignment, and preset-based split engine.

### Day 5

Implement settlement math, rounding behavior, and share output for text and screenshots.

### Day 6

Add tests, error states, permission handling, and real-device validation on multiple receipts.

### Day 7

Prepare app icon, metadata, screenshots, privacy strings, TestFlight build, and App Store submission if quality is strong enough.

## Delivery Expectation

A functional TestFlight MVP within one week is realistic if scope remains tight. Public App Store release within that same week is possible but should be treated as a best case, not a commitment.

The highest-risk areas are:

- OCR quality on low-quality receipts
- parsing messy lines into clean items
- making assignment fast enough to feel better than a spreadsheet
- making the share output clear enough that users will actually send it

## Sources

- Apple VisionKit document scanner: <https://developer.apple.com/documentation/visionkit/vndocumentcameraviewcontroller>
- Apple Vision text recognition: <https://developer.apple.com/documentation/vision/vnrecognizetextrequest>
- Apple structured document recognition: <https://developer.apple.com/documentation/vision/recognizedocumentsrequest>
- Apple SwiftData data persistence: <https://developer.apple.com/documentation/swiftdata/preserving-your-apps-model-data-across-launches>
- Apple App Review Guidelines: <https://developer.apple.com/app-store/review/guidelines/>
- Venmo personal QR code FAQ: <https://help.venmo.com/hc/en-us/articles/115010772908-Personal-QR-codes-on-Venmo-FAQ>
- Zelle QR code FAQ: <https://www.zellepay.com/faq/how-do-i-use-zelle-qr-code>
- Cash App payment links announcement: <https://cash.app/press/cash-app-launches-payment-links>
- Braintree Venmo iOS client guide: <https://developer.paypal.com/braintree/docs/guides/venmo/client-side/ios/v6/>
